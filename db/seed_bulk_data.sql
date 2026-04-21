-- ============================================================
-- BULK SEED DATA for search demo
-- Inserts ~50 customers, ~60 accounts, ~200 transactions,
-- ~30 loans, ~20 transfers across multiple branches
-- ============================================================

-- ── Additional Branches ──
INSERT INTO branch (branch_name, ifsc_code, address, city, state, pincode, phone, email, established_date) VALUES
('Ernakulam City Branch',   'SBIN0002345', '22 MG Road, Marine Drive',      'Ernakulam',    'Kerala',       '682011', '0484-2361234', 'ernakulam.city@sbi.co.in',    '2008-06-15'),
('Trivandrum Main Branch',  'SBIN0003456', '45 Statue Junction, MG Road',   'Trivandrum',   'Kerala',       '695001', '0471-2334567', 'trivandrum.main@sbi.co.in',   '2003-01-20'),
('Kozhikode Town Branch',   'SBIN0004567', '18 SM Street, Mananchira',      'Kozhikode',    'Kerala',       '673001', '0495-2721234', 'kozhikode.town@sbi.co.in',    '2010-09-10'),
('Thrissur Round Branch',   'SBIN0005678', '7 Round East, Swaraj',          'Thrissur',     'Kerala',       '680001', '0487-2421234', 'thrissur.round@sbi.co.in',    '2012-03-25'),
('Chennai Anna Nagar',      'SBIN0006789', '112 2nd Avenue, Anna Nagar',    'Chennai',      'Tamil Nadu',   '600040', '044-26214567',  'chennai.annanagar@sbi.co.in', '2006-11-01'),
('Bangalore Koramangala',   'SBIN0007890', '80 Feet Road, 4th Block',       'Bangalore',    'Karnataka',    '560034', '080-25634567',  'blr.koramangala@sbi.co.in',   '2009-04-15'),
('Mumbai Andheri West',     'SBIN0008901', '15 Lokhandwala Complex',        'Mumbai',       'Maharashtra',  '400058', '022-26284567',  'mumbai.andheri@sbi.co.in',    '2001-08-20'),
('Hyderabad Banjara Hills', 'SBIN0009012', 'Road No 12, Banjara Hills',    'Hyderabad',    'Telangana',    '500034', '040-23354567',  'hyd.banjara@sbi.co.in',       '2007-02-14');

-- ── Additional Employees ──
INSERT INTO employee (branch_id, full_name, designation, dept_id, manager_id, join_date, salary, employment_type, status, password) VALUES
-- Ernakulam branch (branch_id depends on insert order; we'll use currval)
(2, 'Deepak Menon',      'Branch Manager',              1, NULL, '2012-04-01', 95000,  'permanent', 'active', 'Deepak Menon'),
(2, 'Reshma Nair',       'Senior Relationship Manager',  1, 8,   '2016-07-15', 62000,  'permanent', 'active', 'Reshma Nair'),
(2, 'Ajith Kumar',       'Loan Officer',                 2, 8,   '2018-03-20', 48000,  'permanent', 'active', 'Ajith Kumar'),
(3, 'Lakshmi Devi',      'Branch Manager',               1, NULL,'2010-01-10', 98000,  'permanent', 'active', 'Lakshmi Devi'),
(3, 'Vishnu Prasad',     'Relationship Manager',         1, 11,  '2019-06-01', 45000,  'permanent', 'active', 'Vishnu Prasad'),
(4, 'Rahul Sharma',      'Branch Manager',               1, NULL,'2014-09-15', 92000,  'permanent', 'active', 'Rahul Sharma'),
(4, 'Sneha Krishnan',    'Loan Officer',                 2, 13,  '2020-02-01', 44000,  'permanent', 'active', 'Sneha Krishnan'),
(5, 'Thomas Mathew',     'Branch Manager',               1, NULL,'2011-05-20', 96000,  'permanent', 'active', 'Thomas Mathew'),
(5, 'Divya Pillai',      'Operations Executive',         3, 15,  '2021-01-10', 38000,  'contract',  'active', 'Divya Pillai'),
(6, 'Kavitha Rajan',     'Branch Manager',               1, NULL,'2009-11-01', 105000, 'permanent', 'active', 'Kavitha Rajan'),
(6, 'Arjun Reddy',       'Relationship Manager',         1, 17,  '2017-08-15', 55000,  'permanent', 'active', 'Arjun Reddy'),
(7, 'Pradeep Kumar',     'Branch Manager',               1, NULL,'2008-03-01', 110000, 'permanent', 'active', 'Pradeep Kumar'),
(7, 'Neha Gupta',        'Loan Officer',                 2, 19,  '2019-09-01', 52000,  'permanent', 'active', 'Neha Gupta'),
(8, 'Sanjay Patil',      'Branch Manager',               1, NULL,'2005-07-15', 115000, 'permanent', 'active', 'Sanjay Patil'),
(8, 'Meera Deshmukh',    'Senior Relationship Manager',  1, 21,  '2015-04-01', 68000,  'permanent', 'active', 'Meera Deshmukh'),
(9, 'Ravi Teja',         'Branch Manager',               1, NULL,'2007-12-01', 108000, 'permanent', 'active', 'Ravi Teja'),
(9, 'Sunitha Reddy',     'Relationship Manager',         1, 23,  '2018-06-15', 50000,  'permanent', 'active', 'Sunitha Reddy');

-- ── Bulk Customers (50 customers across branches) ──
INSERT INTO customer (branch_id, assigned_rm_id, full_name, dob, gender, phone, email, occupation, income_bracket, aadhaar_number, pan_number, kyc_status, customer_since, status, password) VALUES
(1, 2,  'Anu Mathew',        '1990-03-15', 'F', '9876543001', 'anu.mathew@email.com',        'Software Engineer',       '10L_25L',   '100000000001', 'ABCAM1001A', 'verified', '2020-01-10', 'active', 'Anu Mathew'),
(1, 2,  'Bipin Chandran',    '1985-07-22', 'M', '9876543002', 'bipin.c@email.com',            'Teacher',                 '5L_10L',    '100000000002', 'ABCBC1002B', 'verified', '2019-05-20', 'active', 'Bipin Chandran'),
(2, 9,  'Chithra Nair',      '1992-11-08', 'F', '9876543003', 'chithra.nair@email.com',       'Doctor',                  'above_25L', '100000000003', 'ABCCN1003C', 'verified', '2018-03-15', 'active', 'Chithra Nair'),
(2, 9,  'Dileep Kumar',      '1988-01-30', 'M', '9876543004', 'dileep.k@email.com',           'Chartered Accountant',    '10L_25L',   '100000000004', 'ABCDK1004D', 'verified', '2021-06-01', 'active', 'Dileep Kumar'),
(2, 9,  'Fathima Beevi',     '1995-04-17', 'F', '9876543006', 'fathima.b@email.com',          'Pharmacist',              '5L_10L',    '100000000006', 'ABCFB1006F', 'verified', '2022-01-20', 'active', 'Fathima Beevi'),
(3, 12, 'Gopika Menon',      '1991-09-25', 'F', '9876543007', 'gopika.m@email.com',           'Lawyer',                  '10L_25L',   '100000000007', 'ABCGM1007G', 'verified', '2019-08-10', 'active', 'Gopika Menon'),
(3, 12, 'Hari Krishnan',     '1987-12-03', 'M', '9876543008', 'hari.k@email.com',             'Business Owner',          'above_25L', '100000000008', 'ABCHK1008H', 'verified', '2017-02-28', 'active', 'Hari Krishnan'),
(3, 12, 'Indira Varma',      '1993-06-14', 'F', '9876543009', 'indira.v@email.com',           'Architect',               '10L_25L',   '100000000009', 'ABCIV1009I', 'verified', '2020-11-05', 'active', 'Indira Varma'),
(4, 14, 'Jayesh Patel',      '1986-08-20', 'M', '9876543010', 'jayesh.p@email.com',           'Real Estate Agent',       '10L_25L',   '100000000010', 'ABCJP1010J', 'verified', '2018-09-15', 'active', 'Jayesh Patel'),
(4, 14, 'Kavya Suresh',      '1994-02-11', 'F', '9876543011', 'kavya.s@email.com',            'Data Scientist',          '10L_25L',   '100000000011', 'ABCKS1011K', 'verified', '2021-04-22', 'active', 'Kavya Suresh'),
(4, 14, 'Lal Mohan',         '1980-10-05', 'M', '9876543012', 'lal.mohan@email.com',          'Retired Professor',       '5L_10L',    '100000000012', 'ABCLM1012L', 'verified', '2015-07-01', 'active', 'Lal Mohan'),
(5, 16, 'Meenakshi Amma',    '1975-05-30', 'F', '9876543013', 'meenakshi.a@email.com',        'Retired Nurse',           '2L_5L',     '100000000013', 'ABCMA1013M', 'verified', '2010-03-20', 'active', 'Meenakshi Amma'),
(5, 16, 'Naveen Thomas',     '1989-07-18', 'M', '9876543014', 'naveen.t@email.com',           'Civil Engineer',          '10L_25L',   '100000000014', 'ABCNT1014N', 'verified', '2019-12-01', 'active', 'Naveen Thomas'),
(5, 16, 'Oommen Philip',     '1982-03-27', 'M', '9876543015', 'oommen.p@email.com',           'Government Officer',      '5L_10L',    '100000000015', 'ABCOP1015O', 'verified', '2016-06-15', 'active', 'Oommen Philip'),
(6, 18, 'Preethi Raj',       '1996-01-09', 'F', '9876543016', 'preethi.r@email.com',          'Marketing Manager',       '10L_25L',   '100000000016', 'ABCPR1016P', 'verified', '2022-02-10', 'active', 'Preethi Raj'),
(6, 18, 'Ramesh Babu',       '1984-11-22', 'M', '9876543017', 'ramesh.b@email.com',           'Restaurant Owner',        '5L_10L',    '100000000017', 'ABCRB1017Q', 'verified', '2017-10-05', 'active', 'Ramesh Babu'),
(6, 18, 'Sunita Sharma',     '1990-08-03', 'F', '9876543018', 'sunita.s@email.com',           'Dentist',                 '10L_25L',   '100000000018', 'ABCSS1018R', 'verified', '2020-07-20', 'active', 'Sunita Sharma'),
(7, 20, 'Tarun Gupta',       '1983-04-16', 'M', '9876543019', 'tarun.g@email.com',            'Stock Broker',            'above_25L', '100000000019', 'ABCTG1019S', 'verified', '2016-01-15', 'active', 'Tarun Gupta'),
(7, 20, 'Uma Devi',          '1978-12-28', 'F', '9876543020', 'uma.d@email.com',              'School Principal',        '5L_10L',    '100000000020', 'ABCUD1020T', 'verified', '2012-09-01', 'active', 'Uma Devi'),
(7, 20, 'Vijay Malhotra',    '1991-06-07', 'M', '9876543021', 'vijay.m@email.com',            'IT Consultant',           '10L_25L',   '100000000021', 'ABCVM1021U', 'verified', '2021-03-10', 'active', 'Vijay Malhotra'),
(8, 22, 'Waseem Ahmed',      '1987-09-19', 'M', '9876543022', 'waseem.a@email.com',           'Textile Merchant',        '10L_25L',   '100000000022', 'ABCWA1022V', 'verified', '2018-11-25', 'active', 'Waseem Ahmed'),
(8, 22, 'Yamuna Krishnan',   '1993-02-14', 'F', '9876543023', 'yamuna.k@email.com',           'Fashion Designer',        '5L_10L',    '100000000023', 'ABCYK1023W', 'verified', '2020-05-10', 'active', 'Yamuna Krishnan'),
(8, 22, 'Zakir Hussain',     '1981-07-04', 'M', '9876543024', 'zakir.h@email.com',            'Automobile Dealer',       'above_25L', '100000000024', 'ABCZH1024X', 'verified', '2015-02-20', 'active', 'Zakir Hussain'),
(9, 24, 'Aditi Rao',         '1994-10-31', 'F', '9876543025', 'aditi.r@email.com',            'Film Producer',           'above_25L', '100000000025', 'ABCAR1025Y', 'verified', '2019-04-15', 'active', 'Aditi Rao'),
(9, 24, 'Bharath Kumar',     '1986-05-23', 'M', '9876543026', 'bharath.k@email.com',          'Mechanical Engineer',     '5L_10L',    '100000000026', 'ABCBK1026Z', 'verified', '2017-08-30', 'active', 'Bharath Kumar'),
(9, 24, 'Chandini Menon',    '1997-08-12', 'F', '9876543027', 'chandini.m@email.com',         'Content Creator',         '5L_10L',    '100000000027', 'ABCCM1027A', 'verified', '2022-06-01', 'active', 'Chandini Menon'),
(1, 2,  'Dev Anand',         '1979-03-10', 'M', '9876543028', 'dev.a@email.com',              'Retired Army Officer',    '5L_10L',    '100000000028', 'ABCDA1028B', 'verified', '2014-12-01', 'active', 'Dev Anand'),
(2, 9,  'Elsa Thomas',       '1998-01-25', 'F', '9876543029', 'elsa.t@email.com',             'Nurse',                   '2L_5L',     '100000000029', 'ABCET1029C', 'verified', '2023-01-05', 'active', 'Elsa Thomas'),
(3, 12, 'Faizal Khan',       '1985-06-18', 'M', '9876543030', 'faizal.k@email.com',           'Shipping Agent',          '10L_25L',   '100000000030', 'ABCFK1030D', 'verified', '2016-10-20', 'active', 'Faizal Khan'),
(4, 14, 'Gayathri Nair',     '1992-12-07', 'F', '9876543031', 'gayathri.n@email.com',         'Bank Auditor',            '10L_25L',   '100000000031', 'ABCGN1031E', 'verified', '2020-08-15', 'active', 'Gayathri Nair'),
(5, 16, 'Harish Menon',      '1988-04-02', 'M', '9876543032', 'harish.m@email.com',           'Journalist',              '5L_10L',    '100000000032', 'ABCHM1032F', 'verified', '2018-05-10', 'active', 'Harish Menon'),
(6, 18, 'Ishwarya Lakshmi',  '1995-09-20', 'F', '9876543033', 'ishwarya.l@email.com',         'UI/UX Designer',          '10L_25L',   '100000000033', 'ABCIL1033G', 'verified', '2021-11-01', 'active', 'Ishwarya Lakshmi'),
(7, 20, 'Jobin Mathew',      '1983-02-16', 'M', '9876543034', 'jobin.m@email.com',            'Plumber (Self-employed)', '2L_5L',     '100000000034', 'ABCJM1034H', 'verified', '2015-06-25', 'active', 'Jobin Mathew'),
(8, 22, 'Keerthi Suresh',    '1996-10-17', 'F', '9876543035', 'keerthi.s@email.com',          'Actress',                 'above_25L', '100000000035', 'ABCKS1035I', 'verified', '2019-09-10', 'active', 'Keerthi Suresh'),
(9, 24, 'Lijin George',      '1990-07-08', 'M', '9876543036', 'lijin.g@email.com',            'Electrician',             '2L_5L',     '100000000036', 'ABCLG1036J', 'verified', '2020-04-01', 'active', 'Lijin George'),
(1, 2,  'Manisha Pillai',    '1987-11-14', 'F', '9876543037', 'manisha.p@email.com',          'HR Manager',              '10L_25L',   '100000000037', 'ABCMP1037K', 'verified', '2017-01-15', 'active', 'Manisha Pillai'),
(2, 9,  'Nikhil Das',        '1993-05-29', 'M', '9876543038', 'nikhil.d@email.com',           'Physiotherapist',         '5L_10L',    '100000000038', 'ABCND1038L', 'verified', '2021-07-20', 'active', 'Nikhil Das'),
(3, 12, 'Padmini Varma',     '1976-08-11', 'F', '9876543039', 'padmini.v@email.com',          'Retired Judge',           '10L_25L',   '100000000039', 'ABCPV1039M', 'verified', '2008-03-01', 'active', 'Padmini Varma'),
(4, 14, 'Rajeev Pillai',     '1984-01-05', 'M', '9876543040', 'rajeev.p@email.com',           'Airline Pilot',           'above_25L', '100000000040', 'ABCRP1040N', 'verified', '2016-11-10', 'active', 'Rajeev Pillai'),
(5, 16, 'Saritha Nair',      '1991-06-22', 'F', '9876543041', 'saritha.n@email.com',          'Veterinarian',            '5L_10L',    '100000000041', 'ABCSN1041O', 'verified', '2019-02-15', 'active', 'Saritha Nair'),
(6, 18, 'Ullas Krishnan',    '1989-12-30', 'M', '9876543042', 'ullas.k@email.com',            'Gym Trainer',             '2L_5L',     '100000000042', 'ABCUK1042P', 'verified', '2022-03-05', 'active', 'Ullas Krishnan'),
(7, 20, 'Veena Menon',       '1994-04-18', 'F', '9876543043', 'veena.m@email.com',            'Travel Agent',            '5L_10L',    '100000000043', 'ABCVM1043Q', 'verified', '2020-10-01', 'active', 'Veena Menon'),
(8, 22, 'Xavier Joseph',     '1982-09-07', 'M', '9876543044', 'xavier.j@email.com',           'Plantation Owner',        '10L_25L',   '100000000044', 'ABCXJ1044R', 'verified', '2013-07-15', 'active', 'Xavier Joseph');

-- ── Bulk Accounts (1-2 per new customer) ──
-- We'll use a DO block to create accounts dynamically for all customers without existing accounts
DO $$
DECLARE
    r RECORD;
    v_acct_num VARCHAR(20);
    v_seq INT := 100;
BEGIN
    FOR r IN (
        SELECT c.customer_id, c.branch_id, c.full_name
        FROM customer c
        LEFT JOIN account a ON a.customer_id = c.customer_id
        WHERE a.account_id IS NULL
        ORDER BY c.customer_id
    ) LOOP
        v_seq := v_seq + 1;
        v_acct_num := 'SB' || LPAD(v_seq::TEXT, 10, '0');
        INSERT INTO account (customer_id, branch_id, opened_by, account_number, account_type, min_balance, interest_rate, opened_date, current_balance, status)
        VALUES (r.customer_id, r.branch_id, 1, v_acct_num, 'savings', 1000, 4.00,
                CURRENT_DATE - (random() * 1000)::INT, 10000 + (random() * 500000)::NUMERIC(15,2), 'active');
        -- Give some customers a second (current) account
        IF random() > 0.6 THEN
            v_seq := v_seq + 1;
            v_acct_num := 'CA' || LPAD(v_seq::TEXT, 10, '0');
            INSERT INTO account (customer_id, branch_id, opened_by, account_number, account_type, min_balance, interest_rate, opened_date, current_balance, status)
            VALUES (r.customer_id, r.branch_id, 1, v_acct_num, 'current', 5000, 0.00,
                    CURRENT_DATE - (random() * 800)::INT, 25000 + (random() * 1000000)::NUMERIC(15,2), 'active');
        END IF;
    END LOOP;
    RAISE NOTICE 'Created accounts up to seq %', v_seq;
END $$;

-- ── Bulk Transactions (~200 across all accounts) ──
DO $$
DECLARE
    r RECORD;
    i INT;
    v_amt NUMERIC(15,2);
    v_bal NUMERIC(15,2);
    v_type VARCHAR(10);
    v_channel VARCHAR(20);
    v_channels VARCHAR[] := ARRAY['branch','atm','upi','neft','rtgs','imps'];
    v_descs_credit TEXT[] := ARRAY['Salary credit','Freelance payment','Cash deposit','Refund from merchant','Interest credit','Insurance claim','Rental income','Dividend credit','FD maturity credit','Gift received'];
    v_descs_debit TEXT[] := ARRAY['Grocery purchase','Electricity bill','Mobile recharge','EMI payment','Fuel station','Online shopping','Restaurant bill','Medical expense','School fees','Insurance premium','Water bill','Internet subscription','Cab fare','Movie tickets','Gym membership'];
    v_desc TEXT;
    v_ref VARCHAR(40);
BEGIN
    FOR r IN (SELECT account_id, current_balance FROM account WHERE status = 'active' ORDER BY account_id) LOOP
        v_bal := r.current_balance;
        FOR i IN 1..( 3 + (random()*6)::INT ) LOOP
            IF random() > 0.4 THEN
                v_type := 'debit';
                v_amt := (100 + random() * 15000)::NUMERIC(15,2);
                v_desc := v_descs_debit[1 + (random() * (array_length(v_descs_debit,1)-1))::INT];
                IF v_amt > v_bal THEN v_amt := (v_bal * 0.3)::NUMERIC(15,2); END IF;
                IF v_amt <= 0 THEN CONTINUE; END IF;
                v_bal := v_bal - v_amt;
            ELSE
                v_type := 'credit';
                v_amt := (500 + random() * 50000)::NUMERIC(15,2);
                v_desc := v_descs_credit[1 + (random() * (array_length(v_descs_credit,1)-1))::INT];
                v_bal := v_bal + v_amt;
            END IF;
            v_channel := v_channels[1 + (random() * (array_length(v_channels,1)-1))::INT];
            v_ref := 'REF' || md5(random()::TEXT || i || r.account_id);
            INSERT INTO transaction (account_id, txn_type, channel, amount, balance_after, reference_number, txn_date, description, initiated_by)
            VALUES (r.account_id, v_type, v_channel, v_amt, v_bal, LEFT(v_ref,38),
                    NOW() - (random() * INTERVAL '365 days'), v_desc, NULL);
        END LOOP;
        UPDATE account SET current_balance = v_bal WHERE account_id = r.account_id;
    END LOOP;
END $$;

-- ── Bulk Loans (30 across customers) ──
DO $$
DECLARE
    r RECORD;
    v_type VARCHAR(30);
    v_types VARCHAR[] := ARRAY['home','personal','vehicle','education','gold'];
    v_statuses VARCHAR[] := ARRAY['submitted','under_review','approved','disbursed','disbursed','disbursed'];
    v_status VARCHAR(20);
    v_amt NUMERIC(15,2);
    v_rate NUMERIC(5,2);
    v_tenure INT;
    v_i INT := 0;
BEGIN
    FOR r IN (
        SELECT c.customer_id, a.account_id, c.branch_id
        FROM customer c
        JOIN account a ON a.customer_id = c.customer_id
        WHERE c.status = 'active'
        ORDER BY random()
        LIMIT 30
    ) LOOP
        v_i := v_i + 1;
        v_type := v_types[1 + (random() * (array_length(v_types,1)-1))::INT];
        v_status := v_statuses[1 + (random() * (array_length(v_statuses,1)-1))::INT];
        v_amt := CASE v_type
            WHEN 'home'      THEN 2000000 + (random()*5000000)::NUMERIC(15,2)
            WHEN 'vehicle'   THEN 300000 + (random()*1200000)::NUMERIC(15,2)
            WHEN 'education' THEN 200000 + (random()*800000)::NUMERIC(15,2)
            WHEN 'personal'  THEN 50000 + (random()*500000)::NUMERIC(15,2)
            WHEN 'gold'      THEN 50000 + (random()*300000)::NUMERIC(15,2)
        END;
        v_rate := CASE v_type
            WHEN 'home'      THEN 7.50 + (random()*2)::NUMERIC(5,2)
            WHEN 'vehicle'   THEN 8.00 + (random()*3)::NUMERIC(5,2)
            WHEN 'education' THEN 6.50 + (random()*2)::NUMERIC(5,2)
            WHEN 'personal'  THEN 10.00 + (random()*4)::NUMERIC(5,2)
            WHEN 'gold'      THEN 7.00 + (random()*2)::NUMERIC(5,2)
        END;
        v_tenure := CASE v_type
            WHEN 'home' THEN 120 + (random()*180)::INT
            WHEN 'vehicle' THEN 36 + (random()*48)::INT
            WHEN 'education' THEN 48 + (random()*72)::INT
            WHEN 'personal' THEN 12 + (random()*48)::INT
            WHEN 'gold' THEN 6 + (random()*18)::INT
        END;
        INSERT INTO loan (
            customer_id, account_id, assigned_officer, loan_type,
            base_interest_rate, applied_amount, purpose,
            application_date, application_status,
            sanctioned_amount, interest_rate, tenure_months, emi_amount,
            disbursement_date, outstanding_principal, status
        ) VALUES (
            r.customer_id, r.account_id, 1, v_type,
            v_rate, v_amt,
            CASE v_type
                WHEN 'home' THEN 'House purchase / construction'
                WHEN 'vehicle' THEN 'New vehicle purchase'
                WHEN 'education' THEN 'Higher education abroad'
                WHEN 'personal' THEN 'Personal expenses'
                WHEN 'gold' THEN 'Gold-backed short term loan'
            END,
            CURRENT_DATE - (random()*300)::INT, v_status,
            CASE WHEN v_status IN ('approved','disbursed') THEN v_amt * 0.95 ELSE NULL END,
            CASE WHEN v_status IN ('approved','disbursed') THEN v_rate ELSE NULL END,
            CASE WHEN v_status IN ('approved','disbursed') THEN v_tenure ELSE NULL END,
            CASE WHEN v_status IN ('approved','disbursed') THEN (v_amt * (v_rate/1200) * POWER(1+v_rate/1200, v_tenure)) / (POWER(1+v_rate/1200, v_tenure)-1) ELSE NULL END,
            CASE WHEN v_status = 'disbursed' THEN CURRENT_DATE - (random()*100)::INT ELSE NULL END,
            CASE WHEN v_status = 'disbursed' THEN v_amt * (0.5 + random()*0.5)::NUMERIC(15,2) ELSE NULL END,
            CASE WHEN v_status = 'disbursed' THEN 'active'
                 WHEN v_status IN ('approved','under_review','submitted') THEN 'pending'
                 ELSE 'pending' END
        );
    END LOOP;
    RAISE NOTICE 'Inserted % loans', v_i;
END $$;

-- ── Bulk Fund Transfers ──
DO $$
DECLARE
    v_from INT;
    v_to INT;
    v_amt NUMERIC(15,2);
    i INT;
    v_modes VARCHAR[] := ARRAY['neft','rtgs','imps','upi','internal'];
BEGIN
    FOR i IN 1..25 LOOP
        SELECT account_id INTO v_from FROM account WHERE status='active' ORDER BY random() LIMIT 1;
        SELECT account_id INTO v_to FROM account WHERE status='active' AND account_id != v_from ORDER BY random() LIMIT 1;
        v_amt := (500 + random()*50000)::NUMERIC(15,2);
        INSERT INTO fund_transfer (from_account_id, to_account_id, transfer_mode, amount, status, initiated_at, remarks)
        VALUES (v_from, v_to, v_modes[1+(random()*4)::INT], v_amt,
                CASE WHEN random()>0.1 THEN 'completed' ELSE 'failed' END,
                NOW() - (random()*INTERVAL '180 days'),
                'Bulk seed transfer #' || i);
    END LOOP;
END $$;

-- ── Fix sequences after bulk insert ──
SELECT setval('branch_branch_id_seq',       (SELECT MAX(branch_id) FROM branch));
SELECT setval('customer_customer_id_seq',   (SELECT MAX(customer_id) FROM customer));
SELECT setval('employee_emp_id_seq',        (SELECT MAX(emp_id) FROM employee));
SELECT setval('account_account_id_seq',     (SELECT MAX(account_id) FROM account));
SELECT setval('department_dept_id_seq',     (SELECT MAX(dept_id) FROM department));
SELECT setval('loan_loan_id_seq',           (SELECT MAX(loan_id) FROM loan));
SELECT setval('transaction_txn_id_seq',     (SELECT MAX(txn_id) FROM transaction));
SELECT setval('fund_transfer_transfer_id_seq', (SELECT MAX(transfer_id) FROM fund_transfer));

-- ── Summary ──
SELECT 'branch' AS entity, COUNT(*) AS total FROM branch
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'employee', COUNT(*) FROM employee
UNION ALL SELECT 'account', COUNT(*) FROM account
UNION ALL SELECT 'transaction', COUNT(*) FROM transaction
UNION ALL SELECT 'loan', COUNT(*) FROM loan
UNION ALL SELECT 'fund_transfer', COUNT(*) FROM fund_transfer
ORDER BY 1;
