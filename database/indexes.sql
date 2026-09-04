-- Foreign-key indexes support joins and prevent full scans during parent updates.
CREATE INDEX idx_units_property ON units(property_id);
CREATE INDEX idx_leases_unit_dates ON leases(unit_id, start_date, end_date);
CREATE INDEX idx_leases_tenant ON leases(tenant_id);
CREATE INDEX idx_leases_status_end ON leases(lease_status, end_date);
CREATE UNIQUE INDEX uq_one_active_lease_per_unit ON leases(unit_id) WHERE lease_status = 'active';
CREATE INDEX idx_payments_lease_due ON payments(lease_id, due_date);
CREATE INDEX idx_payments_status_due ON payments(payment_status, due_date);
CREATE INDEX idx_maintenance_unit_status ON maintenance_requests(unit_id, request_status);
CREATE INDEX idx_maintenance_created ON maintenance_requests(created_at DESC);
CREATE INDEX idx_work_orders_request ON work_orders(request_id);
CREATE INDEX idx_work_orders_vendor_status ON work_orders(vendor_id, work_order_status);

-- Expression index makes case-insensitive tenant searches sargable.
CREATE INDEX idx_tenants_lower_name ON tenants(lower(last_name), lower(first_name));
