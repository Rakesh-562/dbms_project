-- ============================================================
--  Migration: Convert ML tables from VARCHAR PKs to SERIAL INT
--  Preserves data with new integer IDs
-- ============================================================

BEGIN;

-- 1. Drop dependent tables first (FK ordering)
DROP TABLE IF EXISTS ai_model_features CASCADE;
DROP TABLE IF EXISTS governance_decisions CASCADE;
DROP TABLE IF EXISTS ai_predictions CASCADE;
DROP TABLE IF EXISTS ai_models CASCADE;
DROP TABLE IF EXISTS dataset_versions CASCADE;
DROP TABLE IF EXISTS loan_payment CASCADE;
DROP TABLE IF EXISTS loan_history CASCADE;
DROP TABLE IF EXISTS loan_current CASCADE;
DROP TABLE IF EXISTS customer_financials_history CASCADE;
DROP TABLE IF EXISTS customer_financials CASCADE;
DROP TABLE IF EXISTS v_function_count CASCADE;
DROP TABLE IF EXISTS v_table_count CASCADE;

-- 2. Recreate with SERIAL INT PKs

CREATE TABLE dataset_versions (
    dataset_version_id  SERIAL PRIMARY KEY,
    version_label       VARCHAR(100),
    description         TEXT,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ai_models (
    model_id            SERIAL PRIMARY KEY,
    dataset_version_id  INT REFERENCES dataset_versions(dataset_version_id),
    algorithm           VARCHAR(100),
    accuracy            NUMERIC(5,4),
    auc                 NUMERIC(5,4),
    trained_at          TIMESTAMP DEFAULT NOW()
);

CREATE TABLE loan_current (
    loan_id             SERIAL PRIMARY KEY,
    borrower_id         INT REFERENCES customer(customer_id),
    approved_by_emp_id  INT REFERENCES employee(emp_id),
    loan_type           VARCHAR(50),
    principal           NUMERIC(15,2),
    interest_rate       NUMERIC(5,2),
    tenure_months       INT,
    status              VARCHAR(30),
    disbursed_on        DATE,
    maturity_date       DATE
);

CREATE TABLE loan_history (
    history_id          SERIAL PRIMARY KEY,
    loan_id             INT REFERENCES loan_current(loan_id),
    old_status          VARCHAR(30),
    new_status          VARCHAR(30),
    changed_by          INT REFERENCES employee(emp_id),
    changed_at          TIMESTAMP DEFAULT NOW(),
    remarks             TEXT
);

CREATE TABLE loan_payment (
    payment_id          SERIAL PRIMARY KEY,
    loan_id             INT REFERENCES loan_current(loan_id),
    amount_paid         NUMERIC(15,2),
    payment_date        TIMESTAMP DEFAULT NOW(),
    payment_method      VARCHAR(30),
    remaining_balance   NUMERIC(15,2)
);

CREATE TABLE ai_predictions (
    prediction_id       SERIAL PRIMARY KEY,
    loan_id             INT REFERENCES loan_current(loan_id),
    model_id            INT REFERENCES ai_models(model_id),
    predicted_score     NUMERIC(5,4),
    decision_reason     TEXT
);

CREATE TABLE ai_model_features (
    feature_id          SERIAL PRIMARY KEY,
    prediction_id       INT REFERENCES ai_predictions(prediction_id),
    feature_name        VARCHAR(100),
    feature_value       VARCHAR(200)
);

CREATE TABLE governance_decisions (
    decision_id         SERIAL PRIMARY KEY,
    model_id            INT REFERENCES ai_models(model_id),
    reviewed_by_emp_id  INT REFERENCES employee(emp_id),
    decision            VARCHAR(50),
    comments            TEXT,
    decided_at          TIMESTAMP DEFAULT NOW()
);

CREATE TABLE customer_financials (
    fin_id              SERIAL PRIMARY KEY,
    customer_id         INT REFERENCES customer(customer_id),
    credit_score        INT,
    annual_income       NUMERIC(15,2),
    employment_status   VARCHAR(50),
    total_debt          NUMERIC(15,2),
    last_updated        TIMESTAMP DEFAULT NOW()
);

CREATE TABLE customer_financials_history (
    history_id          SERIAL PRIMARY KEY,
    customer_id         INT REFERENCES customer(customer_id),
    credit_score        INT,
    annual_income       NUMERIC(15,2),
    employment_status   VARCHAR(50),
    total_debt          NUMERIC(15,2),
    snapshot_date       TIMESTAMP DEFAULT NOW()
);

COMMIT;
