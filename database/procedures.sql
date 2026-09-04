-- Small functions package reusable business calculations without hiding report SQL.
CREATE OR REPLACE FUNCTION calculate_property_occupancy(p_property_id BIGINT)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT occupancy_percentage
    FROM property_occupancy_view
    WHERE property_id = p_property_id;
$$;

CREATE OR REPLACE FUNCTION calculate_lease_outstanding(p_lease_id BIGINT)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(amount_due - amount_paid), 0)::NUMERIC(14,2)
    FROM payments
    WHERE lease_id = p_lease_id
      AND payment_status NOT IN ('paid', 'waived');
$$;

CREATE OR REPLACE FUNCTION property_summary(p_property_id BIGINT)
RETURNS TABLE (
    property_name VARCHAR,
    occupancy_percentage NUMERIC,
    collection_percentage NUMERIC,
    open_maintenance_requests INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT o.property_name, o.occupancy_percentage, r.collection_percentage, m.open_requests
    FROM property_occupancy_view o
    LEFT JOIN rent_collection_view r USING (property_id)
    LEFT JOIN maintenance_summary_view m USING (property_id)
    WHERE o.property_id = p_property_id;
$$;

-- ADVANCED ENTERPRISE FEATURE 1: Audit Log Table & Trigger Function
CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL,
    record_id BIGINT,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_lease_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_logs (table_name, action, record_id, new_data)
        VALUES ('leases', 'INSERT', NEW.lease_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_logs (table_name, action, record_id, old_data, new_data)
        VALUES ('leases', 'UPDATE', NEW.lease_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_logs (table_name, action, record_id, old_data)
        VALUES ('leases', 'DELETE', OLD.lease_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_leases ON leases;
CREATE TRIGGER trg_audit_leases
AFTER INSERT OR UPDATE OR DELETE ON leases
FOR EACH ROW EXECUTE FUNCTION log_lease_changes();

-- ADVANCED ENTERPRISE FEATURE 2: PL/pgSQL Stored Procedure with Transactional Concurrency Guards
CREATE OR REPLACE PROCEDURE create_lease_transaction(
    p_unit_id BIGINT,
    p_tenant_id BIGINT,
    p_start_date DATE,
    p_end_date DATE,
    p_monthly_rent NUMERIC,
    p_deposit_amount NUMERIC,
    INOUT p_lease_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_unit_exists BIGINT;
    v_tenant_exists BIGINT;
    v_active_lease_exists BIGINT;
    v_payment_ref VARCHAR(100);
BEGIN
    IF p_end_date <= p_start_date THEN
        RAISE EXCEPTION 'Lease end_date (%) must be after start_date (%)', p_end_date, p_start_date;
    END IF;

    -- Validate tenant existence with FOR SHARE lock
    SELECT tenant_id INTO v_tenant_exists FROM tenants WHERE tenant_id = p_tenant_id FOR SHARE;
    IF v_tenant_exists IS NULL THEN
        RAISE EXCEPTION 'Tenant ID % does not exist.', p_tenant_id;
    END IF;

    -- Validate unit & acquire FOR UPDATE lock
    SELECT unit_id INTO v_unit_exists FROM units WHERE unit_id = p_unit_id FOR UPDATE;
    IF v_unit_exists IS NULL THEN
        RAISE EXCEPTION 'Unit ID % does not exist.', p_unit_id;
    END IF;

    -- Check active lease collisions with FOR UPDATE lock
    SELECT lease_id INTO v_active_lease_exists
    FROM leases
    WHERE unit_id = p_unit_id
      AND lease_status = 'active'
      AND start_date <= p_end_date AND end_date >= p_start_date
    FOR UPDATE;

    IF v_active_lease_exists IS NOT NULL THEN
        RAISE EXCEPTION 'Unit ID % is already occupied by active lease #% during this date range.', p_unit_id, v_active_lease_exists;
    END IF;

    -- Step 1: Insert lease record
    INSERT INTO leases (unit_id, tenant_id, start_date, end_date, monthly_rent, security_deposit, lease_status)
    VALUES (p_unit_id, p_tenant_id, p_start_date, p_end_date, p_monthly_rent, p_deposit_amount, 'active')
    RETURNING lease_id INTO p_lease_id;

    -- Step 2: Insert initial deposit payment charge
    v_payment_ref := 'PAY-LEASE-' || p_lease_id || '-' || to_char(p_start_date, 'YYYYMM');
    INSERT INTO payments (lease_id, payment_reference, due_date, amount_due, amount_paid, payment_status, payment_method)
    VALUES (p_lease_id, v_payment_ref, p_start_date, p_monthly_rent, 0.00, 'pending', 'ach');

    -- Step 3: Update unit status to occupied
    UPDATE units SET unit_status = 'occupied' WHERE unit_id = p_unit_id;
END;
$$;

-- ADVANCED ENTERPRISE FEATURE 3: Materialized View for Heavy Performance Reports
CREATE MATERIALIZED VIEW IF NOT EXISTS property_performance_mat_view AS
SELECT o.property_id, o.property_code, o.property_name, o.city,
       o.occupancy_percentage,
       r.expected_rent, r.collected_rent, r.pending_rent, r.collection_percentage,
       m.total_requests, m.open_requests, m.high_priority_requests, m.average_resolution_hours
FROM property_occupancy_view o
LEFT JOIN rent_collection_view r USING (property_id)
LEFT JOIN maintenance_summary_view m USING (property_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mat_perf_prop ON property_performance_mat_view(property_id);

-- ADVANCED ENTERPRISE FEATURE 4: GIN Index for PostgreSQL Full-Text Search
CREATE INDEX IF NOT EXISTS idx_maintenance_fts ON maintenance_requests USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '')));

