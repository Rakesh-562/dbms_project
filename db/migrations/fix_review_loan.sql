CREATE OR REPLACE FUNCTION bank_review_loan(
    p_app_id    INT,
    p_emp_id    INT,
    p_new_status VARCHAR,
    p_notes     TEXT DEFAULT NULL
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

    -- Branch Manager: can approve, reject, or mark under_review on any application
    IF v_emp_role = 'Branch Manager' THEN
        IF p_new_status NOT IN ('approved', 'rejected', 'under_review') THEN
            RAISE EXCEPTION 'Invalid status: %', p_new_status;
        END IF;

    -- Loan Officer (or any other employee): can ONLY mark as under_review on assigned apps
    ELSE
        IF v_app.assigned_emp_id <> p_emp_id THEN
            RAISE EXCEPTION 'You can only review applications assigned to you';
        END IF;
        IF p_new_status <> 'under_review' THEN
            RAISE EXCEPTION 'As an employee you can only set status to under_review. A manager must approve or reject.';
        END IF;
    END IF;

    -- Update the application
    UPDATE loan_application
       SET status       = p_new_status,
           reviewed_at  = NOW(),
           decision_notes = COALESCE(p_notes, decision_notes)
     WHERE application_id = p_app_id;

    -- If approved by manager, create the loan record
    IF p_new_status = 'approved' THEN
        INSERT INTO loan (customer_id, loan_type, amount, interest_rate, start_date, end_date, status)
        VALUES (v_app.customer_id, 'approved', v_app.requested_amount, 8.5, CURRENT_DATE, CURRENT_DATE + 365, 'approved');
    END IF;

    RETURN format('Application %s updated to: %s', p_app_id, p_new_status);
END;
$$ LANGUAGE plpgsql;
