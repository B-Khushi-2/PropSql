from app import create_app


def test_root_route_identifies_service():
    client = create_app().test_client()
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json()["service"] == "PropSQL API"


def test_invalid_lease_window_is_rejected_before_database_access():
    client = create_app().test_client()
    response = client.get("/api/reports/lease-expiry?days=45")
    assert response.status_code == 400


def test_support_cases_are_available_without_database_access():
    client = create_app().test_client()
    response = client.get("/api/support/cases")
    assert response.status_code == 200
    assert len(response.get_json()) == 10
