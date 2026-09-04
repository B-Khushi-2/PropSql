-- Title: Incorrect Occupancy Report
-- Severity: High
-- ## Problem
-- A property report shows occupancy above 100 percent.
-- ## Investigation SQL
-- Faulty report counts active leases, not distinct occupied units.
SELECT p.property_name, COUNT(l.lease_id) AS occupied_count, COUNT(DISTINCT u.unit_id) AS total_units
FROM properties p JOIN units u ON u.property_id = p.property_id
LEFT JOIN leases l ON l.unit_id = u.unit_id AND l.lease_status = 'active'
GROUP BY p.property_id, p.property_name;

SELECT unit_id, COUNT(*) FROM leases
WHERE lease_status = 'active' AND CURRENT_DATE BETWEEN start_date AND end_date
GROUP BY unit_id HAVING COUNT(*) > 1;
-- ## Expected Result
-- occupied_units must be no greater than total_units.
-- ## Actual Result
-- A faulty import can create multiple active lease rows per unit; COUNT(lease_id) then exceeds the unit count.
-- ## Root Cause
-- A one-to-many join was aggregated without de-duplicating the unit business entity.
-- ## Fix
-- Count units with EXISTS and enforce one active lease per unit with uq_one_active_lease_per_unit.
SELECT property_name, total_units, occupied_units, occupancy_percentage FROM property_occupancy_view;
-- ## Validation SQL
SELECT * FROM property_occupancy_view WHERE occupancy_percentage > 100;
-- Expected: zero rows.
