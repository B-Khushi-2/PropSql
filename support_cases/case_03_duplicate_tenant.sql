-- Title: Tenant Appearing Multiple Times
-- Severity: Medium
-- ## Problem
-- The tenant directory shows the same tenant on many rows.
-- ## Investigation SQL
SELECT t.tenant_id, t.email, COUNT(*) AS joined_rows
FROM tenants t JOIN leases l ON l.tenant_id = t.tenant_id
JOIN payments p ON p.lease_id = l.lease_id
GROUP BY t.tenant_id, t.email HAVING COUNT(*) > 1;
-- ## Expected Result
-- One row per tenant in a tenant summary report.
-- ## Actual Result
-- One row appears for every payment belonging to the tenant.
-- ## Root Cause
-- Transaction-level payment detail was joined into an entity-level tenant list.
-- ## Fix
SELECT t.tenant_id, t.first_name, t.last_name, t.email, COUNT(l.lease_id) AS lease_count
FROM tenants t LEFT JOIN leases l ON l.tenant_id = t.tenant_id
GROUP BY t.tenant_id;
-- ## Validation SQL
WITH report AS (
  SELECT t.tenant_id FROM tenants t LEFT JOIN leases l ON l.tenant_id = t.tenant_id GROUP BY t.tenant_id
)
SELECT tenant_id, COUNT(*) FROM report GROUP BY tenant_id HAVING COUNT(*) > 1;
-- Expected: zero rows.
