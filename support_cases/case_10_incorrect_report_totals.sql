-- Title: Incorrect Property Performance Totals
-- Severity: High
-- ## Problem
-- Combined performance totals change when maintenance rows are added.
-- ## Investigation SQL
-- Faulty grain: leases, payments, and requests are all one-to-many joins.
SELECT p.property_id, SUM(l.monthly_rent) AS expected_rent, SUM(pmt.amount_paid) AS collected
FROM properties p JOIN units u ON u.property_id = p.property_id
JOIN leases l ON l.unit_id = u.unit_id
LEFT JOIN payments pmt ON pmt.lease_id = l.lease_id
LEFT JOIN maintenance_requests mr ON mr.unit_id = u.unit_id
GROUP BY p.property_id;
-- ## Expected Result
-- Adding maintenance data must not change rent totals.
-- ## Actual Result
-- Payments repeat for each maintenance request on the same unit.
-- ## Root Cause
-- Multiple fact tables were joined before each was aggregated to property grain.
-- ## Fix
SELECT o.property_name, o.occupancy_percentage, r.expected_rent, r.collected_rent,
       m.total_requests, m.open_requests
FROM property_occupancy_view o
LEFT JOIN rent_collection_view r USING (property_id)
LEFT JOIN maintenance_summary_view m USING (property_id);
-- ## Validation SQL
-- Compare rent totals before and after adding the maintenance summary; they must be unchanged.
SELECT SUM(expected_rent) AS expected, SUM(collected_rent) AS collected FROM rent_collection_view;
