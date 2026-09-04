-- Deterministic, set-based seed data. Counts are large enough for meaningful plans and reports.
BEGIN;

TRUNCATE work_orders, maintenance_requests, payments, leases, tenants, vendors, units, properties
RESTART IDENTITY CASCADE;

INSERT INTO properties (
    property_code, property_name, address_line1, city, state_code,
    postal_code, manager_name, acquisition_date
)
SELECT 'PROP-' || lpad(n::TEXT, 3, '0'),
       (ARRAY['Maple','Riverside','Cedar','Oak','Harbor','Summit','Park','Lake'])[1 + ((n - 1) % 8)]
           || ' ' || (ARRAY['Residences','Court','Place','Commons'])[1 + ((n - 1) % 4)]
           || ' ' || n,
       (100 + n * 17) || ' ' || (ARRAY['Main Street','Lake Avenue','Oak Drive','Market Road'])[1 + ((n - 1) % 4)],
       (ARRAY['Austin','Dallas','Houston','San Antonio','Fort Worth'])[1 + ((n - 1) % 5)],
       'TX',
       (75000 + n * 13)::TEXT,
       (ARRAY['Maya Patel','Daniel Kim','Olivia Reed','Marcus Lee','Sofia Torres'])[1 + ((n - 1) % 5)],
       CURRENT_DATE - (900 + n * 31)
FROM generate_series(1, 25) AS n;

-- Twelve units per property: 300 units total.
INSERT INTO units (property_id, unit_number, bedrooms, bathrooms, square_feet, market_rent)
SELECT p.property_id,
       (floor((n - 1) / 4) + 1)::TEXT || chr((65 + ((n - 1) % 4))::INTEGER),
       ((n + p.property_id) % 4)::SMALLINT,
       (1 + ((n + p.property_id) % 4) * 0.5)::NUMERIC(3,1),
       500 + (((n * 73 + p.property_id * 29) % 950))::INTEGER,
       (900 + p.property_id * 24 + (n % 4) * 235 + (n / 5) * 40)::NUMERIC(12,2)
FROM properties p
CROSS JOIN generate_series(1, 12) AS n;

INSERT INTO tenants (first_name, last_name, email, phone, emergency_contact)
SELECT (ARRAY['Aarav','Mia','Noah','Emma','Ethan','Ava','Liam','Zoe','Lucas','Nora'])[1 + ((n - 1) % 10)],
       (ARRAY['Shah','Johnson','Garcia','Brown','Davis','Wilson','Martinez','Clark','Lewis','Walker'])[1 + (((n * 3) - 1) % 10)],
       'tenant' || lpad(n::TEXT, 3, '0') || '@example.com',
       '+1-512-555-' || lpad((1000 + n)::TEXT, 4, '0'),
       'Emergency contact ' || n || ' (+1-737-555-' || lpad((2000 + n)::TEXT, 4, '0') || ')'
FROM generate_series(1, 260) AS n;

INSERT INTO vendors (vendor_name, specialty, email, phone, hourly_rate)
SELECT 'Vendor Services ' || lpad(n::TEXT, 2, '0'),
       (ARRAY['Plumbing','Electrical','HVAC','Appliance','Carpentry','Cleaning','Landscaping','General'])[1 + ((n - 1) % 8)],
       'dispatch' || lpad(n::TEXT, 2, '0') || '@vendor.example',
       '+1-469-555-' || lpad((3000 + n)::TEXT, 4, '0'),
       (55 + (n % 8) * 8.5)::NUMERIC(10,2)
FROM generate_series(1, 40) AS n;

-- Active leases: realistic variable occupancy across all properties (80% - 95%).
INSERT INTO leases (unit_id, tenant_id, start_date, end_date, monthly_rent, security_deposit, lease_status)
SELECT u.unit_id,
       1 + ((u.unit_id * 7 - 1) % 260),
       CURRENT_DATE - (30 + ((u.unit_id * 11) % 180))::INTEGER,
       CURRENT_DATE + (45 + ((u.unit_id * 13) % 300))::INTEGER,
       (u.market_rent - 25 + (u.unit_id % 5) * 10)::NUMERIC(12,2),
       u.market_rent,
       'active'
FROM units u
WHERE ((u.unit_id + u.property_id * 3) % 7) <> 0;

-- 200 historical leases add realistic turnover without overlapping the current lease period.
INSERT INTO leases (unit_id, tenant_id, start_date, end_date, monthly_rent, security_deposit, lease_status)
SELECT u.unit_id,
       1 + ((u.unit_id * 11 + 39) % 260),
       CURRENT_DATE - (1000 + (u.unit_id % 180))::INTEGER,
       CURRENT_DATE - (500 + (u.unit_id % 150))::INTEGER,
       (u.market_rent * 0.88)::NUMERIC(12,2),
       (u.market_rent * 0.88)::NUMERIC(12,2),
       'expired'
FROM units u
WHERE u.unit_id <= 200;

-- Unit status is a display/cache field; the lease view is the source of truth for reporting.
UPDATE units u
SET unit_status = CASE
    WHEN EXISTS (SELECT 1 FROM leases l WHERE l.unit_id = u.unit_id AND l.lease_status = 'active'
                 AND CURRENT_DATE BETWEEN l.start_date AND l.end_date) THEN 'occupied'
    ELSE 'vacant'
END;

-- Twelve recent monthly charges for active leases (roughly 2,880 payment rows).
WITH charge_months AS (
    SELECT l.lease_id, l.monthly_rent,
           gs::DATE AS due_date,
           row_number() OVER (ORDER BY l.lease_id, gs) AS sequence_no
    FROM leases l
    CROSS JOIN LATERAL generate_series(
        date_trunc('month', CURRENT_DATE) - INTERVAL '11 months',
        date_trunc('month', CURRENT_DATE),
        INTERVAL '1 month'
    ) gs
    WHERE l.lease_status = 'active'
      AND gs::DATE >= date_trunc('month', l.start_date)::DATE
)
INSERT INTO payments (
    lease_id, payment_reference, due_date, paid_date, amount_due,
    amount_paid, payment_status, payment_method
)
SELECT lease_id,
       'PAY-' || lpad(lease_id::TEXT, 5, '0') || '-' || to_char(due_date, 'YYYYMM'),
       due_date,
       CASE
           WHEN sequence_no % 13 = 0 THEN NULL
           WHEN sequence_no % 9 = 0 THEN due_date + 8
           WHEN sequence_no % 17 = 0 THEN due_date + 14
           ELSE due_date + 2 + (sequence_no % 4)::INTEGER
       END,
       monthly_rent,
       CASE
           WHEN sequence_no % 13 = 0 THEN 0
           WHEN sequence_no % 17 = 0 THEN round(monthly_rent * 0.55, 2)
           ELSE monthly_rent
       END,
       CASE
           WHEN sequence_no % 13 = 0 THEN 'pending'
           WHEN sequence_no % 17 = 0 THEN 'partial'
           WHEN sequence_no % 9 = 0 THEN 'late'
           ELSE 'paid'
       END,
       CASE WHEN sequence_no % 13 = 0 THEN NULL
            ELSE (ARRAY['ach','card','check','bank_transfer'])[1 + (sequence_no % 4)] END
FROM charge_months;

-- Six charges per historical lease provide additional payment history (1,200 rows).
WITH historical_months AS (
    SELECT l.lease_id, l.monthly_rent,
           (date_trunc('month', l.end_date) - make_interval(months => n))::DATE AS due_date,
           row_number() OVER (ORDER BY l.lease_id, n) AS sequence_no
    FROM leases l
    CROSS JOIN generate_series(1, 6) AS n
    WHERE l.lease_status = 'expired'
)
INSERT INTO payments (
    lease_id, payment_reference, due_date, paid_date, amount_due,
    amount_paid, payment_status, payment_method
)
SELECT lease_id,
       'HIST-' || lpad(lease_id::TEXT, 5, '0') || '-' || to_char(due_date, 'YYYYMM'),
       due_date,
       CASE WHEN sequence_no % 11 = 0 THEN due_date + 12 ELSE due_date + 3 END,
       monthly_rent,
       monthly_rent,
       CASE WHEN sequence_no % 11 = 0 THEN 'late' ELSE 'paid' END,
       (ARRAY['ach','card','check','bank_transfer'])[1 + (sequence_no % 4)]
FROM historical_months;

INSERT INTO maintenance_requests (
    unit_id, tenant_id, title, description, priority, request_status, created_at, closed_at
)
SELECT 1 + ((n * 17 - 1) % 300),
       (SELECT l.tenant_id FROM leases l
        WHERE l.unit_id = 1 + ((n * 17 - 1) % 300) AND l.lease_status = 'active' LIMIT 1),
       (ARRAY['Leaking faucet','Air conditioning issue','Outlet not working','Appliance repair',
              'Door lock problem','Ceiling stain','Low water pressure','Smoke alarm service'])[1 + ((n - 1) % 8)],
       'Resident-reported maintenance request ' || n || ' requiring inspection and documented follow-up.',
       CASE WHEN n % 19 = 0 THEN 'emergency' WHEN n % 7 = 0 THEN 'high'
            WHEN n % 3 = 0 THEN 'medium' ELSE 'low' END,
       CASE WHEN n % 5 = 0 THEN 'open' WHEN n % 5 = 1 THEN 'assigned'
            WHEN n % 5 = 2 THEN 'in_progress' ELSE 'closed' END,
       CURRENT_TIMESTAMP - make_interval(days => (n % 240), hours => (n % 20)),
       CASE WHEN n % 5 IN (3,4)
            THEN LEAST(CURRENT_TIMESTAMP,
                 CURRENT_TIMESTAMP - make_interval(days => (n % 240), hours => (n % 20))
                 + make_interval(hours => 8 + (n % 140)))
            ELSE NULL END
FROM generate_series(1, 420) AS n;

INSERT INTO work_orders (
    request_id, vendor_id, assigned_at, scheduled_date, completed_at,
    labor_cost, material_cost, work_order_status, notes
)
SELECT mr.request_id,
       1 + ((mr.request_id * 7 - 1) % 40),
       mr.created_at + INTERVAL '2 hours',
       (mr.created_at + INTERVAL '1 day')::DATE,
       CASE WHEN mr.request_status = 'closed' THEN mr.closed_at ELSE NULL END,
       CASE WHEN mr.request_status = 'closed' THEN (65 + (mr.request_id % 12) * 22)::NUMERIC(12,2) ELSE 0 END,
       CASE WHEN mr.request_status = 'closed' THEN (15 + (mr.request_id % 9) * 18)::NUMERIC(12,2) ELSE 0 END,
       CASE WHEN mr.request_status = 'closed' THEN 'completed'
            WHEN mr.request_status = 'in_progress' THEN 'in_progress'
            WHEN mr.request_status = 'assigned' THEN 'scheduled' ELSE 'assigned' END,
       'Work order created from request ' || mr.request_id || '; costs require invoice review.'
FROM maintenance_requests mr
WHERE mr.request_id <= 380;

COMMIT;

-- Expected volume summary: 25 properties, 300 units, 260 tenants, 440 leases,
-- 3,000+ payments, 420 maintenance requests, 40 vendors, and 380 work orders.
SELECT 'properties' AS entity, COUNT(*) AS row_count FROM properties
UNION ALL SELECT 'units', COUNT(*) FROM units
UNION ALL SELECT 'tenants', COUNT(*) FROM tenants
UNION ALL SELECT 'leases', COUNT(*) FROM leases
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'maintenance_requests', COUNT(*) FROM maintenance_requests
UNION ALL SELECT 'vendors', COUNT(*) FROM vendors
UNION ALL SELECT 'work_orders', COUNT(*) FROM work_orders
ORDER BY entity;
