-- ============================================================
-- GIT-LIKE DATABASE VERSIONING - HISTORY, DIFF, LOG & TAG
-- ============================================================
-- vcs_log()            - View commit history
-- vcs_diff()           - Compare two commits
-- vcs_show()           - Show details of a single commit
-- vcs_tag_create()     - Tag a commit
-- vcs_tag_list()       - List all tags
-- vcs_blame()          - Show who last modified each row
-- ============================================================

-- ============================================================
-- VCS_LOG: View commit history for a branch
-- Equivalent to: git log
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_log(
    p_branch VARCHAR DEFAULT NULL,
    p_limit INT DEFAULT 20
)
RETURNS TABLE (
    commit_id INT,
    hash TEXT,
    branch TEXT,
    message TEXT,
    author TEXT,
    is_merge BOOLEAN,
    parent_commits TEXT,
    change_count BIGINT,
    committed_at TIMESTAMP
) AS $$
DECLARE
    v_branch VARCHAR(100);
BEGIN
    v_branch := COALESCE(p_branch, vcs_get_active_branch());
    
    RETURN QUERY
    SELECT 
        c.commit_id,
        LEFT(c.commit_hash, 8)::TEXT,
        c.branch_name::TEXT,
        c.message::TEXT,
        c.author::TEXT,
        c.is_merge,
        COALESCE(
            (SELECT string_agg('#' || cp.parent_commit_id::TEXT, ', ' ORDER BY cp.ordinal)
             FROM vcs_commit_parent cp WHERE cp.commit_id = c.commit_id),
            '-'
        )::TEXT,
        (SELECT COUNT(*) FROM vcs_change ch WHERE ch.commit_id = c.commit_id),
        c.committed_at
    FROM vcs_commit c
    WHERE c.branch_name = v_branch
    ORDER BY c.committed_at DESC, c.commit_id DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_LOG_ALL: View commit history across ALL branches
-- Equivalent to: git log --all --graph
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_log_all(
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    commit_id INT,
    hash TEXT,
    branch TEXT,
    message TEXT,
    author TEXT,
    is_merge BOOLEAN,
    change_count BIGINT,
    committed_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.commit_id,
        LEFT(c.commit_hash, 8)::TEXT,
        c.branch_name::TEXT,
        c.message::TEXT,
        c.author::TEXT,
        c.is_merge,
        (SELECT COUNT(*) FROM vcs_change ch WHERE ch.commit_id = c.commit_id),
        c.committed_at
    FROM vcs_commit c
    ORDER BY c.committed_at DESC, c.commit_id DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_SHOW: Show full details of a specific commit
-- Equivalent to: git show <commit>
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_show(
    p_commit_id INT
)
RETURNS TABLE (
    field TEXT,
    value TEXT
) AS $$
DECLARE
    v_rec RECORD;
BEGIN
    -- Get commit metadata
    SELECT * INTO v_rec FROM vcs_commit WHERE commit_id = p_commit_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commit #% not found', p_commit_id;
    END IF;
    
    -- Return structured output
    RETURN QUERY SELECT 'Commit'::TEXT, format('#%s (%s)', v_rec.commit_id, v_rec.commit_hash);
    RETURN QUERY SELECT 'Branch'::TEXT, v_rec.branch_name::TEXT;
    RETURN QUERY SELECT 'Author'::TEXT, v_rec.author::TEXT;
    RETURN QUERY SELECT 'Date'::TEXT, v_rec.committed_at::TEXT;
    RETURN QUERY SELECT 'Message'::TEXT, v_rec.message::TEXT;
    RETURN QUERY SELECT 'Is Merge'::TEXT, v_rec.is_merge::TEXT;
    
    -- Parents
    RETURN QUERY 
    SELECT 'Parent(s)'::TEXT, 
           COALESCE(string_agg('#' || cp.parent_commit_id::TEXT, ', '), 'none (root)')
    FROM vcs_commit_parent cp WHERE cp.commit_id = p_commit_id;
    
    -- Change summary
    RETURN QUERY
    SELECT 'Changes'::TEXT, 
           format('%s: %s %s(s)', ch.table_name, ch.operation, ch.row_pk)
    FROM vcs_change ch
    WHERE ch.commit_id = p_commit_id
    ORDER BY ch.changed_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_DIFF: Compare changes between two commits
-- Equivalent to: git diff <commitA> <commitB>
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_diff(
    p_commit_a INT,
    p_commit_b INT
)
RETURNS TABLE (
    table_name TEXT,
    row_pk TEXT,
    operation TEXT,
    changed_in_commit INT,
    changed_columns TEXT,
    old_value JSONB,
    new_value JSONB
) AS $$
BEGIN
    -- Validate commits exist
    IF NOT EXISTS (SELECT 1 FROM vcs_commit WHERE commit_id = p_commit_a) THEN
        RAISE EXCEPTION 'Commit #% not found', p_commit_a;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM vcs_commit WHERE commit_id = p_commit_b) THEN
        RAISE EXCEPTION 'Commit #% not found', p_commit_b;
    END IF;
    
    -- Return all changes between the two commits (inclusive range)
    RETURN QUERY
    SELECT 
        ch.table_name::TEXT,
        ch.row_pk::TEXT,
        ch.operation::TEXT,
        ch.commit_id,
        COALESCE(array_to_string(ch.changed_columns, ', '), '-')::TEXT,
        ch.old_data,
        ch.new_data
    FROM vcs_change ch
    JOIN vcs_commit co ON ch.commit_id = co.commit_id
    WHERE ch.commit_id > p_commit_a AND ch.commit_id <= p_commit_b
    ORDER BY ch.commit_id, ch.changed_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_DIFF_BRANCH: Compare all changes between two branches
-- Equivalent to: git diff branch1..branch2
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_diff_branch(
    p_branch_a VARCHAR,
    p_branch_b VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    table_name TEXT,
    row_pk TEXT,
    operation TEXT,
    branch TEXT,
    changed_columns TEXT,
    data JSONB
) AS $$
DECLARE
    v_branch_b VARCHAR(100);
BEGIN
    v_branch_b := COALESCE(p_branch_b, vcs_get_active_branch());
    
    -- Changes in branch_a that are NOT in branch_b
    RETURN QUERY
    (
        SELECT 
            ch.table_name::TEXT,
            ch.row_pk::TEXT,
            ch.operation::TEXT,
            co.branch_name::TEXT,
            COALESCE(array_to_string(ch.changed_columns, ', '), '-')::TEXT,
            COALESCE(ch.new_data, ch.old_data)
        FROM vcs_change ch
        JOIN vcs_commit co ON ch.commit_id = co.commit_id
        WHERE co.branch_name = p_branch_a
        AND NOT EXISTS (
            SELECT 1 FROM vcs_change ch2
            JOIN vcs_commit co2 ON ch2.commit_id = co2.commit_id
            WHERE co2.branch_name = v_branch_b
            AND ch2.table_name = ch.table_name 
            AND ch2.row_pk = ch.row_pk
        )
    )
    UNION ALL
    (
        SELECT 
            ch.table_name::TEXT,
            ch.row_pk::TEXT,
            ch.operation::TEXT,
            co.branch_name::TEXT,
            COALESCE(array_to_string(ch.changed_columns, ', '), '-')::TEXT,
            COALESCE(ch.new_data, ch.old_data)
        FROM vcs_change ch
        JOIN vcs_commit co ON ch.commit_id = co.commit_id
        WHERE co.branch_name = v_branch_b
        AND NOT EXISTS (
            SELECT 1 FROM vcs_change ch2
            JOIN vcs_commit co2 ON ch2.commit_id = co2.commit_id
            WHERE co2.branch_name = p_branch_a
            AND ch2.table_name = ch.table_name 
            AND ch2.row_pk = ch.row_pk
        )
    )
    ORDER BY 4, 1, 2;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_TAG_CREATE: Tag a specific commit
-- Equivalent to: git tag -a v1.0 -m "Release 1.0"
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_tag_create(
    p_tag_name VARCHAR,
    p_commit_id INT DEFAULT NULL,
    p_message TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_commit_id INT;
BEGIN
    v_commit_id := COALESCE(p_commit_id, vcs_get_head_commit());
    
    IF EXISTS (SELECT 1 FROM vcs_tag WHERE tag_name = p_tag_name) THEN
        RAISE EXCEPTION 'Tag "%" already exists', p_tag_name;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM vcs_commit WHERE commit_id = v_commit_id) THEN
        RAISE EXCEPTION 'Commit #% not found', v_commit_id;
    END IF;
    
    INSERT INTO vcs_tag (tag_name, commit_id, message) 
    VALUES (p_tag_name, v_commit_id, p_message);
    
    RETURN format('✅ Tag "%s" created at commit #%s', p_tag_name, v_commit_id);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_TAG_LIST: List all tags
-- Equivalent to: git tag -l
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_tag_list()
RETURNS TABLE (
    tag TEXT,
    commit_id INT,
    commit_hash TEXT,
    commit_branch TEXT,
    message TEXT,
    created_by TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tag_name::TEXT,
        t.commit_id,
        LEFT(c.commit_hash, 8)::TEXT,
        c.branch_name::TEXT,
        COALESCE(t.message, c.message)::TEXT,
        t.created_by::TEXT,
        t.created_at
    FROM vcs_tag t
    JOIN vcs_commit c ON t.commit_id = c.commit_id
    ORDER BY t.created_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_BLAME: Show who last modified each row in a table
-- Equivalent to: git blame <file>
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_blame(
    p_table_name VARCHAR,
    p_branch VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    row_pk TEXT,
    last_operation TEXT,
    last_commit_id INT,
    last_author TEXT,
    last_message TEXT,
    modified_at TIMESTAMP
) AS $$
DECLARE
    v_branch VARCHAR(100);
BEGIN
    v_branch := COALESCE(p_branch, vcs_get_active_branch());
    
    RETURN QUERY
    SELECT DISTINCT ON (ch.row_pk)
        ch.row_pk::TEXT,
        ch.operation::TEXT,
        co.commit_id,
        co.author::TEXT,
        LEFT(co.message, 60)::TEXT,
        co.committed_at
    FROM vcs_change ch
    JOIN vcs_commit co ON ch.commit_id = co.commit_id
    WHERE ch.table_name = p_table_name
    AND co.branch_name = v_branch
    ORDER BY ch.row_pk, co.committed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VCS_HISTORY: Show the full change history for a specific row
-- Equivalent to: git log -p -- <file> (for a row)
-- ============================================================
CREATE OR REPLACE FUNCTION vcs_row_history(
    p_table_name VARCHAR,
    p_row_pk TEXT
)
RETURNS TABLE (
    commit_id INT,
    branch TEXT,
    operation TEXT,
    changed_columns TEXT,
    old_data JSONB,
    new_data JSONB,
    author TEXT,
    committed_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        co.commit_id,
        co.branch_name::TEXT,
        ch.operation::TEXT,
        COALESCE(array_to_string(ch.changed_columns, ', '), '-')::TEXT,
        ch.old_data,
        ch.new_data,
        co.author::TEXT,
        co.committed_at
    FROM vcs_change ch
    JOIN vcs_commit co ON ch.commit_id = co.commit_id
    WHERE ch.table_name = p_table_name AND ch.row_pk = p_row_pk
    ORDER BY co.committed_at;
END;
$$ LANGUAGE plpgsql;

SELECT '✅ History functions created: vcs_log(), vcs_diff(), vcs_show(), vcs_tag_create(), vcs_blame(), vcs_row_history()' AS status;
