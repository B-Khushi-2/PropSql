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
    CORS(app)

    app.register_blueprint(api)

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

