from services.support_service import get_case, list_cases


def test_all_support_cases_have_required_sections():
    cases = list_cases()
    required = {"problem", "investigation_sql", "expected_result", "actual_result", "root_cause", "fix", "validation_sql"}
    assert len(cases) == 10
    assert all(required.issubset(case["sections"]) for case in cases)


def test_missing_case_raises_key_error():
    try:
        get_case(999)
    except KeyError:
        return
    raise AssertionError("Missing support case should raise KeyError")
