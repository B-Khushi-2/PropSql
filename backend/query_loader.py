import re
from functools import lru_cache
from pathlib import Path

from config import PROJECT_ROOT

NAMED_QUERY_PATTERN = re.compile(
    r"^-- name:\s*([a-z0-9_]+)\s*$\n(.*?)^-- end\s*$",
    re.MULTILINE | re.DOTALL,
)


@lru_cache(maxsize=1)
def load_queries():
    queries = {}
    for path in sorted((PROJECT_ROOT / "sql").glob("*.sql")):
        content = path.read_text(encoding="utf-8")
        for name, sql in NAMED_QUERY_PATTERN.findall(content):
            if name in queries:
                raise ValueError(f"Duplicate named query: {name}")
            queries[name] = sql.strip().rstrip(";")
    return queries


def get_query(name):
    try:
        return load_queries()[name]
    except KeyError as exc:
        raise KeyError(f"Unknown SQL query: {name}") from exc
