-- INNER JOIN is used when every returned row must have both a lease and tenant.
SELECT l.lease_id, t.first_name || ' ' || t.last_name AS tenant_name,
       p.property_name, u.unit_number, l.start_date, l.end_date, l.monthly_rent
FROM leases l
JOIN tenants t ON t.tenant_id = l.tenant_id
JOIN units u ON u.unit_id = l.unit_id
JOIN properties p ON p.property_id = u.property_id
WHERE l.lease_status = 'active'
ORDER BY p.property_name, u.unit_number;

-- LEFT JOIN keeps vacant units in the result even when no active lease exists.
SELECT p.property_name, u.unit_number,
       COALESCE(al.first_name || ' ' || al.last_name, 'Vacant') AS current_tenant
FROM units u
JOIN properties p ON p.property_id = u.property_id
LEFT JOIN active_leases_view al ON al.unit_id = u.unit_id
ORDER BY p.property_name, u.unit_number;

-- Multi-table join follows the operational path request -> work order -> vendor.
SELECT mr.request_id, p.property_name, u.unit_number, mr.title,
       wo.work_order_status, v.vendor_name, wo.labor_cost + wo.material_cost AS total_cost
FROM maintenance_requests mr
JOIN units u ON u.unit_id = mr.unit_id
JOIN properties p ON p.property_id = u.property_id
LEFT JOIN work_orders wo ON wo.request_id = mr.request_id
LEFT JOIN vendors v ON v.vendor_id = wo.vendor_id
ORDER BY mr.created_at DESC;
