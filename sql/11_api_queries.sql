-- Named queries in this file are loaded by Flask. Keeping SQL here makes report logic reviewable.

-- name: dashboard_summary
SELECT (SELECT COUNT(*) FROM properties WHERE is_active)::INTEGER AS total_properties,
       (SELECT COUNT(*) FROM units)::INTEGER AS total_units,
       (SELECT ROUND(AVG(occupancy_percentage), 1) FROM property_occupancy_view) AS occupancy_rate,
       (SELECT ROUND(100.0 * SUM(collected_rent) / NULLIF(SUM(expected_rent), 0), 1) FROM rent_collection_view) AS collection_rate,
       (SELECT COUNT(*) FROM payments WHERE amount_paid < amount_due AND due_date <= CURRENT_DATE)::INTEGER AS pending_payments,
       (SELECT COUNT(*) FROM maintenance_requests WHERE request_status NOT IN ('closed','cancelled'))::INTEGER AS open_maintenance;
-- end

-- name: properties_list
SELECT p.property_id, p.property_code, p.property_name, p.address_line1, p.city, p.state_code,
       p.postal_code, p.manager_name, p.is_active, o.total_units, o.occupancy_percentage
FROM properties p LEFT JOIN property_occupancy_view o USING (property_id)
ORDER BY p.property_name LIMIT %(limit)s OFFSET %(offset)s;
-- end

-- name: units_list
SELECT u.unit_id, p.property_name, u.unit_number, u.bedrooms, u.bathrooms,
       u.square_feet, u.market_rent, u.unit_status
FROM units u JOIN properties p ON p.property_id = u.property_id
ORDER BY p.property_name, u.unit_number LIMIT %(limit)s OFFSET %(offset)s;
-- end

-- name: tenants_list
SELECT t.tenant_id, t.first_name, t.last_name, t.email, t.phone,
       COUNT(l.lease_id)::INTEGER AS lease_count
FROM tenants t LEFT JOIN leases l ON l.tenant_id = t.tenant_id
GROUP BY t.tenant_id ORDER BY t.last_name, t.first_name LIMIT %(limit)s OFFSET %(offset)s;
-- end

-- name: leases_list
SELECT l.lease_id, t.first_name || ' ' || t.last_name AS tenant_name,
       p.property_name, u.unit_number, l.start_date, l.end_date, l.monthly_rent, l.lease_status
FROM leases l JOIN tenants t ON t.tenant_id = l.tenant_id
JOIN units u ON u.unit_id = l.unit_id JOIN properties p ON p.property_id = u.property_id
ORDER BY l.end_date DESC LIMIT %(limit)s OFFSET %(offset)s;
-- end

-- name: payments_list
SELECT pmt.payment_id, pmt.payment_reference, t.first_name || ' ' || t.last_name AS tenant_name,
       pr.property_name, pmt.due_date, pmt.paid_date, pmt.amount_due, pmt.amount_paid,
       pmt.payment_status, pmt.payment_method
FROM payments pmt JOIN leases l ON l.lease_id = pmt.lease_id
JOIN tenants t ON t.tenant_id = l.tenant_id JOIN units u ON u.unit_id = l.unit_id
JOIN properties pr ON pr.property_id = u.property_id
ORDER BY pmt.due_date DESC, pmt.payment_id DESC LIMIT %(limit)s OFFSET %(offset)s;
-- end

-- name: maintenance_list
SELECT mr.request_id, pr.property_name, u.unit_number, mr.title, mr.priority,
       mr.request_status, mr.created_at, mr.closed_at
FROM maintenance_requests mr JOIN units u ON u.unit_id = mr.unit_id
JOIN properties pr ON pr.property_id = u.property_id
ORDER BY mr.created_at DESC LIMIT %(limit)s OFFSET %(offset)s;
-- end

-- name: recent_maintenance
SELECT mr.request_id, pr.property_name, u.unit_number, mr.title, mr.priority,
       mr.request_status, mr.created_at
FROM maintenance_requests mr JOIN units u ON u.unit_id = mr.unit_id
JOIN properties pr ON pr.property_id = u.property_id
ORDER BY mr.created_at DESC LIMIT 8;
-- end

-- name: upcoming_expirations
SELECT l.lease_id, t.first_name || ' ' || t.last_name AS tenant_name,
       pr.property_name, u.unit_number, l.end_date, (l.end_date - CURRENT_DATE) AS days_remaining
FROM active_leases_view l JOIN tenants t ON t.tenant_id = l.tenant_id
JOIN units u ON u.unit_id = l.unit_id JOIN properties pr ON pr.property_id = u.property_id
WHERE l.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60
ORDER BY l.end_date LIMIT 8;
-- end

-- name: assistant_low_occupancy
SELECT property_name, city, occupied_units, total_units, occupancy_percentage
FROM property_occupancy_view WHERE occupancy_percentage < %(threshold)s
ORDER BY occupancy_percentage, property_name;
-- end

-- name: assistant_expiring_leases
SELECT tenant_name, property_name, unit_number, end_date, days_remaining
FROM (
  SELECT t.first_name || ' ' || t.last_name AS tenant_name, pr.property_name, u.unit_number,
         l.end_date, l.end_date - CURRENT_DATE AS days_remaining
  FROM active_leases_view l JOIN tenants t ON t.tenant_id = l.tenant_id
  JOIN units u ON u.unit_id = l.unit_id JOIN properties pr ON pr.property_id = u.property_id
) q WHERE days_remaining BETWEEN 0 AND %(days)s ORDER BY days_remaining;
-- end

-- name: assistant_pending_payments
SELECT t.first_name || ' ' || t.last_name AS tenant_name, pr.property_name,
       SUM(pmt.amount_due - pmt.amount_paid)::NUMERIC(14,2) AS outstanding_balance
FROM payments pmt JOIN leases l ON l.lease_id = pmt.lease_id
JOIN tenants t ON t.tenant_id = l.tenant_id JOIN units u ON u.unit_id = l.unit_id
JOIN properties pr ON pr.property_id = u.property_id
WHERE pmt.amount_paid < pmt.amount_due AND pmt.due_date <= CURRENT_DATE
GROUP BY t.tenant_id, t.first_name, t.last_name, pr.property_name
ORDER BY outstanding_balance DESC LIMIT 100;
-- end

-- name: assistant_top_collection
SELECT property_name, expected_rent, collected_rent, collection_percentage
FROM rent_collection_view ORDER BY collection_percentage DESC NULLS LAST LIMIT 5;
-- end

-- name: assistant_duplicate_payments
SELECT lease_id, due_date, amount_due, COUNT(*)::INTEGER AS duplicate_count,
       array_agg(payment_reference ORDER BY payment_reference) AS payment_references
FROM payments GROUP BY lease_id, due_date, amount_due HAVING COUNT(*) > 1;
-- end
