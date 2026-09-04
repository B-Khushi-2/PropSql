BEGIN;

CREATE TABLE properties (
    property_id BIGSERIAL PRIMARY KEY,
    property_code VARCHAR(12) NOT NULL UNIQUE,
    property_name VARCHAR(120) NOT NULL,
    address_line1 VARCHAR(160) NOT NULL,
    city VARCHAR(80) NOT NULL,
    state_code CHAR(2) NOT NULL,
    postal_code VARCHAR(10) NOT NULL,
    manager_name VARCHAR(120) NOT NULL,
    acquisition_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE units (
    unit_id BIGSERIAL PRIMARY KEY,
    property_id BIGINT NOT NULL REFERENCES properties(property_id) ON DELETE RESTRICT,
    unit_number VARCHAR(20) NOT NULL,
    bedrooms SMALLINT NOT NULL CHECK (bedrooms BETWEEN 0 AND 8),
    bathrooms NUMERIC(3,1) NOT NULL CHECK (bathrooms BETWEEN 0.5 AND 8),
    square_feet INTEGER NOT NULL CHECK (square_feet BETWEEN 150 AND 10000),
    market_rent NUMERIC(12,2) NOT NULL CHECK (market_rent > 0),
    unit_status VARCHAR(20) NOT NULL DEFAULT 'vacant'
        CHECK (unit_status IN ('occupied', 'vacant', 'maintenance', 'offline')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (property_id, unit_number)
);

CREATE TABLE tenants (
    tenant_id BIGSERIAL PRIMARY KEY,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    phone VARCHAR(30) NOT NULL,
    emergency_contact VARCHAR(160),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE leases (
    lease_id BIGSERIAL PRIMARY KEY,
    unit_id BIGINT NOT NULL REFERENCES units(unit_id) ON DELETE RESTRICT,
    tenant_id BIGINT NOT NULL REFERENCES tenants(tenant_id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    monthly_rent NUMERIC(12,2) NOT NULL CHECK (monthly_rent > 0),
    security_deposit NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (security_deposit >= 0),
    lease_status VARCHAR(20) NOT NULL
        CHECK (lease_status IN ('draft', 'active', 'expired', 'terminated')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (end_date > start_date)
);

CREATE TABLE payments (
    payment_id BIGSERIAL PRIMARY KEY,
    lease_id BIGINT NOT NULL REFERENCES leases(lease_id) ON DELETE RESTRICT,
    payment_reference VARCHAR(40) NOT NULL UNIQUE,
    due_date DATE NOT NULL,
    paid_date DATE,
    amount_due NUMERIC(12,2) NOT NULL CHECK (amount_due > 0),
    amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
    payment_status VARCHAR(20) NOT NULL
        CHECK (payment_status IN ('pending', 'partial', 'paid', 'late', 'waived')),
    payment_method VARCHAR(30)
        CHECK (payment_method IS NULL OR payment_method IN ('ach', 'card', 'check', 'cash', 'bank_transfer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (amount_paid <= amount_due),
    CHECK ((payment_status = 'pending' AND amount_paid = 0 AND paid_date IS NULL)
        OR payment_status <> 'pending')
);

CREATE TABLE maintenance_requests (
    request_id BIGSERIAL PRIMARY KEY,
    unit_id BIGINT NOT NULL REFERENCES units(unit_id) ON DELETE RESTRICT,
    tenant_id BIGINT REFERENCES tenants(tenant_id) ON DELETE SET NULL,
    title VARCHAR(160) NOT NULL,
    description TEXT NOT NULL,
    priority VARCHAR(12) NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'emergency')),
    request_status VARCHAR(20) NOT NULL
        CHECK (request_status IN ('open', 'assigned', 'in_progress', 'on_hold', 'closed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (closed_at IS NULL OR closed_at >= created_at),
    CHECK (request_status <> 'closed' OR closed_at IS NOT NULL)
);

CREATE TABLE vendors (
    vendor_id BIGSERIAL PRIMARY KEY,
    vendor_name VARCHAR(140) NOT NULL UNIQUE,
    specialty VARCHAR(80) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    phone VARCHAR(30) NOT NULL,
    hourly_rate NUMERIC(10,2) CHECK (hourly_rate > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE work_orders (
    work_order_id BIGSERIAL PRIMARY KEY,
    request_id BIGINT NOT NULL REFERENCES maintenance_requests(request_id) ON DELETE RESTRICT,
    vendor_id BIGINT REFERENCES vendors(vendor_id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    scheduled_date DATE,
    completed_at TIMESTAMPTZ,
    labor_cost NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (labor_cost >= 0),
    material_cost NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (material_cost >= 0),
    work_order_status VARCHAR(20) NOT NULL
        CHECK (work_order_status IN ('assigned', 'scheduled', 'in_progress', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (completed_at IS NULL OR completed_at >= assigned_at),
    CHECK (work_order_status <> 'completed' OR completed_at IS NOT NULL)
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER properties_updated_at BEFORE UPDATE ON properties
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER units_updated_at BEFORE UPDATE ON units
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER tenants_updated_at BEFORE UPDATE ON tenants
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER leases_updated_at BEFORE UPDATE ON leases
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER payments_updated_at BEFORE UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER maintenance_requests_updated_at BEFORE UPDATE ON maintenance_requests
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER work_orders_updated_at BEFORE UPDATE ON work_orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
