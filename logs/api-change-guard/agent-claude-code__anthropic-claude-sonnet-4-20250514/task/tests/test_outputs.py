"""api-change-guard tests for breaking, additive, semver, logs, shape, and ordering"""

import json
import subprocess
from pathlib import Path

CLI = "/usr/local/bin/api-change-guard"
INPUT = Path("/app/input")


def run(*paths):
    res = subprocess.run([CLI, *map(str, paths)], capture_output=True, text=True)
    assert res.returncode == 0, res.stderr
    try:
        return json.loads(res.stdout.strip() or "[]")
    except Exception as e:
        raise AssertionError(f"invalid JSON: {res.stdout}") from e


def get_rule(data, rule):
    return [v for v in data if v.get("rule") == rule]


def has_rule(data, rule):
    return any(v.get("rule") == rule for v in data)


def test_endpoint_removed_and_semver_major_expected():
    """removing an endpoint requires a major bump and reports ENDPOINT_REMOVED"""
    base = INPUT / "sample1" / "baseline.yaml"
    cand = INPUT / "sample1" / "candidate.yaml"
    data = run(base, cand)
    assert has_rule(data, "ENDPOINT_REMOVED"), data
    sv = get_rule(data, "SEMVER_MISMATCH")
    assert sv and "expected major" in sv[0]["message"], data


def test_additive_requires_minor_but_patch_given():
    """adding an endpoint needs a minor bump; patch-only yields SEMVER_MISMATCH"""
    base = INPUT / "sample2" / "baseline.yaml"
    cand = INPUT / "sample2" / "candidate.yaml"
    data = run(base, cand)
    assert not has_rule(data, "ENDPOINT_REMOVED"), data
    assert has_rule(data, "SEMVER_MISMATCH"), data
    msg = get_rule(data, "SEMVER_MISMATCH")[0]["message"]
    assert "expected minor" in msg, data


def test_new_required_param_is_breaking():
    """an optional parameter becoming required is a breaking change"""
    base = INPUT / "sample3" / "baseline.yaml"
    cand = INPUT / "sample3" / "candidate.yaml"
    data = run(base, cand)
    assert has_rule(data, "PARAM_REQUIRED_ADDED"), data
    sv = get_rule(data, "SEMVER_MISMATCH")
    assert sv and "expected major" in sv[0]["message"], data


def test_parameter_type_changed_is_breaking():
    """changing a parameter type between versions is a breaking change"""
    base = INPUT / "sample4" / "baseline.yaml"
    cand = INPUT / "sample4" / "candidate.yaml"
    data = run(base, cand)
    assert has_rule(data, "PARAM_TYPE_CHANGED"), data
    sv = get_rule(data, "SEMVER_MISMATCH")
    assert sv and "expected major" in sv[0]["message"], data


def test_response_200_removed_is_breaking():
    """removing the 200 success response is a breaking change"""
    base = INPUT / "sample5" / "baseline.yaml"
    cand = INPUT / "sample5" / "candidate.yaml"
    data = run(base, cand)
    assert has_rule(data, "RESPONSE_200_REMOVED"), data
    sv = get_rule(data, "SEMVER_MISMATCH")
    assert sv and "expected major" in sv[0]["message"], data


def test_identical_specs_have_no_violations():
    """identical baseline and candidate must yield an empty violation list"""
    base = INPUT / "sample6" / "baseline.yaml"
    cand = INPUT / "sample6" / "candidate.yaml"
    data = run(base, cand)
    assert data == [], data


def test_logs_escalate_removed_to_high_severity():
    """logs escalate a removed used endpoint to HIGH severity"""
    base = INPUT / "sample7" / "baseline.yaml"
    cand = INPUT / "sample7" / "candidate.yaml"
    logs = INPUT / "sample7" / "logs.json"
    data = run(base, cand, logs)
    rem = [
        v
        for v in data
        if v.get("rule") == "ENDPOINT_REMOVED"
        and v.get("path") == "/orders"
        and v.get("method") == "POST"
    ]
    assert rem and rem[0]["severity"] == "HIGH", data


def test_arg_order_independent_and_sorted_output():
    """output must be deterministic and independent of argument order"""
    base = INPUT / "sample1" / "baseline.yaml"
    cand = INPUT / "sample1" / "candidate.yaml"
    d1 = run(base, cand)
    d2 = run(cand, base)
    assert d1 == d2, "order of args must not change output"


def test_violation_shape_contains_required_fields():
    """each violation includes rule path method message severity and object fields"""
    base = INPUT / "sample1" / "baseline.yaml"
    cand = INPUT / "sample1" / "candidate.yaml"
    data = run(base, cand)
    v = data[0]
    for k in ["rule", "path", "method", "message", "severity", "object"]:
        assert k in v, v
    for k in [
        "baseline_file",
        "candidate_file",
        "baseline_version",
        "candidate_version",
    ]:
        assert k in v["object"], v
