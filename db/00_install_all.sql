-- ============================================================
-- GIT-LIKE DATABASE VERSIONING - COMPLETE INSTALLATION
-- ============================================================
-- Run this ONE file to install everything in the correct order.
-- Target database: bank_versioning
--
-- Usage:
--   psql -U postgres -c "CREATE DATABASE bank_versioning;"
--   psql -U postgres -d bank_versioning -f db/00_install_all.sql
-- ============================================================

\echo ''
\echo '=========================================='
\echo 'STEP 1/9: Creating banking database schema'
\echo '=========================================='
\i schema/retail_banking_setup_final.sql

\echo ''
\echo '=========================================='
\echo 'STEP 2/9: Installing VCS metadata schema'
\echo '=========================================='
\i vcs/01_vcs_schema.sql

\echo ''
\echo '=========================================='
\echo 'STEP 3/9: Installing core VCS functions'
\echo '=========================================='
\i vcs/02_vcs_core_functions.sql

\echo ''
\echo '=========================================='
\echo 'STEP 4/9: Installing branch & merge functions'
\echo '=========================================='
\i vcs/03_vcs_branch_functions.sql

\echo ''
\echo '=========================================='
\echo 'STEP 5/9: Installing history & diff functions'
\echo '=========================================='
\i vcs/04_vcs_history_functions.sql

\echo ''
\echo '=========================================='
\echo 'STEP 6/9: Installing rollback & time-travel functions'
\echo '=========================================='
\i vcs/05_vcs_rollback_functions.sql

\echo ''
\echo '=========================================='
\echo 'STEP 7/9: Installing banking layer (loan_application + 12 functions)'
\echo '=========================================='
\i functions/banking_layer.sql

-- Drop functions with conflicting return types before patching
DROP FUNCTION IF EXISTS bank_mini_statement(integer,integer);
DROP FUNCTION IF EXISTS bank_emp_queue(integer);

\echo ''
\echo '=========================================='
\echo 'STEP 8/9: Patching banking functions for schema compatibility'
\echo '=========================================='
\i functions/patch_functions.sql

\echo ''
\echo '=========================================='
\echo 'STEP 9/9: Installing views, RLS policies & roles'
\echo '=========================================='
\i schema/views.sql

-- Add password columns (default = full name)
ALTER TABLE employee ADD COLUMN IF NOT EXISTS password TEXT;
ALTER TABLE customer ADD COLUMN IF NOT EXISTS password TEXT;
UPDATE employee SET password = full_name WHERE password IS NULL;
UPDATE customer SET password = full_name WHERE password IS NULL;

\echo ''
\echo '=========================================='
\echo '  INSTALLATION COMPLETE'
\echo '=========================================='
\echo ''
