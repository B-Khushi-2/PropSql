-- Title: Incorrect Monthly Rent Total
-- Severity: High
-- ## Problem
-- Expected rent is higher than the signed monthly rent total.
-- ## Investigation SQL
-- This intentionally faulty query multiplies each lease by every payment row.
SELECT u.property_id, SUM(l.monthly_rent) AS inflated_expected_rent
FROM leases l JOIN units u ON u.unit_id = l.unit_id
JOIN payments p ON p.lease_id = l.lease_id
WHERE l.lease_status = 'active' GROUP BY u.property_id;
-- ## Expected Result
-- Each active lease contributes monthly_rent once for the selected month.
-- ## Actual Result
-- A lease contributes once per matching payment, inflating the total.
-- ## Root Cause
-- Join fan-out occurred before SUM(monthly_rent).
-- ## Fix
-- Aggregate expected rent and collected payments separately, then join property-level results.
SELECT * FROM rent_collection_view ORDER BY property_id;
-- ## Validation SQL
SELECT u.property_id, SUM(l.monthly_rent) AS expected_once
FROM active_leases_view l JOIN units u ON u.unit_id = l.unit_id GROUP BY u.property_id;
-- Expected: totals match the expected_rent column for the current month.
