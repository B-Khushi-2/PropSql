-- The reported plans and timings must come from the local PostgreSQL instance.
-- Run this file after database/setup.sql. Use plan shape rather than invented timings.

-- EXAMPLE 1: Lease expiry lookup
-- Before: applying a function to end_date makes the predicate non-sargable.
EXPLAIN (ANALYZE, BUFFERS)
SELECT lease_id, unit_id, end_date
FROM leases
WHERE to_char(end_date, 'YYYY-MM-DD') BETWEEN to_char(CURRENT_DATE, 'YYYY-MM-DD')
  AND to_char(CURRENT_DATE + 90, 'YYYY-MM-DD');

-- After: direct range comparison can use idx_leases_status_end.
EXPLAIN (ANALYZE, BUFFERS)
SELECT lease_id, unit_id, end_date
FROM leases
WHERE lease_status = 'active'
  AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 90;

-- EXAMPLE 2: Tenant lookup
-- Before: leading wildcard and concatenation force broad inspection.
EXPLAIN (ANALYZE, BUFFERS)
SELECT tenant_id, first_name, last_name, email
FROM tenants
WHERE lower(first_name || ' ' || last_name) LIKE '%walker%';

-- After: equality on the indexed lower(last_name), lower(first_name) expression.
EXPLAIN (ANALYZE, BUFFERS)
SELECT tenant_id, first_name, last_name, email
FROM tenants
WHERE lower(last_name) = 'walker'
ORDER BY lower(first_name);

-- EXAMPLE 3: Payment reporting
-- Before: correlated aggregation repeats payment access for every active lease.
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.lease_id,
       (SELECT SUM(p.amount_paid) FROM payments p WHERE p.lease_id = l.lease_id) AS paid_total
FROM leases l
WHERE l.lease_status = 'active';

-- After: aggregate payments once, then join the small result set.
EXPLAIN (ANALYZE, BUFFERS)
WITH paid AS (
    SELECT lease_id, SUM(amount_paid) AS paid_total
    FROM payments
    GROUP BY lease_id
)
SELECT l.lease_id, COALESCE(paid.paid_total, 0) AS paid_total
FROM leases l
LEFT JOIN paid ON paid.lease_id = l.lease_id
WHERE l.lease_status = 'active';

-- name: optimization_expiry_before
SELECT lease_id, unit_id, end_date FROM leases
WHERE to_char(end_date, 'YYYY-MM-DD') BETWEEN to_char(CURRENT_DATE, 'YYYY-MM-DD')
AND to_char(CURRENT_DATE + 90, 'YYYY-MM-DD');
-- end

-- name: optimization_expiry_after
SELECT lease_id, unit_id, end_date FROM leases
WHERE lease_status = 'active' AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 90;
-- end

-- name: optimization_tenant_before
SELECT tenant_id, first_name, last_name, email FROM tenants
WHERE lower(first_name || ' ' || last_name) LIKE '%walker%';
-- end

-- name: optimization_tenant_after
SELECT tenant_id, first_name, last_name, email FROM tenants
WHERE lower(last_name) = 'walker' ORDER BY lower(first_name);
-- end

-- name: optimization_payment_before
SELECT l.lease_id,
       (SELECT SUM(p.amount_paid) FROM payments p WHERE p.lease_id = l.lease_id) AS paid_total
FROM leases l WHERE l.lease_status = 'active';
-- end

-- name: optimization_payment_after
WITH paid AS (SELECT lease_id, SUM(amount_paid) AS paid_total FROM payments GROUP BY lease_id)
SELECT l.lease_id, COALESCE(paid.paid_total, 0) AS paid_total
FROM leases l LEFT JOIN paid ON paid.lease_id = l.lease_id
WHERE l.lease_status = 'active';
-- end
