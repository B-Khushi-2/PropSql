from query_loader import get_query, load_queries
from services.assistant_service import is_read_only_sql


def test_required_named_queries_are_available():
    queries = load_queries()
    assert "occupancy_report" in queries
    assert "property_performance_report" in queries
    assert "assistant_duplicate_payments" in queries


def test_assistant_queries_are_read_only():
    names = [name for name in load_queries() if name.startswith("assistant_")]
    assert names
    assert all(is_read_only_sql(get_query(name)) for name in names)


def test_write_statements_are_rejected():
    assert not is_read_only_sql("DELETE FROM payments")
    assert not is_read_only_sql("WITH x AS (DELETE FROM payments RETURNING *) SELECT * FROM x")
    assert is_read_only_sql("SELECT * FROM properties")
