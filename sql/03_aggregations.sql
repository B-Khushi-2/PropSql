-- Conditional aggregation calculates several KPIs in one grouped pass.
SELECT p.property_name,
       COUNT(*) AS payment_count,
       SUM(pmt.amount_due) AS total_due,
       SUM(pmt.amount_paid) AS total_paid,
       SUM(pmt.amount_due - pmt.amount_paid) AS outstanding,
       COUNT(*) FILTER (WHERE pmt.payment_status = 'late') AS late_payment_count
FROM payments pmt
JOIN leases l ON l.lease_id = pmt.lease_id
JOIN units u ON u.unit_id = l.unit_id
JOIN properties p ON p.property_id = u.property_id
GROUP BY p.property_id, p.property_name
HAVING SUM(pmt.amount_due - pmt.amount_paid) > 0
ORDER BY outstanding DESC;

-- HAVING filters groups after aggregation, unlike WHERE which filters input rows.
SELECT v.specialty, COUNT(*) AS completed_jobs,
       ROUND(AVG(wo.labor_cost + wo.material_cost), 2) AS average_job_cost
FROM work_orders wo
JOIN vendors v ON v.vendor_id = wo.vendor_id
WHERE wo.work_order_status = 'completed'
GROUP BY v.specialty
HAVING COUNT(*) >= 5
ORDER BY average_job_cost DESC;
