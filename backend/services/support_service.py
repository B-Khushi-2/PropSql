import re

from config import PROJECT_ROOT

SECTION_PATTERN = re.compile(r"^-- ## (.+)$", re.MULTILINE)


def _parse_case(path):
    raw = path.read_text(encoding="utf-8")
    title_match = re.search(r"^-- Title:\s*(.+)$", raw, re.MULTILINE)
    severity_match = re.search(r"^-- Severity:\s*(.+)$", raw, re.MULTILINE)
    markers = list(SECTION_PATTERN.finditer(raw))
    sections = {}
    for index, marker in enumerate(markers):
        start = marker.end()
        end = markers[index + 1].start() if index + 1 < len(markers) else len(raw)
        body = raw[start:end].strip()
        sections[marker.group(1).lower().replace(" ", "_")] = body
    case_id = int(re.search(r"case_(\d+)", path.name).group(1))
    return {
        "id": case_id,
        "title": title_match.group(1).strip() if title_match else path.stem,
        "severity": severity_match.group(1).strip() if severity_match else "Medium",
        "sections": sections,
        "filename": path.name,
    }


def list_cases():
    return [_parse_case(path) for path in sorted((PROJECT_ROOT / "support_cases").glob("case_*.sql"))]


def get_case(case_id):
    case = next((item for item in list_cases() if item["id"] == case_id), None)
    if not case:
        raise KeyError("Support case not found.")
    return case
