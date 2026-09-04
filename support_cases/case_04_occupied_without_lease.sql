-- Title: Occupied Unit Without Active Lease
-- Severity: High
-- ## Problem
-- Operations shows a unit as occupied, but no current tenant appears.
-- ## Investigation SQL
SELECT p.property_name, u.unit_id, u.unit_number, u.unit_status
FROM units u JOIN properties p ON p.property_id = u.property_id
WHERE u.unit_status = 'occupied'
AND NOT EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id);
-- ## Expected Result
-- Every occupied unit has exactly one date-valid active lease.
-- ## Actual Result
-- The cached unit_status can remain occupied after a lease terminates.
-- ## Root Cause
-- Two representations of occupancy were updated in separate application operations.
-- ## Fix
UPDATE units u SET unit_status = 'vacant'
WHERE u.unit_status = 'occupied'
AND NOT EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id);
-- Reports use property_occupancy_view, where the lease is the source of truth.
-- ## Validation SQL
SELECT u.unit_id FROM units u WHERE u.unit_status = 'occupied'
AND NOT EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id);
-- Expected: zero rows.
