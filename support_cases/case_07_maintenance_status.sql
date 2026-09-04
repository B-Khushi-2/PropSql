-- Title: Inconsistent Maintenance Status
-- Severity: Medium
-- ## Problem
-- A request is closed while its work order remains in progress.
-- ## Investigation SQL
SELECT mr.request_id, mr.request_status, mr.closed_at,
       wo.work_order_id, wo.work_order_status, wo.completed_at
FROM maintenance_requests mr JOIN work_orders wo ON wo.request_id = mr.request_id
WHERE (mr.request_status = 'closed' AND wo.work_order_status <> 'completed')
   OR (wo.work_order_status = 'completed' AND mr.request_status <> 'closed');
-- ## Expected Result
-- Completed work and closed requests move together in the service workflow.
-- ## Actual Result
-- Separate updates can leave the parent and child statuses inconsistent.
-- ## Root Cause
-- The application did not wrap the two status changes in one transaction.
-- ## Fix
-- Update both records in one database transaction after validating completion timestamps.
-- ## Validation SQL
SELECT mr.request_id FROM maintenance_requests mr JOIN work_orders wo ON wo.request_id = mr.request_id
WHERE (mr.request_status = 'closed') <> (wo.work_order_status = 'completed');
-- Expected: zero rows for single-work-order requests.
