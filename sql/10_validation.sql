-- Every query should return zero rows in a healthy database.

-- 1. Cached occupied status without a date-valid active lease.
SELECT u.unit_id, u.unit_number
FROM units u
WHERE u.unit_status = 'occupied'
  AND NOT EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id);

-- 2. Date-valid active lease on a unit not marked occupied.
SELECT al.lease_id, al.unit_id
FROM active_leases_view al
JOIN units u ON u.unit_id = al.unit_id
WHERE u.unit_status <> 'occupied';

-- 3. Orphan tenant references (normally prevented by the foreign key).
SELECT l.lease_id FROM leases l
LEFT JOIN tenants t ON t.tenant_id = l.tenant_id
WHERE t.tenant_id IS NULL;

-- 4. Orphan unit references (normally prevented by the foreign key).
SELECT l.lease_id FROM leases l
LEFT JOIN units u ON u.unit_id = l.unit_id
WHERE u.unit_id IS NULL;

-- 5. Payments without leases (normally prevented by the foreign key).
SELECT p.payment_id FROM payments p
LEFT JOIN leases l ON l.lease_id = p.lease_id
WHERE l.lease_id IS NULL;

-- 6. Negative or overpaid payments (normally prevented by CHECK constraints).
SELECT payment_id, amount_due, amount_paid FROM payments
WHERE amount_due <= 0 OR amount_paid < 0 OR amount_paid > amount_due;

-- 7. Business-key duplicates even if external references differ.
SELECT lease_id, due_date, amount_due, COUNT(*)
FROM payments
GROUP BY lease_id, due_date, amount_due
HAVING COUNT(*) > 1;

-- 8. Invalid lease periods.
SELECT lease_id, start_date, end_date FROM leases WHERE end_date <= start_date;

-- 9. Maintenance requests without valid units.
SELECT mr.request_id FROM maintenance_requests mr
LEFT JOIN units u ON u.unit_id = mr.unit_id
WHERE u.unit_id IS NULL;

-- 10. Work orders without maintenance requests.
SELECT wo.work_order_id FROM work_orders wo
LEFT JOIN maintenance_requests mr ON mr.request_id = wo.request_id
WHERE mr.request_id IS NULL;

-- 11. Multiple date-valid leases for one unit would inflate naive occupancy joins.
SELECT unit_id, COUNT(*) FROM active_leases_view GROUP BY unit_id HAVING COUNT(*) > 1;

-- 12. Closed requests must have a close time, while open requests should not.
SELECT request_id, request_status, closed_at FROM maintenance_requests
WHERE (request_status = 'closed' AND closed_at IS NULL)
   OR (request_status NOT IN ('closed', 'cancelled') AND closed_at IS NOT NULL);
