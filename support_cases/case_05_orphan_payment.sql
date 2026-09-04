-- Title: Payment Without a Valid Lease
-- Severity: Critical
-- ## Problem
-- A legacy import references a lease that is not present.
-- ## Investigation SQL
SELECT p.payment_id, p.payment_reference, p.lease_id
FROM payments p LEFT JOIN leases l ON l.lease_id = p.lease_id
WHERE l.lease_id IS NULL;
-- ## Expected Result
-- Every payment resolves to one lease.
-- ## Actual Result
-- Legacy systems without foreign keys can retain orphan payment rows.
-- ## Root Cause
-- Import order and missing referential constraints allowed child rows first.
-- ## Fix
-- Load/validate leases before payments and retain payments_lease_id_fkey.
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid = 'payments'::regclass AND contype = 'f';
-- ## Validation SQL
SELECT COUNT(*) AS orphan_payments FROM payments p
LEFT JOIN leases l ON l.lease_id = p.lease_id WHERE l.lease_id IS NULL;
-- Expected: 0.
