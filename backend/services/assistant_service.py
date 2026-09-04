import re

from query_loader import get_query
from services.report_service import run_report

FORBIDDEN_SQL = re.compile(r"\b(ALTER|CREATE|DELETE|DROP|GRANT|INSERT|REVOKE|TRUNCATE|UPDATE)\b", re.I)


def is_read_only_sql(sql):
    normalized = re.sub(r"--.*?$|/\*.*?\*/", "", sql, flags=re.MULTILINE | re.DOTALL).strip()
    return bool(re.match(r"^(SELECT|WITH)\b", normalized, re.I)) and not FORBIDDEN_SQL.search(normalized)


def answer_question(question):
    text = " ".join(question.lower().split())
    if "occupancy" in text and ("below" in text or "under" in text):
        threshold_match = re.search(r"(\d{1,3})(?:\s*%)?", text)
        threshold = int(threshold_match.group(1)) if threshold_match else 80
        if not 1 <= threshold <= 100:
            raise ValueError("Occupancy threshold must be between 1 and 100.")
        query_name, params = "assistant_low_occupancy", {"threshold": threshold}
        explanation = f"Properties below {threshold}% occupancy, calculated from date-valid active leases."
    elif "lease" in text and ("expire" in text or "expiring" in text):
        days_match = re.search(r"(30|60|90)\s*days?", text)
        days = int(days_match.group(1)) if days_match else 30
        query_name, params = "assistant_expiring_leases", {"days": days}
        explanation = f"Active leases ending in the next {days} days."
    elif "pending" in text and ("payment" in text or "tenant" in text):
        query_name, params = "assistant_pending_payments", {}
        explanation = "Tenants with an unpaid balance on a charge due today or earlier."
    elif ("top" in text or "best" in text) and "collection" in text:
        query_name, params = "assistant_top_collection", {}
        explanation = "The five strongest current-month collection rates."
    elif "duplicate" in text and "payment" in text:
        query_name, params = "assistant_duplicate_payments", {}
        explanation = "Potential duplicate charges sharing the same lease, due date, and amount."
    else:
        raise ValueError("Try asking about low occupancy, expiring leases, pending payments, top rent collection, or duplicate payments.")

    sql = get_query(query_name)
    if not is_read_only_sql(sql):
        raise RuntimeError("The selected query did not pass the read-only safety check.")
    return {"question": question, "explanation": explanation, "sql": sql, "rows": run_report(query_name, params)}
