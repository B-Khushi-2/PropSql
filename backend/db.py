from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool

from config import Config


class DatabaseUnavailable(RuntimeError):
    pass


_pool = None


def init_pool():
    global _pool
    if _pool is None:
        if not Config.DATABASE_URL:
            raise DatabaseUnavailable("DATABASE_URL is not configured. Copy .env.example to .env.")
        try:
            _pool = SimpleConnectionPool(1, 8, dsn=Config.DATABASE_URL)
        except psycopg2.Error as exc:
            raise DatabaseUnavailable("PostgreSQL is unavailable. Check DATABASE_URL and start PostgreSQL.") from exc
    return _pool


@contextmanager
def connection(readonly=True):
    pool = init_pool()
    conn = pool.getconn()
    try:
        conn.set_session(readonly=readonly, autocommit=False)
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        pool.putconn(conn)


def execute_query(sql, params=None, readonly=True):
    try:
        with connection(readonly=readonly) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                if params is None:
                    cursor.execute(sql)
                else:
                    cursor.execute(sql, params)
                return [dict(row) for row in cursor.fetchall()] if cursor.description else []
    except DatabaseUnavailable:
        raise
    except psycopg2.Error as exc:
        raise RuntimeError("The database could not complete this request.") from exc


def close_pool():
    global _pool
    if _pool is not None:
        _pool.closeall()
        _pool = None
