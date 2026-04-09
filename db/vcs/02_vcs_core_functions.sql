-- ============================================================
-- GIT-LIKE DATABASE VERSIONING - CORE FUNCTIONS
-- ============================================================
-- vcs_init()         - Register a table for tracking
-- vcs_get_active_branch() - Get current branch
-- vcs_commit()       - Commit staged changes
-- vcs_status()       - Show uncommitted changes
-- ============================================================

-- ============================================================
-- HELPER: Get the currently active branch name
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_get_active_branch()
RETURNS VARCHAR(100) AS $$
DECLARE
    branch_name VARCHAR(100);
BEGIN
    SELECT value INTO branch_name FROM vcs_config WHERE key = 'active_branch';
    RETURN branch_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- HELPER: Get latest commit ID on a branch
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_get_head_commit(p_branch VARCHAR DEFAULT NULL)
RETURNS INT AS $$
DECLARE
    v_branch VARCHAR(100);
    v_commit_id INT;
BEGIN
    v_branch := COALESCE(p_branch, vcs_get_active_branch());
    
    SELECT commit_id INTO v_commit_id 
    FROM vcs_commit 
    WHERE branch_name = v_branch 
    ORDER BY committed_at DESC, commit_id DESC
    LIMIT 1;
    
    RETURN v_commit_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_INIT: Register a table for version tracking
-- Equivalent to: git init (per table)
-- 
-- Creates a trigger on the table to auto-capture changes
-- into the staging area.
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_init(
    p_table_name VARCHAR,
    p_pk_column VARCHAR DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_pk_col VARCHAR(100);
    v_trigger_name VARCHAR(200);
    v_already_tracked BOOLEAN;
BEGIN
    -- Check if table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = p_table_name 
        AND table_schema = 'public'
    ) THEN
        RAISE EXCEPTION 'Table "%" does not exist in public schema', p_table_name;
    END IF;

    -- Check if already tracked
    SELECT EXISTS(
        SELECT 1 FROM vcs_repository WHERE table_name = p_table_name
    ) INTO v_already_tracked;
    
    IF v_already_tracked THEN
        RETURN format('Table "%s" is already tracked.', p_table_name);
    END IF;

    -- Auto-detect primary key if not provided
    IF p_pk_column IS NULL THEN
        SELECT kcu.column_name INTO v_pk_col
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = p_table_name 
            AND tc.constraint_type = 'PRIMARY KEY'
            AND tc.table_schema = 'public'
        LIMIT 1;
        
        IF v_pk_col IS NULL THEN
            RAISE EXCEPTION 'Cannot auto-detect primary key for "%". Specify p_pk_column.', p_table_name;
        END IF;
    ELSE
        v_pk_col := p_pk_column;
    END IF;

    -- Register the table
    INSERT INTO vcs_repository (table_name, primary_key_column)
    VALUES (p_table_name, v_pk_col);

    -- Create the trigger on this table
    v_trigger_name := 'vcs_track_' || p_table_name;
    
    EXECUTE format(
        'DROP TRIGGER IF EXISTS %I ON %I',
        v_trigger_name, p_table_name
    );
    
    EXECUTE format(
        'CREATE TRIGGER %I
         AFTER INSERT OR UPDATE OR DELETE ON %I
         FOR EACH ROW EXECUTE FUNCTION vcs_trigger_fn()',
        v_trigger_name, p_table_name
    );

    RETURN format('✅ Now tracking table "%s" (PK: %s). Changes will be auto-staged.', p_table_name, v_pk_col);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER FUNCTION: Auto-capture row changes to staging area
-- This fires on every INSERT/UPDATE/DELETE on tracked tables
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_trigger_fn()
RETURNS TRIGGER AS $$
DECLARE
    v_branch VARCHAR(100);
    v_pk_col VARCHAR(100);
    v_pk_val TEXT;
    v_old_json JSONB;
    v_new_json JSONB;
    v_changed_cols TEXT[];
    v_col_name TEXT;
BEGIN
    -- Get active branch and PK column
    v_branch := vcs_get_active_branch();
    
    SELECT primary_key_column INTO v_pk_col
    FROM vcs_repository WHERE table_name = TG_TABLE_NAME;
    
    IF v_pk_col IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Determine operation and extract data
    IF TG_OP = 'INSERT' THEN
        v_new_json := to_jsonb(NEW);
        v_pk_val := v_new_json ->> v_pk_col;
        
        INSERT INTO vcs_staged_change (branch_name, table_name, row_pk, operation, old_data, new_data)
        VALUES (v_branch, TG_TABLE_NAME, v_pk_val, 'INSERT', NULL, v_new_json);
        
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);
        v_pk_val := v_old_json ->> v_pk_col;
        
        -- Detect which columns changed
        v_changed_cols := ARRAY(
            SELECT key FROM jsonb_each_text(v_old_json)
            WHERE v_old_json ->> key IS DISTINCT FROM v_new_json ->> key
        );
        
        -- Only stage if something actually changed
        IF array_length(v_changed_cols, 1) > 0 THEN
            INSERT INTO vcs_staged_change (branch_name, table_name, row_pk, operation, old_data, new_data, changed_columns)
            VALUES (v_branch, TG_TABLE_NAME, v_pk_val, 'UPDATE', v_old_json, v_new_json, v_changed_cols);
        END IF;
        
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        v_old_json := to_jsonb(OLD);
        v_pk_val := v_old_json ->> v_pk_col;
        
        INSERT INTO vcs_staged_change (branch_name, table_name, row_pk, operation, old_data, new_data)
        VALUES (v_branch, TG_TABLE_NAME, v_pk_val, 'DELETE', v_old_json, NULL);
        
        RETURN OLD;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_STATUS: Show uncommitted (staged) changes
-- Equivalent to: git status
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_status(
    p_branch VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    branch TEXT,
    table_name TEXT,
    row_pk TEXT,
    operation TEXT,
    changed_columns TEXT,
    staged_at TIMESTAMP
) AS $$
DECLARE
    v_branch VARCHAR(100);
BEGIN
    v_branch := COALESCE(p_branch, vcs_get_active_branch());
    
    RETURN QUERY
    SELECT 
        v_branch::TEXT,
        sc.table_name::TEXT,
        sc.row_pk::TEXT,
        sc.operation::TEXT,
        COALESCE(array_to_string(sc.changed_columns, ', '), '-')::TEXT,
        sc.staged_at
    FROM vcs_staged_change sc
    WHERE sc.branch_name = v_branch
    ORDER BY sc.staged_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_COMMIT: Commit all staged changes on the active branch
-- Equivalent to: git commit -m "message"
--
-- Moves changes from staging to permanent commit history.
-- Generates a commit hash from the change content.
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_commit(
    p_message TEXT,
    p_author VARCHAR DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_branch VARCHAR(100);
    v_author VARCHAR(100);
    v_commit_id INT;
    v_parent_id INT;
    v_change_count INT;
    v_hash_input TEXT;
    v_hash VARCHAR(64);
BEGIN
    v_branch := vcs_get_active_branch();
    v_author := COALESCE(p_author, CURRENT_USER);
    
    -- Count staged changes
    SELECT COUNT(*) INTO v_change_count 
    FROM vcs_staged_change WHERE branch_name = v_branch;
    
    IF v_change_count = 0 THEN
        RETURN '⚠️  Nothing to commit on branch "' || v_branch || '". Working tree clean.';
    END IF;
    
    -- Get parent commit (current HEAD)
    v_parent_id := vcs_get_head_commit(v_branch);
    
    -- Generate commit hash from content
    v_hash_input := v_branch || '|' || p_message || '|' || v_author || '|' || NOW()::TEXT || '|' || v_change_count;
    v_hash := md5(v_hash_input);
    
    -- Create the commit
    INSERT INTO vcs_commit (branch_name, commit_hash, message, author)
    VALUES (v_branch, v_hash, p_message, v_author)
    RETURNING commit_id INTO v_commit_id;
    
    -- Link to parent
    IF v_parent_id IS NOT NULL THEN
        INSERT INTO vcs_commit_parent (commit_id, parent_commit_id, ordinal)
        VALUES (v_commit_id, v_parent_id, 1);
    END IF;
    
    -- Move staged changes to permanent storage
    INSERT INTO vcs_change (commit_id, table_name, row_pk, operation, old_data, new_data, changed_columns, changed_at)
    SELECT v_commit_id, table_name, row_pk, operation, old_data, new_data, changed_columns, staged_at
    FROM vcs_staged_change
    WHERE branch_name = v_branch
    ORDER BY staged_at;
    
    -- Clear staging area for this branch
    DELETE FROM vcs_staged_change WHERE branch_name = v_branch;
    
    RETURN format(
        '✅ [%s %s] %s' || chr(10) || '   %s change(s) committed on branch "%s" by %s',
        v_branch, LEFT(v_hash, 8), p_message, v_change_count, v_branch, v_author
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_DISCARD: Discard staged (uncommitted) changes
-- Equivalent to: git checkout -- . (discard working changes)
-- NOTE: This only removes from staging, it does NOT undo 
-- the actual table data changes.
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_discard(
    p_table_name VARCHAR DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_branch VARCHAR(100);
    v_count INT;
BEGIN
    v_branch := vcs_get_active_branch();
    
    IF p_table_name IS NOT NULL THEN
        DELETE FROM vcs_staged_change 
        WHERE branch_name = v_branch AND table_name = p_table_name;
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN format('Discarded %s staged change(s) for table "%s"', v_count, p_table_name);
    ELSE
        DELETE FROM vcs_staged_change WHERE branch_name = v_branch;
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN format('Discarded %s staged change(s) on branch "%s"', v_count, v_branch);
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT '✅ Core VCS functions created: vcs_init(), vcs_commit(), vcs_status(), vcs_discard()' AS status;
