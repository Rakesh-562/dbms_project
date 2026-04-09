-- ============================================================
-- PATCH: Fix banking functions for retail_banking_setup_final schema
-- ============================================================

-- Fix bank_apply_loan: 'Active' → 'active', fix branch fallback
CREATE OR REPLACE FUNCTION bank_apply_loan(
    p_customer_id       INTEGER,
    p_requested_amount  DECIMAL,
    p_purpose           TEXT DEFAULT 'General purpose'
) RETURNS TEXT AS $$
DECLARE
    v_app_id      INT;
    v_officer_id  INTEGER;
    v_branch_id   INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM customer WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer "%" not found', p_customer_id;
    END IF;
    IF p_requested_amount <= 0 THEN
        RAISE EXCEPTION 'Loan amount must be positive';
    END IF;

    -- Find customer's branch from their active account
    SELECT a.branch_id INTO v_branch_id
      FROM account a
     WHERE a.customer_id = p_customer_id AND a.status = 'active'
     ORDER BY a.opened_date LIMIT 1;

    -- Fallback: customer's own branch
    IF v_branch_id IS NULL THEN
        SELECT branch_id INTO v_branch_id FROM customer WHERE customer_id = p_customer_id;
    END IF;

    -- Assign a loan officer from that branch
    SELECT emp_id INTO v_officer_id
      FROM employee
     WHERE branch_id = COALESCE(v_branch_id, 1)
       AND designation ILIKE '%Loan Officer%'
       AND status = 'active'
     ORDER BY emp_id LIMIT 1;

    -- Fallback: any active employee
    IF v_officer_id IS NULL THEN
        SELECT emp_id INTO v_officer_id
          FROM employee
         WHERE branch_id = COALESCE(v_branch_id, 1) AND status = 'active'
         ORDER BY emp_id LIMIT 1;
    END IF;

    INSERT INTO loan_application (customer_id, assigned_emp_id, requested_amount, purpose, status)
    VALUES (p_customer_id, v_officer_id, p_requested_amount, p_purpose, 'submitted')
    RETURNING application_id INTO v_app_id;

    RETURN format(
        'Loan application %s submitted. Customer: %s, Amount: ₹%s, Purpose: %s, Assigned to: %s',
        v_app_id, p_customer_id, p_requested_amount::NUMERIC(15,2),
        p_purpose, COALESCE(v_officer_id::TEXT, '(unassigned)')
    );
END;
$$ LANGUAGE plpgsql;

-- Fix bank_review_loan: remove references to customer_financials and loan_current
CREATE OR REPLACE FUNCTION bank_review_loan(
    p_app_id     INTEGER,
    p_emp_id     INTEGER,
    p_new_status VARCHAR,
    p_notes      TEXT DEFAULT NULL
) RETURNS TEXT AS $$
DECLARE
    v_app        loan_application%ROWTYPE;
    v_emp_role   VARCHAR(100);
BEGIN
    SELECT * INTO v_app FROM loan_application WHERE application_id = p_app_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application "%" not found', p_app_id;
    END IF;

    SELECT designation INTO v_emp_role FROM employee WHERE emp_id = p_emp_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee "%" not found', p_emp_id;
    END IF;

    -- Role check
    IF v_emp_role ILIKE '%Branch Manager%' THEN
        NULL; -- managers can do anything
    ELSIF v_emp_role ILIKE '%Loan Officer%' THEN
        IF v_app.assigned_emp_id != p_emp_id THEN
            RAISE EXCEPTION 'Application % is assigned to %, not you (%)',
                            p_app_id, v_app.assigned_emp_id, p_emp_id;
        END IF;
    ELSE
        RAISE EXCEPTION 'No permission — requires Loan Officer or Branch Manager';
    END IF;

    -- Update the application
    UPDATE loan_application
       SET status = p_new_status,
           reviewed_at = NOW(),
           decision_notes = COALESCE(p_notes, decision_notes),
           assigned_emp_id = p_emp_id
     WHERE application_id = p_app_id;

    -- If approved, create a loan record in the loan table
    IF p_new_status = 'approved' THEN
        INSERT INTO loan (
            customer_id, account_id, assigned_officer, loan_type,
            base_interest_rate, applied_amount, purpose,
            application_date, application_status, status
        )
        SELECT
            v_app.customer_id,
            (SELECT account_id FROM account WHERE customer_id = v_app.customer_id AND status = 'active' LIMIT 1),
            p_emp_id,
            'personal',
            8.50,
            v_app.requested_amount,
            v_app.purpose,
            v_app.application_date::date,
            'approved',
            'pending';
    END IF;

    RETURN format('Application %s updated to: %s', p_app_id, p_new_status);
END;
$$ LANGUAGE plpgsql;

-- Fix bank_mini_statement: use correct column names for new schema
CREATE OR REPLACE FUNCTION bank_mini_statement(
    p_account_id INTEGER,
    p_limit      INT DEFAULT 10
) RETURNS TABLE (
    txn_id      INT,
    txn_type    TEXT,
    amount      NUMERIC,
    direction   TEXT,
    txn_time    TIMESTAMP,
    balance     NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.txn_id,
        t.txn_type::TEXT,
        t.amount,
        CASE WHEN t.txn_type = 'credit' THEN 'CR' ELSE 'DR' END,
        t.txn_date,
        t.balance_after
    FROM transaction t
    WHERE t.account_id = p_account_id
    ORDER BY t.txn_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Fix bank_customer_summary: use current_balance and loan table
CREATE OR REPLACE FUNCTION bank_customer_summary(p_customer_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_name    TEXT;
    v_result  TEXT := '';
    rec       RECORD;
BEGIN
    SELECT full_name INTO v_name FROM customer WHERE customer_id = p_customer_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Customer "%" not found', p_customer_id; END IF;

    v_result := format('=== Customer Summary: %s (ID: %s) ===' || chr(10), v_name, p_customer_id);

    v_result := v_result || chr(10) || '--- Accounts ---' || chr(10);
    FOR rec IN (
        SELECT account_id, account_type, current_balance, status
        FROM account WHERE customer_id = p_customer_id ORDER BY opened_date
    ) LOOP
        v_result := v_result || format('  %s [%s] %s — ₹%s' || chr(10),
            rec.account_id, rec.account_type, rec.status, rec.current_balance::NUMERIC(15,2));
    END LOOP;

    v_result := v_result || chr(10) || '--- Active Loans ---' || chr(10);
    FOR rec IN (
        SELECT loan_id, loan_type, applied_amount, interest_rate, status
        FROM loan WHERE customer_id = p_customer_id ORDER BY application_date
    ) LOOP
        v_result := v_result || format('  %s [%s] ₹%s @%s%% — %s' || chr(10),
            rec.loan_id, rec.loan_type, rec.applied_amount::NUMERIC(15,2),
            COALESCE(rec.interest_rate, 0), rec.status);
    END LOOP;

    v_result := v_result || chr(10) || '--- Loan Applications ---' || chr(10);
    FOR rec IN (
        SELECT application_id, requested_amount, status, application_date
        FROM loan_application WHERE customer_id = p_customer_id ORDER BY application_date
    ) LOOP
        v_result := v_result || format('  %s ₹%s — %s (applied %s)' || chr(10),
            rec.application_id, rec.requested_amount::NUMERIC(15,2), rec.status,
            rec.application_date::DATE);
    END LOOP;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Fix bank_emp_queue: remove credit_score reference
CREATE OR REPLACE FUNCTION bank_emp_queue(p_emp_id INTEGER)
RETURNS TABLE (
    app_id          INT,
    customer_name   TEXT,
    amount          DECIMAL,
    app_status      TEXT,
    days_waiting    INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        la.application_id,
        c.full_name::TEXT,
        la.requested_amount,
        la.status::TEXT,
        EXTRACT(DAY FROM NOW() - la.application_date)::INT
    FROM loan_application la
    JOIN customer c ON c.customer_id = la.customer_id
    WHERE la.assigned_emp_id = p_emp_id
      AND la.status NOT IN ('approved','rejected')
    ORDER BY la.application_date;
END;
$$ LANGUAGE plpgsql;

SELECT '✅ All banking functions patched for retail_banking_setup_final schema' AS status;
