-- Title: Unusually High Property Maintenance Cost
-- Severity: Medium
-- ## Problem
-- One property's maintenance spend is much higher than the portfolio norm.
-- ## Investigation SQL
WITH property_cost AS (
 SELECT p.property_id, p.property_name, SUM(wo.labor_cost + wo.material_cost) AS total_cost
 FROM work_orders wo JOIN maintenance_requests mr ON mr.request_id = wo.request_id
 JOIN units u ON u.unit_id = mr.unit_id JOIN properties p ON p.property_id = u.property_id
 WHERE wo.work_order_status = 'completed' GROUP BY p.property_id, p.property_name
)
SELECT *, ROUND(AVG(total_cost) OVER (), 2) AS portfolio_average
FROM property_cost ORDER BY total_cost DESC;
-- ## Expected Result
-- High-cost properties are explainable by work volume or specific invoices.
-- ## Actual Result
-- A raw total alone makes large properties look anomalous and can hide duplicate work orders.
-- ## Root Cause
-- The report lacked normalized cost-per-job and invoice-level drill-down.
-- ## Fix
SELECT p.property_name, COUNT(wo.work_order_id) AS jobs,
       SUM(wo.labor_cost + wo.material_cost) AS total_cost,
       AVG(wo.labor_cost + wo.material_cost) AS cost_per_job
FROM work_orders wo JOIN maintenance_requests mr ON mr.request_id = wo.request_id
JOIN units u ON u.unit_id = mr.unit_id JOIN properties p ON p.property_id = u.property_id
WHERE wo.work_order_status = 'completed' GROUP BY p.property_id ORDER BY cost_per_job DESC;
-- ## Validation SQL
-- Review the top properties against individual work_order_id and vendor invoices.
