from db import execute_query
from query_loader import get_query


def run_report(name, params=None):
    return execute_query(get_query(name), params or {}, readonly=True)


def explain_query(name):
    sql = get_query(name)
    rows = execute_query(f"EXPLAIN (ANALYZE, FORMAT JSON, COSTS, VERBOSE) {sql}", readonly=True)
    return rows[0].get("QUERY PLAN", []) if rows else []
