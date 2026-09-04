-- CTEs separate expected and collected amounts before joining; this prevents fan-out.
WITH expected AS (
    SELECT u.property_id, SUM(l.monthly_rent) AS expected_rent
    FROM active_leases_view l
    JOIN units u ON u.unit_id = l.unit_id
    GROUP BY u.property_id
), collected AS (
    SELECT u.property_id, SUM(p.amount_paid) AS collected_rent
    FROM payments p
    JOIN leases l ON l.lease_id = p.lease_id
    JOIN units u ON u.unit_id = l.unit_id
    WHERE p.due_date >= date_trunc('month', CURRENT_DATE)
      AND p.due_date < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
    GROUP BY u.property_id
)
SELECT pr.property_name, e.expected_rent, COALESCE(c.collected_rent, 0) AS collected_rent,
       e.expected_rent - COALESCE(c.collected_rent, 0) AS pending_rent
FROM properties pr
JOIN expected e ON e.property_id = pr.property_id
LEFT JOIN collected c ON c.property_id = pr.property_id
ORDER BY pending_rent DESC;

-- A second CTE makes the resolution-time formula readable and reusable.
WITH resolved AS (
    SELECT u.property_id, mr.request_id,
           EXTRACT(EPOCH FROM (mr.closed_at - mr.created_at)) / 3600.0 AS resolution_hours
    FROM maintenance_requests mr
    JOIN units u ON u.unit_id = mr.unit_id
    WHERE mr.request_status = 'closed'
)
SELECT p.property_name, COUNT(r.request_id) AS closed_requests,
       ROUND(AVG(r.resolution_hours), 1) AS average_resolution_hours
FROM properties p
LEFT JOIN resolved r ON r.property_id = p.property_id
GROUP BY p.property_id, p.property_name
ORDER BY average_resolution_hours DESC NULLS LAST;
