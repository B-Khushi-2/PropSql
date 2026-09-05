from datetime import date

from flask import Blueprint, jsonify, request
from psycopg2.extras import RealDictCursor

from config import Config
from db import connection
from query_loader import get_query
from services.assistant_service import answer_question
from services.report_service import explain_query, run_report
from services.support_service import get_case, list_cases

api = Blueprint("api", __name__, url_prefix="/api")


@api.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "*"
    return response


def get_active_role():
    raw_role = (request.args.get("role") or request.headers.get("X-User-Role", "property_manager")).lower().strip()
    if raw_role in ("property_manager", "operations"):
        return "property_manager"
    return raw_role


def enforce_role(allowed_roles):
    role = get_active_role()
    if role not in allowed_roles:
        return jsonify({"error": f"Forbidden: Role '{role}' is not authorized to access this endpoint."}), 403
    return None


def pagination_params():
    try:
        page = max(int(request.args.get("page", 1)), 1)
        raw_size = int(request.args.get("page_size", 50))
        page_size = min(max(raw_size, 1), 500)
    except ValueError as exc:
        raise ValueError("page and page_size must be integers.") from exc
    return page, page_size, {"limit": page_size, "offset": (page - 1) * page_size}


@api.get("/health")
def health():
    row = run_report("dashboard_summary")[0]
    return jsonify({"status": "ok", "database": "connected", "properties": row["total_properties"]})


@api.get("/dashboard")
def dashboard():
    err = enforce_role(["property_manager", "support_engineer", "tenant", "vendor"])
    if err:
        return err
    return jsonify({
        "summary": run_report("dashboard_summary")[0],
        "occupancy": run_report("occupancy_report"),
        "rent_collection": run_report("rent_collection_report", {"report_month": date.today().replace(day=1)}),
        "recent_maintenance": run_report("recent_maintenance"),
        "upcoming_expirations": run_report("upcoming_expirations"),
    })


@api.get("/properties")
@api.get("/units")
@api.get("/tenants")
@api.get("/leases")
@api.get("/payments")
@api.get("/maintenance")
def entity_list():
    err = enforce_role(["property_manager", "support_engineer", "tenant", "vendor"])
    if err:
        return err
    entity = request.path.rsplit("/", 1)[-1]
    page, page_size, params = pagination_params()
    return jsonify({"data": run_report(f"{entity}_list", params), "pagination": {"page": page, "page_size": page_size}})


@api.post("/leases")
def create_lease():
    err = enforce_role(["property_manager"])
    if err:
        return err

    payload = request.get_json(silent=True) or {}
    try:
        unit_id = int(payload["unit_id"])
        tenant_id = int(payload["tenant_id"])
        start_date = date.fromisoformat(str(payload["start_date"]))
        end_date = date.fromisoformat(str(payload["end_date"]))
        monthly_rent = float(payload["monthly_rent"])
        deposit_amount = float(payload.get("deposit_amount", monthly_rent))
    except (KeyError, ValueError, TypeError) as exc:
        raise ValueError("Invalid payload: unit_id, tenant_id, start_date, end_date, monthly_rent are required.") from exc

    if end_date <= start_date:
        raise ValueError("Lease end_date must be after start_date.")

    # Execute PL/pgSQL Stored Procedure inside a PostgreSQL write transaction
    with connection(readonly=False) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                CALL create_lease_transaction(%s, %s, %s, %s, %s, %s, NULL);
            """, (unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount))
            res = cursor.fetchone()
            lease_id = res["p_lease_id"] if res and "p_lease_id" in res else None

    return jsonify({
        "status": "success",
        "message": f"Lease #{lease_id} created successfully via PL/pgSQL stored procedure.",
        "data": {
            "lease_id": lease_id,
            "unit_id": unit_id,
            "tenant_id": tenant_id,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "monthly_rent": monthly_rent,
            "status": "active"
        }
    }), 201


from datetime import date, datetime

@api.get("/audit-logs")
def audit_logs():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    page, page_size, params = pagination_params()
    sql = "SELECT audit_id, table_name, action, record_id, old_data, new_data, changed_at FROM audit_logs ORDER BY audit_id DESC LIMIT %(limit)s OFFSET %(offset)s;"
    with connection(readonly=True) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute(sql, params)
            rows = []
            for r in cursor.fetchall():
                row = dict(r)
                if isinstance(row.get("changed_at"), (date, datetime)):
                    row["changed_at"] = row["changed_at"].isoformat()
                rows.append(row)
    return jsonify({"data": rows, "pagination": {"page": page, "page_size": page_size}})


@api.get("/maintenance/search")
def maintenance_search():
    err = enforce_role(["property_manager", "support_engineer", "tenant", "vendor"])
    if err:
        return err
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify([])
    sql = """
        SELECT mr.request_id, u.property_id, mr.unit_id, mr.title, mr.priority, mr.request_status, mr.created_at,
               ts_rank(to_tsvector('english', mr.title || ' ' || COALESCE(mr.description, '')), plainto_tsquery('english', %s)) AS rank
        FROM maintenance_requests mr
        JOIN units u ON u.unit_id = mr.unit_id
        WHERE to_tsvector('english', mr.title || ' ' || COALESCE(mr.description, '')) @@ plainto_tsquery('english', %s)
        ORDER BY rank DESC, mr.created_at DESC
        LIMIT 50;
    """
    with connection(readonly=True) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute(sql, (q, q))
            rows = []
            for r in cursor.fetchall():
                row = dict(r)
                if isinstance(row.get("created_at"), (date, datetime)):
                    row["created_at"] = row["created_at"].isoformat()
                rows.append(row)
    return jsonify(rows)


@api.post("/maintenance/<int:request_id>/status")
def update_maintenance_status(request_id):
    err = enforce_role(["property_manager", "vendor", "tenant", "support_engineer"])
    if err:
        return err

    payload = request.get_json(silent=True) or {}
    new_status = str(payload.get("request_status", "")).lower().strip()
    allowed_statuses = ("open", "assigned", "in_progress", "on_hold", "closed", "cancelled")
    if new_status not in allowed_statuses:
        raise ValueError(f"Invalid status. Must be one of: {', '.join(allowed_statuses)}")

    role = get_active_role()
    if role == "vendor" and new_status not in ("in_progress", "closed", "assigned"):
        return jsonify({"error": "Forbidden: Vendors can only update status to 'in_progress' or 'closed'."}), 403

    if role == "tenant" and new_status != "cancelled":
        return jsonify({"error": "Forbidden: Tenants can only cancel their maintenance requests."}), 403

    with connection(readonly=False) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                UPDATE maintenance_requests
                SET request_status = %s,
                    closed_at = CASE WHEN %s = 'closed' THEN CURRENT_TIMESTAMP ELSE closed_at END,
                    updated_at = CURRENT_TIMESTAMP
                WHERE request_id = %s
                RETURNING request_id, request_status, closed_at;
            """, (new_status, new_status, request_id))
            updated = cursor.fetchone()
            if not updated:
                raise ValueError(f"Maintenance request #{request_id} does not exist.")

    return jsonify({
        "status": "success",
        "message": f"Maintenance request #{request_id} status updated to '{new_status}'.",
        "data": updated
    })


@api.post("/maintenance")
def create_maintenance():
    err = enforce_role(["property_manager", "tenant", "support_engineer"])
    if err:
        return err

    payload = request.get_json(silent=True) or {}
    try:
        unit_id = int(payload["unit_id"])
        title = str(payload["title"]).strip()
        description = str(payload.get("description", title)).strip()
        priority = str(payload.get("priority", "medium")).lower().strip()
    except (KeyError, ValueError, TypeError) as exc:
        raise ValueError("unit_id and title are required.") from exc

    if priority not in ("low", "medium", "high", "emergency"):
        priority = "medium"

    role = get_active_role()
    tenant_id = int(request.headers.get("X-Tenant-ID", 1)) if role == "tenant" else int(payload.get("tenant_id", 1))

    with connection(readonly=False) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                INSERT INTO maintenance_requests (unit_id, tenant_id, title, description, priority, request_status)
                VALUES (%s, %s, %s, %s, %s, 'open')
                RETURNING request_id, title, request_status, created_at;
            """, (unit_id, tenant_id, title, description, priority))
            new_req = cursor.fetchone()

    return jsonify({
        "status": "success",
        "message": f"Maintenance ticket #{new_req['request_id']} submitted successfully.",
        "data": new_req
    }), 201


@api.post("/payments/<int:payment_id>/pay")
def pay_payment(payment_id):
    err = enforce_role(["property_manager", "tenant", "support_engineer"])
    if err:
        return err

    with connection(readonly=False) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                UPDATE payments
                SET amount_paid = amount_due,
                    payment_status = 'paid',
                    paid_date = CURRENT_DATE,
                    updated_at = CURRENT_TIMESTAMP
                WHERE payment_id = %s AND payment_status <> 'paid'
                RETURNING payment_id, payment_reference, amount_due, payment_status, paid_date;
            """, (payment_id,))
            updated = cursor.fetchone()
            if not updated:
                raise ValueError(f"Payment #{payment_id} is already paid or does not exist.")

    return jsonify({
        "status": "success",
        "message": f"Payment #{payment_id} processed successfully.",
        "data": updated
    })


@api.get("/reports/occupancy")
def occupancy_report():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    return jsonify(run_report("occupancy_report"))


@api.get("/reports/rent-collection")
def rent_collection_report():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    month = request.args.get("month", date.today().replace(day=1).isoformat())
    try:
        report_month = date.fromisoformat(month).replace(day=1)
    except ValueError as exc:
        raise ValueError("month must be an ISO date such as 2026-09-01.") from exc
    return jsonify(run_report("rent_collection_report", {"report_month": report_month}))


@api.get("/reports/lease-expiry")
def lease_expiry_report():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    try:
        days = int(request.args.get("days", 30))
    except ValueError as exc:
        raise ValueError("days must be 30, 60, or 90.") from exc
    if days not in (30, 60, 90):
        raise ValueError("days must be 30, 60, or 90.")
    return jsonify(run_report("lease_expiry_report", {"days": days}))


@api.get("/reports/tenant-payment-history")
def tenant_payment_history():
    err = enforce_role(["property_manager", "support_engineer", "tenant", "tenant_resident"])
    if err:
        return err

    role = get_active_role()
    if role in ("tenant", "tenant_resident"):
        auth_tenant_id = request.headers.get("X-Tenant-ID", "1")
        try:
            auth_tenant_id = int(auth_tenant_id)
        except ValueError:
            auth_tenant_id = 1
        raw_id = request.args.get("tenant_id")
        if raw_id and int(raw_id) != auth_tenant_id:
            return jsonify({"error": "Forbidden: Tenants are only authorized to view their own payment ledger."}), 403
        tenant_id = auth_tenant_id
    else:
        raw_id = request.args.get("tenant_id")
        try:
            tenant_id = int(raw_id) if raw_id else None
        except ValueError as exc:
            raise ValueError("tenant_id must be an integer.") from exc

    return jsonify(run_report("tenant_payment_history", {"tenant_id": tenant_id}))


@api.get("/reports/delinquent-tenants")
def delinquent_tenants():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    return jsonify(run_report("delinquent_tenant_report"))


@api.get("/reports/maintenance")
def maintenance_report():
    err = enforce_role(["property_manager", "support_engineer", "tenant", "vendor"])
    if err:
        return err
    return jsonify(run_report("maintenance_report"))


@api.get("/reports/property-performance")
def property_performance_report():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    return jsonify(run_report("property_performance_report"))


@api.get("/support/cases")
def support_cases():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    return jsonify([{"id": c["id"], "title": c["title"], "severity": c["severity"]} for c in list_cases()])


@api.get("/support/cases/<int:case_id>")
def support_case(case_id):
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    return jsonify(get_case(case_id))


PERFORMANCE_EXAMPLES = [
    {"id": "expiry", "title": "Lease expiry lookup", "before": "optimization_expiry_before", "after": "optimization_expiry_after", "index": "idx_leases_status_end", "issue": "A function on end_date prevents a direct range lookup."},
    {"id": "tenant", "title": "Tenant name lookup", "before": "optimization_tenant_before", "after": "optimization_tenant_after", "index": "idx_tenants_lower_name", "issue": "Concatenation plus a leading wildcard requires broad row inspection."},
    {"id": "payments", "title": "Lease payment totals", "before": "optimization_payment_before", "after": "optimization_payment_after", "index": "idx_payments_lease_due", "issue": "The correlated aggregate repeats payment access for each lease."},
]


@api.get("/audit-logs")
def get_audit_logs():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    try:
        page = max(int(request.args.get("page", 1)), 1)
        page_size = min(max(int(request.args.get("page_size", 50)), 1), 500)
    except Exception:
        page, page_size = 1, 50
    offset = (page - 1) * page_size
    with connection.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS audit_logs (
                audit_id BIGSERIAL PRIMARY KEY,
                table_name VARCHAR(50) NOT NULL,
                action VARCHAR(20) NOT NULL,
                record_id BIGINT,
                old_data JSONB,
                new_data JSONB,
                changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        connection.commit()
        cur.execute("""
            SELECT audit_id, table_name, action, record_id, old_data, new_data, changed_at
            FROM audit_logs
            ORDER BY changed_at DESC, audit_id DESC
            LIMIT %s OFFSET %s;
        """, (page_size, offset))
        rows = cur.fetchall()
        for row in rows:
            if row.get("changed_at"):
                row["changed_at"] = row["changed_at"].isoformat()
    return jsonify({"data": rows, "pagination": {"page": page, "page_size": page_size}})


@api.get("/performance")
def performance():
    err = enforce_role(["property_manager", "support_engineer"])
    if err:
        return err
    results = []
    for item in PERFORMANCE_EXAMPLES:
        results.append({**item, "before_sql": get_query(item["before"]),
                        "after_sql": get_query(item["after"]),
                        "before_plan": explain_query(item["before"]), "after_plan": explain_query(item["after"])})
    return jsonify(results)


@api.post("/assistant")
def assistant():
    err = enforce_role(["property_manager", "support_engineer", "tenant", "vendor"])
    if err:
        return err
    payload = request.get_json(silent=True) or {}
    question = str(payload.get("question", "")).strip()
    if not question or len(question) > 300:
        raise ValueError("Provide a question between 1 and 300 characters.")
    return jsonify(answer_question(question))

