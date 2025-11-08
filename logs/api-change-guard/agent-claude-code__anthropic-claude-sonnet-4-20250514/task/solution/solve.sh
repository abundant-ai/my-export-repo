#!/usr/bin/env bash
set -euo pipefail

cat > /usr/local/bin/api-change-guard <<'PY'
#!/usr/bin/env python3
import sys, json, yaml, pathlib, re
from typing import Dict, Tuple, List, Any, Optional

def load_yaml(p: pathlib.Path) -> Dict[str, Any]:
    d = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    return d if isinstance(d, dict) else {}

def find_pair(args: List[str]):
    fs = [pathlib.Path(a) for a in args if a]
    logs = next((p for p in fs if p.suffix == ".json"), None)
    specs = [p for p in fs if p.suffix in (".yml", ".yaml")]
    if len(specs) >= 2:
        def score(p: pathlib.Path) -> int:
            name = p.name.lower()
            return 0 if "baseline" in name else (1 if "candidate" in name else 2)
        specs_sorted = sorted(specs, key=score)
        return specs_sorted[0], specs_sorted[1], logs
    dirs = [p for p in fs if p.is_dir()]
    if not dirs:
        raise SystemExit(2)
    root = dirs[0]
    base = next((q for q in [root/"baseline.yaml", root/"baseline.yml"] if q.exists()), None)
    cand = next((q for q in [root/"candidate.yaml", root/"candidate.yml"] if q.exists()), None)
    if not base or not cand:
        raise SystemExit(2)
    return base, cand, logs

def gather_ops(spec: Dict[str, Any]) -> Dict[Tuple[str, str], Dict[str, Any]]:
    paths = spec.get("paths") or {}
    out = {}
    for pth, ops in paths.items():
        if not isinstance(ops, dict): continue
        for m in ["get","post","put","patch","delete","head","options","trace"]:
            op = ops.get(m)
            if isinstance(op, dict):
                out[(pth, m.upper())] = op
    return out

def params_map(op: Dict[str, Any]) -> Dict[Tuple[str, str], Dict[str, Any]]:
    ps = op.get("parameters") or []
    out = {}
    for p in ps:
        name = str(p.get("name"))
        loc = str(p.get("in"))
        out[(name, loc)] = p
    return out

def schema_type(param: Dict[str, Any]) -> Optional[str]:
    s = param.get("schema") or {}
    t = s.get("type")
    return t if isinstance(t, str) else None

def version_tuple(v: str) -> Tuple[int,int,int]:
    m = re.match(r"^\s*(\d+)\.(\d+)\.(\d+)", str(v))
    if not m: return (0,0,0)
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))

def bump_kind(b0: Tuple[int,int,int], b1: Tuple[int,int,int]) -> str:
    if b1[0] > b0[0]: return "major"
    if b1[0] == b0[0] and b1[1] > b0[1]: return "minor"
    if b1 > b0: return "patch"
    if b1 == b0: return "equal"
    return "backwards"

def severity_for_removed(path: str, method: str, used: set) -> str:
    return "HIGH" if (path, method) in used else "MEDIUM"

def main(argv: List[str]) -> int:
    if len(argv) < 3:
        print("[]")
        return 0
    try:
        bfile, cfile, lfile = find_pair(argv[1:])
    except SystemExit:
        print("[]")
        return 0
    bspec = load_yaml(bfile)
    cspec = load_yaml(cfile)
    used = set()
    if lfile and lfile.exists():
        try:
            logs = json.loads(lfile.read_text(encoding="utf-8"))
            for row in logs:
                p = row.get("path"); m = row.get("method")
                if isinstance(p,str) and isinstance(m,str):
                    used.add((p, m.upper()))
        except Exception:
            used = set()
    bver = str((bspec.get("info") or {}).get("version", "0.0.0"))
    cver = str((cspec.get("info") or {}).get("version", "0.0.0"))

    bops = gather_ops(bspec)
    cops = gather_ops(cspec)

    violations: List[Dict[str, Any]] = []
    breaking = False
    additive = False

    for key in sorted(bops.keys()):
        pth, met = key
        if key not in cops:
            breaking = True
            violations.append({
                "rule":"ENDPOINT_REMOVED",
                "path": pth,
                "method": met,
                "message": "operation removed",
                "severity": severity_for_removed(pth, met, used),
                "object": {
                    "baseline_file": str(bfile),
                    "candidate_file": str(cfile),
                    "baseline_version": bver,
                    "candidate_version": cver
                }
            })
            continue
        bp, cp = params_map(bops[key]), params_map(cops[key])

        for (nm, loc), pc in cp.items():
            req_c = bool(pc.get("required"))
            if req_c:
                req_b = bool(bp.get((nm,loc), {}).get("required"))
                if not req_b:
                    breaking = True
                    violations.append({
                        "rule":"PARAM_REQUIRED_ADDED",
                        "path": pth,
                        "method": met,
                        "message": f"parameter {nm} in {loc} became required",
                        "severity": "MEDIUM",
                        "object": {
                            "baseline_file": str(bfile),
                            "candidate_file": str(cfile),
                            "baseline_version": bver,
                            "candidate_version": cver
                        }
                    })

        for (nm, loc), pb in bp.items():
            if (nm, loc) in cp:
                t0, t1 = schema_type(pb), schema_type(cp[(nm,loc)])
                if t0 and t1 and t0 != t1:
                    breaking = True
                    violations.append({
                        "rule":"PARAM_TYPE_CHANGED",
                        "path": pth,
                        "method": met,
                        "message": f"type changed for {nm} in {loc} from {t0} to {t1}",
                        "severity": "MEDIUM",
                        "object": {
                            "baseline_file": str(bfile),
                            "candidate_file": str(cfile),
                            "baseline_version": bver,
                            "candidate_version": cver
                        }
                    })

        b200 = ((bops[key].get("responses") or {}).get("200") is not None)
        c200 = ((cops[key].get("responses") or {}).get("200") is not None)
        if b200 and not c200:
            breaking = True
            violations.append({
                "rule":"RESPONSE_200_REMOVED",
                "path": pth,
                "method": met,
                "message": "success response removed",
                "severity": "MEDIUM",
                "object": {
                    "baseline_file": str(bfile),
                    "candidate_file": str(cfile),
                    "baseline_version": bver,
                    "candidate_version": cver
                }
            })

    for key in sorted(cops.keys()):
        if key not in bops:
            additive = True

    def version_tuple(v: str):
        m = re.match(r"^\s*(\d+)\.(\d+)\.(\d+)", str(v))
        return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else (0,0,0)

    def bump_kind(b0, b1):
        if b1[0] > b0[0]: return "major"
        if b1[0] == b0[0] and b1[1] > b0[1]: return "minor"
        if b1 > b0: return "patch"
        if b1 == b0: return "equal"
        return "backwards"

    bvt, cvt = version_tuple(bver), version_tuple(cver)
    expected = "patch_or_equal"
    if breaking:
        expected = "major"
    elif additive:
        expected = "minor"
    bump = bump_kind(bvt, cvt)
    mismatch = (
        (expected == "major" and bump != "major") or
        (expected == "minor" and bump != "minor") or
        (expected == "patch_or_equal" and bump not in ("patch","equal"))
    )
    if mismatch:
        violations.append({
            "rule":"SEMVER_MISMATCH",
            "path":"info.version",
            "method":"N/A",
            "message":f"expected {expected}",
            "severity":"MEDIUM",
            "object": {
                "baseline_file": str(bfile),
                "candidate_file": str(cfile),
                "baseline_version": bver,
                "candidate_version": cver
            }
        })

    violations.sort(key=lambda v: (v.get("path",""), v.get("method",""), v.get("rule","")))
    print(json.dumps(violations, ensure_ascii=False))
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
PY
chmod +x /usr/local/bin/api-change-guard
echo "patched api-change-guard"