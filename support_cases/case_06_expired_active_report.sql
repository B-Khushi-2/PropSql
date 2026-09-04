-- Title: Expired Leases in Active Report
-- Severity: High
-- ## Problem
-- Leases with an end date in the past appear on the active-leases screen.
-- ## Investigation SQL
SELECT lease_id, lease_status, start_date, end_date
FROM leases WHERE lease_status = 'active' AND end_date < CURRENT_DATE;
-- ## Expected Result
-- Active reports contain only leases whose current date is within the lease period.
-- ## Actual Result
-- Filtering only lease_status trusts a stale workflow flag.
-- ## Root Cause
-- A scheduled status rollover did not run; the report lacked a defensive date predicate.
-- ## Fix
SELECT * FROM active_leases_view;
-- The view requires status and CURRENT_DATE BETWEEN start_date AND end_date.
-- ## Validation SQL
SELECT lease_id FROM active_leases_view
WHERE end_date < CURRENT_DATE OR start_date > CURRENT_DATE;
-- Expected: zero rows.
