-- ============================================================
-- GIT-LIKE DATABASE VERSIONING - ROLLBACK & TIME TRAVEL
-- ============================================================
-- vcs_rollback()         - Revert table data to a prior commit
-- vcs_snapshot()         - Capture current state as a commit
-- vcs_reconstruct_at()   - Reconstruct row state at a commit
-- vcs_time_travel()      - View table as it was at a commit
-- ============================================================

-- ============================================================
-- VCS_ROLLBACK: Revert a table to its state at a given commit
-- Equivalent to: git revert / git reset --hard
--
-- CAUTION: This modifies actual table data by replaying
-- inverse operations. A new "rollback commit" is created
-- to record what was undone.
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_rollback(
    p_to_commit_id INT,
    p_table_name VARCHAR DEFAULT NULL,
    p_dry_run BOOLEAN DEFAULT FALSE
)
RETURNS TEXT AS $$
DECLARE
    v_branch VARCHAR(100);
    v_head INT;
    v_change RECORD;
    v_rollback_count INT := 0;
    v_pk_col VARCHAR(100);
    v_result TEXT;
BEGIN
    v_branch := vcs_get_active_branch();
    v_head := vcs_get_head_commit(v_branch);
    
    IF p_to_commit_id >= v_head THEN
        RETURN '⚠️  Target commit is at or ahead of HEAD. Nothing to rollback.';
    END IF;
    
    FOR v_change IN (
        SELECT ch.*, co.commit_id as cid
        FROM vcs_change ch
        JOIN vcs_commit co ON ch.commit_id = co.commit_id
        WHERE co.branch_name = v_branch
        AND co.commit_id > p_to_commit_id
        AND (p_table_name IS NULL OR ch.table_name = p_table_name)
        ORDER BY co.committed_at DESC, ch.change_id DESC
    ) LOOP
        IF NOT p_dry_run THEN
            SELECT primary_key_column INTO v_pk_col
            FROM vcs_repository WHERE table_name = v_change.table_name;
            
            IF v_change.operation = 'INSERT' THEN
                -- ✅ Cast row_pk to match the PK column type
                EXECUTE format(
                    'DELETE FROM %I WHERE %I::TEXT = $1',
                    v_change.table_name, v_pk_col
                ) USING v_change.row_pk;
                
            ELSIF v_change.operation = 'DELETE' THEN
                EXECUTE format(
                    'INSERT INTO %I SELECT * FROM jsonb_populate_record(NULL::%I, $1)',
                    v_change.table_name, v_change.table_name
                ) USING v_change.old_data;
                
            ELSIF v_change.operation = 'UPDATE' THEN
                -- ✅ Cast row_pk to match the PK column type
                EXECUTE format(
                    'UPDATE %I SET (%s) = (SELECT %s FROM jsonb_populate_record(NULL::%I, $1)) WHERE %I::TEXT = $2',
                    v_change.table_name,
                    array_to_string(v_change.changed_columns, ', '),
                    array_to_string(v_change.changed_columns, ', '),
                    v_change.table_name,
                    v_pk_col
                ) USING v_change.old_data, v_change.row_pk;
            END IF;
        END IF;
        
        v_rollback_count := v_rollback_count + 1;
    END LOOP;
    
    IF p_dry_run THEN
        v_result := format('🔍 DRY RUN: Would rollback %s change(s) to commit #%s', v_rollback_count, p_to_commit_id);
    ELSE
        IF v_rollback_count > 0 THEN
            PERFORM vcs_commit(
                format('Rollback to commit #%s (%s changes reverted)', p_to_commit_id, v_rollback_count),
                CURRENT_USER::VARCHAR
            );
        END IF;
        v_result := format('✅ Rolled back %s change(s) to commit #%s on branch "%s"', v_rollback_count, p_to_commit_id, v_branch);
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
-- ============================================================
-- VCS_RECONSTRUCT_AT: Reconstruct what a row looked like at 
-- a specific commit by replaying changes forward from genesis.
-- Equivalent to: git show <commit>:<file>
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_reconstruct_at(
    p_table_name VARCHAR,
    p_row_pk TEXT,
    p_at_commit_id INT
)
RETURNS JSONB AS $$
DECLARE
    v_state JSONB := NULL;
    v_change RECORD;
BEGIN
    -- Replay all changes up to and including the target commit
    FOR v_change IN (
        SELECT ch.*
        FROM vcs_change ch
        JOIN vcs_commit co ON ch.commit_id = co.commit_id
        WHERE ch.table_name = p_table_name 
        AND ch.row_pk = p_row_pk
        AND co.commit_id <= p_at_commit_id
        ORDER BY co.committed_at, ch.change_id
    ) LOOP
        IF v_change.operation = 'INSERT' THEN
            v_state := v_change.new_data;
        ELSIF v_change.operation = 'UPDATE' THEN
            v_state := v_change.new_data;
        ELSIF v_change.operation = 'DELETE' THEN
            v_state := NULL;
        END IF;
    END LOOP;
    
    RETURN v_state;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_TIME_TRAVEL: View all rows of a table as they were at 
-- a specific commit. Returns JSONB rows.
-- Equivalent to: checking out a file at a historical commit
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_time_travel(
    p_table_name VARCHAR,
    p_at_commit_id INT
)
RETURNS TABLE (
    row_pk TEXT,
    row_state JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT 
        ch.row_pk,
        vcs_reconstruct_at(p_table_name, ch.row_pk, p_at_commit_id)
    FROM vcs_change ch
    JOIN vcs_commit co ON ch.commit_id = co.commit_id
    WHERE ch.table_name = p_table_name
    AND co.commit_id <= p_at_commit_id
    AND vcs_reconstruct_at(p_table_name, ch.row_pk, p_at_commit_id) IS NOT NULL
    ORDER BY ch.row_pk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_SNAPSHOT: Capture the entire current state of a tracked
-- table as an "initial snapshot" commit. Useful to establish
-- the baseline after setting up tracking.
-- Equivalent to: git add . && git commit -m "Initial snapshot"
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_snapshot(
    p_table_name VARCHAR,
    p_message TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_pk_col VARCHAR(100);
    v_branch VARCHAR(100);
    v_count INT;
    v_msg TEXT;
BEGIN
    v_branch := vcs_get_active_branch();
    
    -- Get PK column
    SELECT primary_key_column INTO v_pk_col
    FROM vcs_repository WHERE table_name = p_table_name;
    
    IF v_pk_col IS NULL THEN
        RAISE EXCEPTION 'Table "%" is not tracked. Run vcs_init(''%'') first.', p_table_name, p_table_name;
    END IF;
    
    -- Insert current rows as staged INSERTs
    EXECUTE format(
        'INSERT INTO vcs_staged_change (branch_name, table_name, row_pk, operation, new_data)
         SELECT $1, $2, (%I)::TEXT, ''INSERT'', to_jsonb(t.*)
         FROM %I t',
        v_pk_col, p_table_name
    ) USING v_branch, p_table_name;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    v_msg := COALESCE(p_message, format('Snapshot of "%s" (%s rows)', p_table_name, v_count));
    
    -- Auto-commit the snapshot
    RETURN vcs_commit(v_msg, CURRENT_USER::VARCHAR);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_SNAPSHOT_ALL: Snapshot ALL tracked tables at once
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_snapshot_all(
    p_message TEXT DEFAULT 'Full database snapshot'
)
RETURNS TEXT AS $$
DECLARE
    v_repo RECORD;
    v_branch VARCHAR(100);
    v_pk_col VARCHAR(100);
    v_total INT := 0;
    v_count INT;
BEGIN
    v_branch := vcs_get_active_branch();
    
    FOR v_repo IN (SELECT table_name, primary_key_column FROM vcs_repository WHERE is_active = TRUE) LOOP
        EXECUTE format(
            'INSERT INTO vcs_staged_change (branch_name, table_name, row_pk, operation, new_data)
             SELECT $1, $2, (%I)::TEXT, ''INSERT'', to_jsonb(t.*)
             FROM %I t',
            v_repo.primary_key_column, v_repo.table_name
        ) USING v_branch, v_repo.table_name;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        v_total := v_total + v_count;
    END LOOP;
    
    IF v_total = 0 THEN
        RETURN '⚠️  No tracked tables have data to snapshot.';
    END IF;
    
    RETURN vcs_commit(
        format('%s (%s rows across all tracked tables)', p_message, v_total),
        CURRENT_USER::VARCHAR
    );
END;
$$ LANGUAGE plpgsql;

SELECT '✅ Rollback & Time Travel functions created: vcs_rollback(), vcs_time_travel(), vcs_snapshot()' AS status;
