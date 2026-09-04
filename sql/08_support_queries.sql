-- Reusable investigation queries for day-to-day SQL application support.

-- Units whose cached status disagrees with the active-lease source of truth.
SELECT p.property_name, u.unit_id, u.unit_number, u.unit_status,
       EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id) AS has_active_lease
FROM units u
JOIN properties p ON p.property_id = u.property_id
WHERE (u.unit_status = 'occupied') <>
      EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id);

-- Business-key duplicate detector; the unique payment reference catches exact imports,
-- while this query catches differently labelled records for the same lease/month/amount.
SELECT lease_id, due_date, amount_due, COUNT(*) AS duplicate_count,
       array_agg(payment_reference ORDER BY payment_reference) AS references
FROM payments
GROUP BY lease_id, due_date, amount_due
HAVING COUNT(*) > 1;

-- Work orders whose completion status disagrees with their parent request.
SELECT mr.request_id, mr.request_status, wo.work_order_id, wo.work_order_status
FROM maintenance_requests mr
JOIN work_orders wo ON wo.request_id = mr.request_id
WHERE (mr.request_status = 'closed' AND wo.work_order_status <> 'completed')
   OR (mr.request_status <> 'closed' AND wo.work_order_status = 'completed');

-- High maintenance spend by property for invoice review.
SELECT p.property_name, COUNT(wo.work_order_id) AS completed_orders,
       SUM(wo.labor_cost + wo.material_cost) AS total_cost,
       ROUND(AVG(wo.labor_cost + wo.material_cost), 2) AS average_cost
FROM work_orders wo
JOIN maintenance_requests mr ON mr.request_id = wo.request_id
JOIN units u ON u.unit_id = mr.unit_id
JOIN properties p ON p.property_id = u.property_id
WHERE wo.work_order_status = 'completed'
GROUP BY p.property_id, p.property_name
ORDER BY total_cost DESC;
