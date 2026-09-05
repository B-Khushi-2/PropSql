import logging

import psycopg2
from flask import Flask, jsonify, request
from flask_cors import CORS

from config import Config
from db import DatabaseUnavailable
from routes.api import api


def create_app(config=Config):
    app = Flask(__name__)
    app.config.from_object(config)

    @app.before_request
    def handle_preflight():
        if request.method == "OPTIONS":
            response = jsonify({"status": "ok"})
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Access-Control-Allow-Headers"] = "*"
            response.headers["Access-Control-Allow-Methods"] = "*"
            return response, 200

    app.register_blueprint(api)

    @app.before_first_request
    def init_db_tables():
        pass

    def ensure_audit_logs():
        from db import execute_query
        statements = [
            """CREATE TABLE IF NOT EXISTS audit_logs (
                audit_id BIGSERIAL PRIMARY KEY,
                table_name VARCHAR(50) NOT NULL,
                action VARCHAR(20) NOT NULL,
                record_id BIGINT,
                old_data JSONB,
                new_data JSONB,
                changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );""",
            """CREATE OR REPLACE FUNCTION log_lease_changes()
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
            $$;""",
            "DROP TRIGGER IF EXISTS trg_audit_leases ON leases;",
            """CREATE TRIGGER trg_audit_leases
            AFTER INSERT OR UPDATE OR DELETE ON leases
            FOR EACH ROW EXECUTE FUNCTION log_lease_changes();"""
        ]
        for stmt in statements:
            try:
                execute_query(stmt, readonly=False)
            except Exception as e:
                logging.warning("Auto DDL init notice: %s", e)

    try:
        ensure_audit_logs()
    except Exception as e:
        logging.warning("Startup table ensure notice: %s", e)

    @app.after_request
    def add_cors_headers(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "*"
        return response

    @app.get("/")
    def index():
        return jsonify({"service": "PropSQL API", "docs": "/api/health"})

    @app.errorhandler(ValueError)
    def bad_request(error):
        return jsonify({"error": str(error)}), 400

    @app.errorhandler(KeyError)
    def not_found(error):
        return jsonify({"error": str(error).strip("'")}), 404

    @app.errorhandler(DatabaseUnavailable)
    def database_unavailable(error):
        return jsonify({"error": str(error)}), 503

    @app.errorhandler(RuntimeError)
    def database_error(error):
        app.logger.warning("Database request failed: %s", error)
        return jsonify({"error": str(error)}), 500

    @app.errorhandler(psycopg2.Error)
    def database_psycopg2_error(error):
        app.logger.warning("PostgreSQL error: %s", error)
        clean_msg = getattr(error, 'pgerror', str(error)) or str(error)
        first_line = clean_msg.split('\n')[0].replace('ERROR:', '').strip()
        return jsonify({"error": f"Database Integrity Error: {first_line}"}), 400

    @app.errorhandler(404)
    def route_not_found(_error):
        return jsonify({"error": "API route not found."}), 404

    @app.errorhandler(Exception)
    def unexpected_error(error):
        app.logger.exception("Unexpected API error: %s", error)
        return jsonify({"error": "An unexpected server error occurred."}), 500

    return app


app = create_app()

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    app.run(host=Config.API_HOST, port=Config.API_PORT, debug=False)

