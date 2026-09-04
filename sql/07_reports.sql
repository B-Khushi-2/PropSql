-- name: occupancy_report
-- EXISTS-based view prevents double-counting units if source lease data is duplicated.
SELECT property_id, property_code, property_name, city, total_units,
       occupied_units, vacant_units, occupancy_percentage
FROM property_occupancy_view
ORDER BY occupancy_percentage ASC, property_name;
-- end

-- name: rent_collection_report
-- This parameterized CTE reports any selected month rather than only the current month.
WITH expected AS (
    SELECT u.property_id, SUM(l.monthly_rent) AS expected_rent
    FROM leases l
    JOIN units u ON u.unit_id = l.unit_id
    WHERE l.lease_status IN ('active', 'expired')
      AND l.start_date < (%(report_month)s::DATE + INTERVAL '1 month')
      AND l.end_date >= %(report_month)s::DATE
    GROUP BY u.property_id
), collected AS (
    SELECT u.property_id, SUM(pmt.amount_paid) AS collected_rent
    FROM payments pmt
    JOIN leases l ON l.lease_id = pmt.lease_id
    JOIN units u ON u.unit_id = l.unit_id
    WHERE pmt.due_date >= %(report_month)s::DATE
      AND pmt.due_date < (%(report_month)s::DATE + INTERVAL '1 month')
    GROUP BY u.property_id
)
SELECT p.property_id, p.property_code, p.property_name,
       COALESCE(e.expected_rent, 0)::NUMERIC(14,2) AS expected_rent,
       COALESCE(c.collected_rent, 0)::NUMERIC(14,2) AS collected_rent,
       GREATEST(COALESCE(e.expected_rent, 0) - COALESCE(c.collected_rent, 0), 0)::NUMERIC(14,2) AS pending_rent,
       COALESCE(ROUND(100.0 * COALESCE(c.collected_rent, 0) / NULLIF(e.expected_rent, 0), 2), 0.00) AS collection_percentage
FROM properties p
LEFT JOIN expected e ON e.property_id = p.property_id
LEFT JOIN collected c ON c.property_id = p.property_id
WHERE p.is_active
ORDER BY collection_percentage ASC, p.property_name;
-- end

-- name: lease_expiry_report
SELECT l.lease_id, t.tenant_id, t.first_name || ' ' || t.last_name AS tenant_name,
       p.property_name, u.unit_number, l.end_date,
       (l.end_date - CURRENT_DATE) AS days_remaining,
       CASE WHEN l.end_date <= CURRENT_DATE + 30 THEN 'within 30 days'
            WHEN l.end_date <= CURRENT_DATE + 60 THEN 'within 60 days'
            ELSE 'within 90 days' END AS expiry_window
FROM leases l
JOIN tenants t ON t.tenant_id = l.tenant_id
JOIN units u ON u.unit_id = l.unit_id
JOIN properties p ON p.property_id = u.property_id
WHERE l.lease_status = 'active'
  AND l.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + %(days)s::INTEGER
ORDER BY l.end_date, p.property_name, u.unit_number;
-- end

-- name: tenant_payment_history
SELECT t.tenant_id, t.first_name || ' ' || t.last_name AS tenant_name,
       pr.property_name, u.unit_number, pmt.due_date, pmt.paid_date,
       pmt.amount_due, pmt.amount_paid, pmt.payment_status, pmt.payment_method
FROM payments pmt
JOIN leases l ON l.lease_id = pmt.lease_id
JOIN tenants t ON t.tenant_id = l.tenant_id
JOIN units u ON u.unit_id = l.unit_id
JOIN properties pr ON pr.property_id = u.property_id
WHERE (%(tenant_id)s::BIGINT IS NULL OR t.tenant_id = %(tenant_id)s::BIGINT)
ORDER BY pmt.due_date DESC, tenant_name
LIMIT 500;
-- end

-- name: delinquent_tenant_report
SELECT t.tenant_id, t.first_name || ' ' || t.last_name AS tenant_name, t.email,
       pr.property_name, u.unit_number,
       COUNT(*) FILTER (WHERE pmt.payment_status = 'late')::INTEGER AS late_payment_count,
       COUNT(*) FILTER (WHERE pmt.amount_paid < pmt.amount_due)::INTEGER AS unpaid_charge_count,
       SUM(pmt.amount_due - pmt.amount_paid)::NUMERIC(14,2) AS outstanding_balance
FROM tenants t
JOIN leases l ON l.tenant_id = t.tenant_id
JOIN units u ON u.unit_id = l.unit_id
JOIN properties pr ON pr.property_id = u.property_id
JOIN payments pmt ON pmt.lease_id = l.lease_id
WHERE pmt.due_date <= CURRENT_DATE
GROUP BY t.tenant_id, t.first_name, t.last_name, t.email, pr.property_name, u.unit_number
HAVING SUM(pmt.amount_due - pmt.amount_paid) > 0 OR COUNT(*) FILTER (WHERE pmt.payment_status = 'late') >= 2
ORDER BY outstanding_balance DESC, late_payment_count DESC;
-- end

-- name: maintenance_report
SELECT property_id, property_code, property_name, total_requests, open_requests,
       closed_requests, high_priority_requests, average_resolution_hours
FROM maintenance_summary_view
ORDER BY open_requests DESC, property_name;
-- end

-- name: property_performance_report
SELECT o.property_id, o.property_code, o.property_name, o.city,
       o.occupancy_percentage,
       r.expected_rent, r.collected_rent, r.pending_rent, r.collection_percentage,
       m.total_requests, m.open_requests, m.high_priority_requests, m.average_resolution_hours
FROM property_occupancy_view o
LEFT JOIN rent_collection_view r USING (property_id)
LEFT JOIN maintenance_summary_view m USING (property_id)
ORDER BY o.occupancy_percentage ASC, r.collection_percentage ASC NULLS FIRST;
-- end
