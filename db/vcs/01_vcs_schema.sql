-- ============================================================
-- GIT-LIKE DATABASE VERSIONING SYSTEM - SCHEMA
-- ============================================================
-- This creates the version control system (VCS) tables that
-- mirror Git concepts: repositories, branches, commits, 
-- changes (deltas), tags, and staging area.
-- ============================================================

-- CLEANUP
DROP TABLE IF EXISTS vcs_tag CASCADE;
DROP TABLE IF EXISTS vcs_staged_change CASCADE;
DROP TABLE IF EXISTS vcs_change CASCADE;
DROP TABLE IF EXISTS vcs_commit_parent CASCADE;
DROP TABLE IF EXISTS vcs_commit CASCADE;
DROP TABLE IF EXISTS vcs_branch CASCADE;
DROP TABLE IF EXISTS vcs_repository CASCADE;
DROP TABLE IF EXISTS vcs_config CASCADE;
DROP FUNCTION IF EXISTS vcs_trigger_fn() CASCADE;

-- ============================================================
-- A. VCS CONFIGURATION (Global settings like current branch)
-- ============================================================
CREATE TABLE vcs_config (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Default: active branch is 'main'
INSERT INTO vcs_config (key, value) VALUES 
    ('active_branch', 'main'),
    ('auto_track', 'true');

-- ============================================================
-- B. REPOSITORY (Tracked tables - like git init per table)
-- ============================================================
CREATE TABLE vcs_repository (
    repo_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) UNIQUE NOT NULL,
    primary_key_column VARCHAR(100) NOT NULL,
    tracked_since TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================
-- C. BRANCHES (Named pointers, just like git branches)
-- ============================================================
CREATE TABLE vcs_branch (
    branch_id SERIAL PRIMARY KEY,
    branch_name VARCHAR(100) UNIQUE NOT NULL,
    created_from_branch VARCHAR(100),       -- parent branch name
    created_from_commit_id INT,             -- fork point commit
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT
);

-- Create the default 'main' branch
INSERT INTO vcs_branch (branch_name, description) 
VALUES ('main', 'Default branch - production state');

-- ============================================================
-- D. COMMITS (Snapshots in time, like git commits)
-- ============================================================
CREATE TABLE vcs_commit (
    commit_id SERIAL PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL REFERENCES vcs_branch(branch_name),
    commit_hash VARCHAR(64),                -- SHA-256 style hash
    message TEXT NOT NULL,
    author VARCHAR(100) DEFAULT CURRENT_USER,
    committed_at TIMESTAMP DEFAULT NOW(),
    is_merge BOOLEAN DEFAULT FALSE
);

-- ============================================================
-- E. COMMIT PARENTS (For merge commits with multiple parents)
-- ============================================================
CREATE TABLE vcs_commit_parent (
    id SERIAL PRIMARY KEY,
    commit_id INT NOT NULL REFERENCES vcs_commit(commit_id),
    parent_commit_id INT NOT NULL REFERENCES vcs_commit(commit_id),
    ordinal INT DEFAULT 1                   -- 1=first parent, 2=second (merge source)
);

-- ============================================================
-- F. COMMITTED CHANGES (Permanent row-level deltas per commit)
--    Stores old & new row data as JSONB for full auditability
-- ============================================================
CREATE TABLE vcs_change (
    change_id SERIAL PRIMARY KEY,
    commit_id INT NOT NULL REFERENCES vcs_commit(commit_id),
    table_name VARCHAR(100) NOT NULL,
    row_pk TEXT NOT NULL,                    -- Primary key value of affected row
    operation VARCHAR(10) NOT NULL           -- INSERT, UPDATE, DELETE
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,                          -- NULL for INSERT
    new_data JSONB,                          -- NULL for DELETE
    changed_columns TEXT[],                  -- Array of changed column names (UPDATE only)
    changed_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- G. STAGING AREA (Uncommitted changes - like git add)
-- ============================================================
CREATE TABLE vcs_staged_change (
    staged_id SERIAL PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL REFERENCES vcs_branch(branch_name),
    table_name VARCHAR(100) NOT NULL,
    row_pk TEXT NOT NULL,
    operation VARCHAR(10) NOT NULL
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_columns TEXT[],
    staged_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- H. TAGS (Named immutable references to commits)
-- ============================================================
CREATE TABLE vcs_tag (
    tag_id SERIAL PRIMARY KEY,
    tag_name VARCHAR(100) UNIQUE NOT NULL,
    commit_id INT NOT NULL REFERENCES vcs_commit(commit_id),
    message TEXT,
    created_by VARCHAR(100) DEFAULT CURRENT_USER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_vcs_change_commit ON vcs_change(commit_id);
CREATE INDEX idx_vcs_change_table ON vcs_change(table_name);
CREATE INDEX idx_vcs_change_pk ON vcs_change(table_name, row_pk);
CREATE INDEX idx_vcs_staged_branch ON vcs_staged_change(branch_name);
CREATE INDEX idx_vcs_commit_branch ON vcs_commit(branch_name, committed_at);
CREATE INDEX idx_vcs_commit_hash ON vcs_commit(commit_hash);
CREATE INDEX idx_vcs_commit_parent ON vcs_commit_parent(commit_id);

-- ============================================================
-- INITIAL COMMIT on main (empty - represents genesis)
-- ============================================================
INSERT INTO vcs_commit (branch_name, commit_hash, message, author)
VALUES ('main', md5('genesis-' || NOW()::TEXT), 'Initial commit - system initialized', CURRENT_USER);

SELECT '✅ VCS Schema created successfully. System initialized with main branch.' AS status;
select* from vcs_config;