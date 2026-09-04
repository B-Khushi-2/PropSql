-- Title: Duplicate Payment Records
-- Severity: Critical
-- ## Problem
-- A payment import appears to have charged the same lease twice for one month.
-- ## Investigation SQL
SELECT lease_id, due_date, amount_due, COUNT(*) AS duplicate_count,
       array_agg(payment_reference ORDER BY payment_reference) AS references
FROM payments GROUP BY lease_id, due_date, amount_due HAVING COUNT(*) > 1;
-- ## Expected Result
-- One scheduled rent charge per lease, due date, and amount.
-- ## Actual Result
-- Retried imports can use a new external reference and bypass a reference-only duplicate check.
-- ## Root Cause
-- Idempotency was based only on payment_reference, not the business key.
-- ## Fix
-- Stage imports, reject repeated business keys, and keep payment_reference UNIQUE.
-- A stricter deployment may add UNIQUE (lease_id, due_date) when split charges are not allowed.
-- ## Validation SQL
SELECT lease_id, due_date, COUNT(*) FROM payments
GROUP BY lease_id, due_date HAVING COUNT(*) > 1;
-- Expected: zero rows under the single-charge policy.
