-- Non-correlated subquery compares each lease with the portfolio average rent.
SELECT lease_id, monthly_rent
FROM leases
WHERE lease_status = 'active'
  AND monthly_rent > (SELECT AVG(monthly_rent) FROM leases WHERE lease_status = 'active')
ORDER BY monthly_rent DESC;

-- Correlated EXISTS is clearer than a join when only the existence of debt matters.
SELECT t.tenant_id, t.first_name, t.last_name, t.email
FROM tenants t
WHERE EXISTS (
    SELECT 1
    FROM leases l
    JOIN payments p ON p.lease_id = l.lease_id
    WHERE l.tenant_id = t.tenant_id
      AND p.amount_paid < p.amount_due
      AND p.due_date < CURRENT_DATE
)
ORDER BY t.last_name, t.first_name;

-- NOT EXISTS safely finds units without a current lease and avoids NULL pitfalls of NOT IN.
SELECT u.unit_id, u.unit_number, p.property_name
FROM units u
JOIN properties p ON p.property_id = u.property_id
WHERE NOT EXISTS (SELECT 1 FROM active_leases_view al WHERE al.unit_id = u.unit_id)
ORDER BY p.property_name, u.unit_number;
