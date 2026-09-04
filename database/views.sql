-- Centralizes the date/status rule so every report agrees on what "active" means.
CREATE OR REPLACE VIEW active_leases_view AS
SELECT l.*, u.property_id, u.unit_number,
       t.first_name, t.last_name, t.email
FROM leases l
JOIN units u ON u.unit_id = l.unit_id
JOIN tenants t ON t.tenant_id = l.tenant_id
WHERE l.lease_status = 'active'
  AND CURRENT_DATE BETWEEN l.start_date AND l.end_date;

-- Uses EXISTS so a unit is counted once even if bad source data contains overlapping leases.
CREATE OR REPLACE VIEW property_occupancy_view AS
SELECT p.property_id, p.property_code, p.property_name, p.city,
       COUNT(u.unit_id)::INTEGER AS total_units,
       COUNT(u.unit_id) FILTER (WHERE EXISTS (
           SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id
       ))::INTEGER AS occupied_units,
       COUNT(u.unit_id) FILTER (WHERE NOT EXISTS (
           SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id
       ))::INTEGER AS vacant_units,
       ROUND(100.0 * COUNT(u.unit_id) FILTER (WHERE EXISTS (
           SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id
       )) / NULLIF(COUNT(u.unit_id), 0), 2) AS occupancy_percentage
FROM properties p
LEFT JOIN units u ON u.property_id = p.property_id
WHERE p.is_active
GROUP BY p.property_id, p.property_code, p.property_name, p.city;

-- One row per property and due month prevents lease/payment joins from multiplying rent.
CREATE OR REPLACE VIEW rent_collection_view AS
WITH expected AS (
    SELECT u.property_id, date_trunc('month', CURRENT_DATE)::DATE AS report_month,
           SUM(l.monthly_rent) AS expected_rent
    FROM active_leases_view l
    JOIN units u ON u.unit_id = l.unit_id
    GROUP BY u.property_id
), collected AS (
    SELECT u.property_id, date_trunc('month', pmt.due_date)::DATE AS report_month,
           SUM(pmt.amount_paid) AS collected_rent
    FROM payments pmt
    JOIN leases l ON l.lease_id = pmt.lease_id
    JOIN units u ON u.unit_id = l.unit_id
    WHERE pmt.due_date >= date_trunc('month', CURRENT_DATE)
      AND pmt.due_date < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
    GROUP BY u.property_id, date_trunc('month', pmt.due_date)::DATE
)
SELECT p.property_id, p.property_code, p.property_name, e.report_month,
       COALESCE(e.expected_rent, 0)::NUMERIC(14,2) AS expected_rent,
       COALESCE(c.collected_rent, 0)::NUMERIC(14,2) AS collected_rent,
       GREATEST(COALESCE(e.expected_rent, 0) - COALESCE(c.collected_rent, 0), 0)::NUMERIC(14,2) AS pending_rent,
       COALESCE(ROUND(100.0 * COALESCE(c.collected_rent, 0) / NULLIF(e.expected_rent, 0), 2), 0.00) AS collection_percentage
FROM properties p
LEFT JOIN expected e ON e.property_id = p.property_id
LEFT JOIN collected c ON c.property_id = p.property_id AND c.report_month = e.report_month
WHERE p.is_active;

-- Pre-aggregates maintenance metrics for fast dashboard and property reporting.
CREATE OR REPLACE VIEW maintenance_summary_view AS
SELECT p.property_id, p.property_code, p.property_name,
       COUNT(mr.request_id)::INTEGER AS total_requests,
       COUNT(mr.request_id) FILTER (WHERE mr.request_status NOT IN ('closed', 'cancelled'))::INTEGER AS open_requests,
       COUNT(mr.request_id) FILTER (WHERE mr.request_status = 'closed')::INTEGER AS closed_requests,
       COUNT(mr.request_id) FILTER (WHERE mr.priority IN ('high', 'emergency'))::INTEGER AS high_priority_requests,
       ROUND(AVG(EXTRACT(EPOCH FROM (mr.closed_at - mr.created_at)) / 3600.0)
             FILTER (WHERE mr.request_status = 'closed'), 1) AS average_resolution_hours
FROM properties p
LEFT JOIN units u ON u.property_id = p.property_id
LEFT JOIN maintenance_requests mr ON mr.unit_id = u.unit_id
WHERE p.is_active
GROUP BY p.property_id, p.property_code, p.property_name;
