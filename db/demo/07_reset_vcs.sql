-- ============================================================
--  RESET VCS SYSTEM — Retail Banking Branch (9 Tables)
--  Safe to run multiple times. Clears all VCS tracking data
--  and restores banking tables to original seed state.
--  Does NOT drop VCS tables or functions.
-- ============================================================

-- ============================================================
-- PART 1: REMOVE TRIGGERS from all tracked tables
-- ============================================================
DO $$
DECLARE
    tbl RECORD;
BEGIN
    FOR tbl IN (SELECT table_name FROM vcs_repository WHERE is_active = TRUE)
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS vcs_track_%I ON %I',
            tbl.table_name, tbl.table_name
        );
    END LOOP;
END $$;

-- ============================================================
-- PART 2: CLEAR ALL VCS DATA (preserve structure & functions)
-- ============================================================
TRUNCATE TABLE vcs_tag            CASCADE;
TRUNCATE TABLE vcs_staged_change  CASCADE;
TRUNCATE TABLE vcs_change         CASCADE;
TRUNCATE TABLE vcs_commit_parent  CASCADE;
TRUNCATE TABLE vcs_commit         CASCADE;
TRUNCATE TABLE vcs_branch         CASCADE;
TRUNCATE TABLE vcs_repository     CASCADE;

-- Reset config
DELETE FROM vcs_config;
INSERT INTO vcs_config (key, value) VALUES
    ('active_branch', 'main'),
    ('auto_track',    'true');

-- Recreate default main branch
INSERT INTO vcs_branch (branch_name, description)
VALUES ('main', 'Default branch - production state');

-- Recreate genesis commit
INSERT INTO vcs_commit (branch_name, commit_hash, message, author)
VALUES (
    'main',
    md5('genesis-' || NOW()::TEXT),
    'Initial commit - system initialized',
    CURRENT_USER
);

-- ============================================================
-- PART 3: REMOVE DEMO-ADDED BANKING ROWS
--         Delete in FK-safe order (children before parents)
-- ============================================================

-- Remove Vivek Chandran and all his data (lookup by name, not hardcoded ID)
DO $$
DECLARE
    v_cust_id INT;
    v_acct_id INT;
BEGIN
    -- Get real IDs
    SELECT customer_id INTO v_cust_id FROM customer WHERE full_name = 'Vivek Chandran' LIMIT 1;
    SELECT account_id  INTO v_acct_id FROM account  WHERE account_number = 'SB10000000007' LIMIT 1;

    IF v_acct_id IS NOT NULL THEN
        DELETE FROM transaction   WHERE account_id = v_acct_id AND reference_number = 'REF20240120001';
        DELETE FROM loan          WHERE account_id = v_acct_id;
        DELETE FROM fund_transfer WHERE from_account_id = v_acct_id OR to_account_id = v_acct_id;
        DELETE FROM account       WHERE account_id = v_acct_id;
    END IF;

    IF v_cust_id IS NOT NULL THEN
        DELETE FROM customer WHERE customer_id = v_cust_id;
    END IF;
END $$;

DELETE FROM fund_transfer WHERE remarks LIKE 'LOAN RESTRUCTURE MEMO%';

-- Remove any wrong/demo HR update entries
DELETE FROM employee_hr_update
WHERE reason LIKE 'DATA ENTRY ERROR%'
   OR reason LIKE 'Outstanding appraisal%'
   OR reason LIKE 'WRONG:%';

-- ============================================================
-- PART 4: RESTORE MODIFIED BANKING ROWS TO SEED VALUES
-- ============================================================

-- Employee: Manoj Krishnan — restore contract + original salary
UPDATE employee SET
    employment_type = 'contract',
    salary          = 38000
WHERE emp_id = 6;

-- Employee: Priya Menon — restore salary (undo wrong entry)
UPDATE employee SET
    salary = 65000
WHERE emp_id = 2;

-- Accounts: restore savings interest rate to 3.50%
UPDATE account SET
    interest_rate = 3.50
WHERE account_type = 'savings';

-- Account: restore Rajan Varma account to dormant
UPDATE account SET
    status = 'dormant'
WHERE customer_id = 5;

-- Customer: restore Rajan Varma to expired KYC + dormant
UPDATE customer SET
    kyc_status = 'expired',
    status     = 'dormant'
WHERE customer_id = 5;

-- Loan: restore Arjun Pillai home loan to original terms
UPDATE loan SET
    tenure_months         = 240,
    emi_amount            = 39204,
    interest_rate         = 8.50,
    application_status    = 'disbursed',
    sanctioned_amount     = 4500000,
    disbursed_amount      = 4500000,
    outstanding_principal = 4388000,
    status                = 'active'
WHERE loan_id = 1;

-- Loan: restore Meena Suresh personal loan to approved/pending
UPDATE loan SET
    application_status    = 'approved',
    sanctioned_amount     = NULL,
    disbursed_amount      = NULL,
    interest_rate         = NULL,
    tenure_months         = NULL,
    emi_amount            = NULL,
    disbursement_date     = NULL,
    maturity_date         = NULL,
    outstanding_principal = NULL,
    status                = 'pending'
WHERE loan_id = 3;

-- ============================================================
-- PART 5: VERIFY — show restored state
-- ============================================================
SELECT '✅ VCS reset complete. Banking data restored to seed state.' AS status;

SELECT 'Customers after reset: ' || COUNT(*)::TEXT AS check_customers FROM customer;
SELECT 'Accounts after reset:  ' || COUNT(*)::TEXT AS check_accounts  FROM account;
SELECT 'Employees after reset: ' || COUNT(*)::TEXT AS check_employees FROM employee;
SELECT 'Loans after reset:     ' || COUNT(*)::TEXT AS check_loans     FROM loan;
SELECT 'VCS commits:           ' || COUNT(*)::TEXT AS check_commits   FROM vcs_commit;
SELECT 'VCS branches:          ' || COUNT(*)::TEXT AS check_branches  FROM vcs_branch;