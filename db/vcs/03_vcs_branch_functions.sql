-- ============================================================
-- GIT-LIKE DATABASE VERSIONING - BRANCH & MERGE FUNCTIONS
-- ============================================================
-- vcs_branch_create()  - Create a new branch
-- vcs_branch_list()    - List all branches
-- vcs_checkout()       - Switch active branch
-- vcs_merge()          - Merge source branch into target
-- ============================================================

-- ============================================================
-- VCS_BRANCH_CREATE: Create a new branch from current branch
-- Equivalent to: git branch <name>  OR  git checkout -b <name>
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_branch_create(
    p_branch_name VARCHAR,
    p_from_branch VARCHAR DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_checkout BOOLEAN DEFAULT FALSE
)
RETURNS TEXT AS $$
DECLARE
    v_from_branch VARCHAR(100);
    v_fork_commit INT;
    v_result TEXT;
BEGIN
    v_from_branch := COALESCE(p_from_branch, vcs_get_active_branch());
    
    -- Validate source branch exists
    IF NOT EXISTS (SELECT 1 FROM vcs_branch WHERE branch_name = v_from_branch) THEN
        RAISE EXCEPTION 'Source branch "%" does not exist', v_from_branch;
    END IF;
    
    -- Check name doesn't already exist
    IF EXISTS (SELECT 1 FROM vcs_branch WHERE branch_name = p_branch_name) THEN
        RAISE EXCEPTION 'Branch "%" already exists', p_branch_name;
    END IF;
    
    -- Get the fork point (HEAD of source branch)
    v_fork_commit := vcs_get_head_commit(v_from_branch);
    
    -- Create the branch
    INSERT INTO vcs_branch (branch_name, created_from_branch, created_from_commit_id, description)
    VALUES (p_branch_name, v_from_branch, v_fork_commit, p_description);
    
    -- Copy the HEAD commit as the starting point for this branch
    -- This creates a "branch-off" commit
    INSERT INTO vcs_commit (branch_name, commit_hash, message, author)
    VALUES (
        p_branch_name, 
        md5('branch-' || p_branch_name || '-from-' || v_from_branch || '-' || NOW()::TEXT),
        format('Branch "%s" created from "%s"', p_branch_name, v_from_branch),
        CURRENT_USER
    );
    
    v_result := format('✅ Branch "%s" created from "%s" at commit #%s', 
                        p_branch_name, v_from_branch, v_fork_commit);
    
    -- Optionally checkout the new branch
    IF p_checkout THEN
        UPDATE vcs_config SET value = p_branch_name, updated_at = NOW() 
        WHERE key = 'active_branch';
        v_result := v_result || chr(10) || format('   Switched to branch "%s"', p_branch_name);
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_BRANCH_LIST: List all branches with metadata
-- Equivalent to: git branch -a -v
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_branch_list()
RETURNS TABLE (
    branch TEXT,
    is_current BOOLEAN,
    created_from TEXT,
    latest_commit TEXT,
    commit_count BIGINT,
    created_at TIMESTAMP
) AS $$
DECLARE
    v_active VARCHAR(100);
BEGIN
    v_active := vcs_get_active_branch();
    
    RETURN QUERY
    SELECT 
        b.branch_name::TEXT,
        (b.branch_name = v_active),
        COALESCE(b.created_from_branch, '-')::TEXT,
        COALESCE(
            (SELECT LEFT(c.commit_hash, 8) || ' - ' || LEFT(c.message, 50)
             FROM vcs_commit c 
             WHERE c.branch_name = b.branch_name 
             ORDER BY c.committed_at DESC LIMIT 1),
            'no commits'
        )::TEXT,
        (SELECT COUNT(*) FROM vcs_commit c WHERE c.branch_name = b.branch_name),
        b.created_at
    FROM vcs_branch b
    WHERE b.is_active = TRUE
    ORDER BY b.created_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_CHECKOUT: Switch to a different branch
-- Equivalent to: git checkout <branch>
--
-- IMPORTANT: This only changes the active branch pointer.
-- Data changes you make after checkout will be staged under 
-- the new branch. It does NOT rewrite table data (see 
-- vcs_rollback for that).
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_checkout(
    p_branch_name VARCHAR
)
RETURNS TEXT AS $$
DECLARE
    v_current VARCHAR(100);
    v_pending INT;
BEGIN
    v_current := vcs_get_active_branch();
    
    -- Can't checkout to current branch
    IF v_current = p_branch_name THEN
        RETURN format('Already on branch "%s"', p_branch_name);
    END IF;
    
    -- Validate branch exists
    IF NOT EXISTS (SELECT 1 FROM vcs_branch WHERE branch_name = p_branch_name AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Branch "%" does not exist or is inactive', p_branch_name;
    END IF;
    
    -- Warn about uncommitted changes
    SELECT COUNT(*) INTO v_pending FROM vcs_staged_change WHERE branch_name = v_current;
    
    IF v_pending > 0 THEN
        RAISE NOTICE 'WARNING: You have % uncommitted change(s) on branch "%". Commit or discard them first.', v_pending, v_current;
        -- We still allow the checkout (like git with unstaged changes)
    END IF;
    
    -- Switch the active branch
    UPDATE vcs_config 
    SET value = p_branch_name, updated_at = NOW() 
    WHERE key = 'active_branch';
    
    RETURN format('✅ Switched to branch "%s"' || chr(10) || 
                  '   HEAD is at commit #%s', 
                  p_branch_name, vcs_get_head_commit(p_branch_name));
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_MERGE: Merge one branch into another
-- Equivalent to: git merge <source> (into current branch)
--
-- Strategy: Replay all commits from source that happened AFTER
-- the fork point into the target branch. Creates a merge commit.
-- Detects conflicts (same row PK changed on both branches).
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_merge(
    p_source_branch VARCHAR,
    p_target_branch VARCHAR DEFAULT NULL,
    p_message TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_target VARCHAR(100);
    v_merge_msg TEXT;
    v_merge_commit_id INT;
    v_source_head INT;
    v_target_head INT;
    v_fork_commit_id INT;
    v_conflict_count INT;
    v_change_count INT;
    v_hash VARCHAR(64);
BEGIN
    v_target := COALESCE(p_target_branch, vcs_get_active_branch());
    v_merge_msg := COALESCE(p_message, format('Merge branch "%s" into "%s"', p_source_branch, v_target));
    
    -- Validate branches
    IF NOT EXISTS (SELECT 1 FROM vcs_branch WHERE branch_name = p_source_branch AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Source branch "%" does not exist', p_source_branch;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM vcs_branch WHERE branch_name = v_target AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Target branch "%" does not exist', v_target;
    END IF;
    IF p_source_branch = v_target THEN
        RAISE EXCEPTION 'Cannot merge a branch into itself';
    END IF;
    
    -- Find fork point
    SELECT created_from_commit_id INTO v_fork_commit_id
    FROM vcs_branch WHERE branch_name = p_source_branch;
    
    v_source_head := vcs_get_head_commit(p_source_branch);
    v_target_head := vcs_get_head_commit(v_target);
    
    -- Detect conflicts: same table+pk modified on both branches after fork
    SELECT COUNT(DISTINCT s.table_name || '::' || s.row_pk) INTO v_conflict_count
    FROM vcs_change s
    JOIN vcs_commit sc ON s.commit_id = sc.commit_id AND sc.branch_name = p_source_branch
    WHERE EXISTS (
        SELECT 1 FROM vcs_change t
        JOIN vcs_commit tc ON t.commit_id = tc.commit_id AND tc.branch_name = v_target
        WHERE t.table_name = s.table_name AND t.row_pk = s.row_pk
        AND tc.commit_id > COALESCE(v_fork_commit_id, 0)
    )
    AND sc.commit_id > COALESCE(v_fork_commit_id, 0);
    
    IF v_conflict_count > 0 THEN
        RETURN format('❌ MERGE CONFLICT: %s row(s) were modified on both branches.' || chr(10) ||
                       '   Resolve conflicts manually before merging.' || chr(10) ||
                       '   Use: SELECT * FROM vcs_merge_conflicts(''%s'', ''%s'') to see details.',
                       v_conflict_count, p_source_branch, v_target);
    END IF;
    
    -- Count changes to merge
    SELECT COUNT(*) INTO v_change_count
    FROM vcs_change ch
    JOIN vcs_commit co ON ch.commit_id = co.commit_id
    WHERE co.branch_name = p_source_branch
    AND co.commit_id > COALESCE(v_fork_commit_id, 0);
    
    IF v_change_count = 0 THEN
        RETURN format('Already up to date. No new changes on "%s" to merge.', p_source_branch);
    END IF;
    
    -- Generate merge commit hash
    v_hash := md5('merge-' || p_source_branch || '-into-' || v_target || '-' || NOW()::TEXT);
    
    -- Create the merge commit
    INSERT INTO vcs_commit (branch_name, commit_hash, message, author, is_merge)
    VALUES (v_target, v_hash, v_merge_msg, CURRENT_USER, TRUE)
    RETURNING commit_id INTO v_merge_commit_id;
    
    -- Link both parents (target HEAD + source HEAD)
    INSERT INTO vcs_commit_parent (commit_id, parent_commit_id, ordinal) VALUES
        (v_merge_commit_id, v_target_head, 1),
        (v_merge_commit_id, v_source_head, 2);
    
    -- Copy source branch changes into the merge commit
    INSERT INTO vcs_change (commit_id, table_name, row_pk, operation, old_data, new_data, changed_columns, changed_at)
    SELECT v_merge_commit_id, ch.table_name, ch.row_pk, ch.operation, ch.old_data, ch.new_data, ch.changed_columns, NOW()
    FROM vcs_change ch
    JOIN vcs_commit co ON ch.commit_id = co.commit_id
    WHERE co.branch_name = p_source_branch
    AND co.commit_id > COALESCE(v_fork_commit_id, 0);
    
    RETURN format(
        '✅ Merge successful: "%s" → "%s"' || chr(10) ||
        '   Merge commit: #%s (%s)' || chr(10) ||
        '   %s change(s) incorporated',
        p_source_branch, v_target, v_merge_commit_id, LEFT(v_hash, 8), v_change_count
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_MERGE_CONFLICTS: Show conflicting rows between branches
-- Equivalent to: viewing conflict markers in git
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_merge_conflicts(
    p_source_branch VARCHAR,
    p_target_branch VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    table_name TEXT,
    row_pk TEXT,
    source_operation TEXT,
    target_operation TEXT,
    source_data JSONB,
    target_data JSONB
) AS $$
DECLARE
    v_target VARCHAR(100);
    v_fork_commit_id INT;
BEGIN
    v_target := COALESCE(p_target_branch, vcs_get_active_branch());
    
    SELECT created_from_commit_id INTO v_fork_commit_id
    FROM vcs_branch WHERE branch_name = p_source_branch;
    
    RETURN QUERY
    SELECT DISTINCT ON (s_ch.table_name, s_ch.row_pk)
        s_ch.table_name::TEXT,
        s_ch.row_pk::TEXT,
        s_ch.operation::TEXT,
        t_ch.operation::TEXT,
        s_ch.new_data,
        t_ch.new_data
    FROM vcs_change s_ch
    JOIN vcs_commit s_co ON s_ch.commit_id = s_co.commit_id AND s_co.branch_name = p_source_branch
    JOIN vcs_change t_ch ON s_ch.table_name = t_ch.table_name AND s_ch.row_pk = t_ch.row_pk
    JOIN vcs_commit t_co ON t_ch.commit_id = t_co.commit_id AND t_co.branch_name = v_target
    WHERE s_co.commit_id > COALESCE(v_fork_commit_id, 0)
    AND t_co.commit_id > COALESCE(v_fork_commit_id, 0)
    ORDER BY s_ch.table_name, s_ch.row_pk, s_ch.changed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_BRANCH_DELETE: Soft-delete a branch (mark inactive)
-- Equivalent to: git branch -d <name>
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_branch_delete(
    p_branch_name VARCHAR
)
RETURNS TEXT AS $$
DECLARE
    v_active VARCHAR(100);
BEGIN
    v_active := vcs_get_active_branch();
    
    IF p_branch_name = 'main' THEN
        RAISE EXCEPTION 'Cannot delete the main branch';
    END IF;
    
    IF p_branch_name = v_active THEN
        RAISE EXCEPTION 'Cannot delete the currently active branch. Checkout another branch first.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM vcs_branch WHERE branch_name = p_branch_name) THEN
        RAISE EXCEPTION 'Branch "%" does not exist', p_branch_name;
    END IF;
    
    UPDATE vcs_branch SET is_active = FALSE WHERE branch_name = p_branch_name;
    
    -- Clean up staged changes for deleted branch
    DELETE FROM vcs_staged_change WHERE branch_name = p_branch_name;
    
    RETURN format('✅ Deleted branch "%s"', p_branch_name);
END;
$$ LANGUAGE plpgsql;

SELECT '✅ Branch & Merge functions created: vcs_branch_create(), vcs_branch_list(), vcs_checkout(), vcs_merge()' AS status;
