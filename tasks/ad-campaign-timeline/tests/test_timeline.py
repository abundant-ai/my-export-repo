from __future__ import annotations

import json
import subprocess
from copy import deepcopy
from datetime import date, timedelta
from pathlib import Path

import pytest

TASK_DIR = Path(__file__).resolve().parents[1]
SCENARIO_PATH = TASK_DIR / "data" / "scenario.json"


def _resolve(path: Path) -> Path:
    if path.exists():
        return path
    alt = Path("/app") / path.relative_to(path.anchor or Path("/"))
    if alt.exists():
        return alt
    fallback = Path("/app") / Path(*path.parts[path.is_absolute() :])
    if fallback.exists():
        return fallback
    raise FileNotFoundError(path)


def _run_timeline(payload: dict) -> list[dict]:
    script = _resolve(TASK_DIR / "campaign" / "aggregator.js")
    script_ref = json.dumps(str(script))
    payload_literal = json.dumps(payload)
    node_snippet = f"""
const aggregator = require({script_ref});
const payload = {payload_literal};
const output = aggregator.computeTimeline(payload);
process.stdout.write(JSON.stringify(output));
"""
    completed = subprocess.run(
        ["node", "-e", node_snippet],
        capture_output=True,
        text=True,
        cwd=TASK_DIR,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"Node execution failed: {completed.stderr.strip() or completed.stdout}"
        )
    return json.loads(completed.stdout)


@pytest.fixture(scope="module")
def scenario():
    return json.loads(_resolve(SCENARIO_PATH).read_text())


@pytest.fixture(scope="module")
def timeline(scenario):
    return _run_timeline(scenario)


def _lookup(timeline: list[dict], iso_day: str, flight_id: str):
    for entry in timeline:
        if entry["date"] == iso_day:
            return entry["flights"].get(flight_id)
    return None


def test_timeline_aligns_with_pause_resume_and_budget_overrides(timeline):
    """FlightA reflects overrides, pauses, and resumes on the expected calendar days."""
    entry = _lookup(timeline, "2024-07-01", "flightA")
    assert entry == {"status": "active", "budget": 100}

    entry = _lookup(timeline, "2024-07-02", "flightA")
    assert entry == {"status": "active", "budget": 90}

    entry = _lookup(timeline, "2024-07-05", "flightA")
    assert entry["status"] == "active"
    assert entry["budget"] == pytest.approx(116.28, rel=0, abs=1e-2)

    entry = _lookup(timeline, "2024-07-06", "flightA")
    assert entry == {"status": "active", "budget": 100}

    entry = _lookup(timeline, "2024-07-07", "flightA")
    assert entry["status"] == "active"
    assert entry["budget"] == pytest.approx(38.71, rel=0, abs=1e-2)


def test_end_override_truncates_flight_window(timeline):
    """FlightB respects an end_override that shortens the scheduled run."""
    assert _lookup(timeline, "2024-07-06", "flightB") is None
    entry = _lookup(timeline, "2024-07-05", "flightB")
    assert entry["status"] == "active"
    assert entry["budget"] == pytest.approx(87.21, rel=0, abs=1e-2)


def test_all_flights_present_each_day_until_end(timeline):
    """Timeline includes every calendar day spanned by the campaign configuration."""
    expected_days = set()
    start = date(2024, 7, 1)
    end = date(2024, 7, 8)
    current = start
    while current <= end:
        expected_days.add(current.isoformat())
        current += timedelta(days=1)
    actual_days = {entry["date"] for entry in timeline}
    assert expected_days.issubset(actual_days)


def test_multiple_overrides_use_latest_event_per_day(timeline):
    """The final budget_override event within a day wins over earlier overrides."""
    entry = _lookup(timeline, "2024-07-02", "flightA")
    assert entry["budget"] == 90


def test_paused_days_ignore_budget_overrides(timeline):
    """Pause events enforce zero budget even when an override exists the same day."""
    entry = _lookup(timeline, "2024-07-04", "flightA")
    assert entry == {"status": "paused", "budget": 0}


def test_timezone_conversion_affects_budget_day(timeline):
    """FlightC adjustments cross time zones and still map to the correct local day."""
    entry = _lookup(timeline, "2024-07-05", "flightC")
    assert entry["status"] == "active"
    assert entry["budget"] == pytest.approx(46.51, rel=0, abs=1e-2)

    entry = _lookup(timeline, "2024-07-06", "flightC")
    assert entry == {"status": "paused", "budget": 0}

    entry = _lookup(timeline, "2024-07-07", "flightC")
    assert entry["status"] == "active"
    assert entry["budget"] == pytest.approx(81.29, rel=0, abs=1e-2)

    entry = _lookup(timeline, "2024-07-08", "flightC")
    assert entry == {"status": "active", "budget": 80}


def test_flights_sorted_alphabetically_each_day(timeline):
    """Within each day flight dictionary keys are sorted for deterministic output."""
    for entry in timeline:
        keys = list(entry["flights"].keys())
        assert keys == sorted(keys)


def test_daily_spend_caps_enforced(timeline):
    """Total spend on capped days does not exceed the configured limit."""
    day5 = next(entry for entry in timeline if entry["date"] == "2024-07-05")
    total_day5 = sum(flight["budget"] for flight in day5["flights"].values())
    assert total_day5 == pytest.approx(250.0, rel=0, abs=1e-6)

    day7 = next(entry for entry in timeline if entry["date"] == "2024-07-07")
    total_day7 = sum(flight["budget"] for flight in day7["flights"].values())
    assert total_day7 == pytest.approx(120.0, rel=0, abs=1e-6)


def test_inputs_not_mutated(scenario):
    """computeTimeline must not mutate the provided scenario payload."""
    snapshot = deepcopy(scenario)
    _run_timeline(scenario)
    assert scenario == snapshot
