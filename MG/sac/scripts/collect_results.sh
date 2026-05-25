#!/bin/bash
# Aggregate per-task JSONs into combined CSV + batch metadata.
#
# Outputs:
#   summary/combined_results.csv   (one row per individual benchmark run)
#   summary/all_runs.json          (full per-task records)
#   summary/metadata.json          (batch-level reproducibility footer)

set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p summary
PY="${PYTHON:-python3}"

"${PY}" - <<'PY'
import csv, glob, json, os, sys
from collections import defaultdict, Counter

compilers      = os.environ.get("COMPILERS", "new orig").split()
spec_variants  = os.environ.get("SPEC_VARIANTS", "fullspec nospec").split()
inline_variants = os.environ.get("INLINE_VARIANTS", "inline noinline").split()
mg_class       = os.environ.get("CLASS", "?")
mg_target      = os.environ.get("TARGET", "?")

records = []
for path in sorted(glob.glob("results/mg-*.json")):
    try:
        with open(path) as f:
            records.append(json.load(f))
    except Exception as e:
        print(f"WARN: could not parse {path}: {e}", file=sys.stderr)

# Slim CSV — one row per individual benchmark run
csv_cols = ["spec", "inline", "compiler", "class", "target",
            "run", "status", "gflops", "wall_seconds",
            "build_status", "build_time_seconds", "build_peak_rss_kb",
            "job_id", "array_task_id", "node",
            "started_at", "finished_at", "error_message"]
with open("summary/combined_results.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(csv_cols)
    for rec in records:
        for r in rec.get("runs", []):
            w.writerow([
                rec.get("spec", ""),
                rec.get("inline", ""),
                rec.get("compiler", ""),
                rec.get("class", ""),
                rec.get("target", ""),
                r.get("run", ""),
                r.get("status", ""),
                r.get("gflops", ""),
                r.get("wall_seconds", ""),
                rec.get("build_status", ""),
                rec.get("build_time_seconds", ""),
                rec.get("build_peak_rss_kb", ""),
                rec.get("job_id", ""),
                rec.get("array_task_id", ""),
                rec.get("node", ""),
                rec.get("started_at", ""),
                rec.get("finished_at", ""),
                r.get("error_message", ""),
            ])

with open("summary/all_runs.json", "w") as f:
    json.dump(records, f, indent=2, sort_keys=True)

# Batch-level metadata
def first_nonempty(vs):
    for v in vs:
        if v: return v
    return ""

batch = {
    "config": {
        "compilers": compilers,
        "spec_variants": spec_variants,
        "inline_variants": inline_variants,
        "class": mg_class,
        "target": mg_target,
        "runs": int(os.environ.get("RUNS", "0")),
        "mt_cores": int(os.environ.get("MT_CORES", "0")),
    },
    "slurm": {
        "partition":         os.environ.get("SLURM_PARTITION", ""),
        "account":           os.environ.get("SLURM_ACCOUNT", ""),
        "cpus_per_task":     os.environ.get("SLURM_CPUS", ""),
        "mem_requested":     os.environ.get("SLURM_MEM", ""),
        "timelimit_requested": os.environ.get("SLURM_TIMELIMIT", ""),
    },
    "hardware": {},
    "compilers": {},
    "stdlib": {},
    "totals": {},
    "warnings": [],
}

if records:
    def field(name):
        seen = []
        for r in records:
            v = r.get(name, "")
            if v and v not in seen:
                seen.append(v)
        return seen

    for h in ["cpu_model", "total_memory_kb", "kernel", "os_release", "gcc_version"]:
        vs = field(h)
        if not vs:
            continue
        batch["hardware"][h] = vs[0]
        if len(vs) > 1:
            batch["warnings"].append(f"hardware.{h} varied across tasks: {vs}")

    nodes = sorted({r.get("node", "") for r in records if r.get("node")})
    batch["hardware"]["nodes_used"] = nodes
    if len(nodes) > 1:
        batch["warnings"].append(f"runs landed on multiple nodes: {nodes}")

    for c in compilers:
        rs = [r for r in records if r.get("compiler") == c]
        if not rs:
            continue
        batch["compilers"][c] = {
            "sac2c_path":        first_nonempty([r.get("sac2c_path", "") for r in rs]),
            "sac2c_version_raw": first_nonempty([r.get("sac2c_version_raw", "") for r in rs]),
            "sac2c_commit":      first_nonempty([r.get("sac2c_commit", "") for r in rs]),
            "sac2c_branch":      first_nonempty([r.get("sac2c_branch", "") for r in rs]),
            "sac2c_describe":    first_nonempty([r.get("sac2c_describe", "") for r in rs]),
            "stdlib_build":      first_nonempty([r.get("stdlib_build", "") for r in rs]),
        }

    batch["stdlib"] = {
        "src_path": first_nonempty([r.get("stdlib_src", "") for r in records]),
        "commit":   first_nonempty([r.get("stdlib_commit", "") for r in records]),
        "branch":   first_nonempty([r.get("stdlib_branch", "") for r in records]),
    }

    task_counts = Counter(r.get("task_status", "?") for r in records)
    per_compiler = defaultdict(Counter)
    for r in records:
        per_compiler[r.get("compiler", "?")][r.get("task_status", "?")] += 1
    batch["totals"] = {
        "task_records": len(records),
        "by_task_status": dict(task_counts),
        "by_compiler": {c: dict(v) for c, v in per_compiler.items()},
    }

    starts = [r.get("started_at", "") for r in records if r.get("started_at")]
    ends   = [r.get("finished_at", "") for r in records if r.get("finished_at")]
    if starts: batch["started_at"]  = min(starts)
    if ends:   batch["finished_at"] = max(ends)

with open("summary/metadata.json", "w") as f:
    json.dump(batch, f, indent=2, sort_keys=True)

total_runs = sum(len(r.get("runs", [])) for r in records)
print(f"collected {len(records)} task record(s) ({total_runs} individual benchmark runs)")
print("  -> summary/combined_results.csv")
print("  -> summary/all_runs.json")
print("  -> summary/metadata.json")

if records:
    print()
    print("Per-compiler outcome (task-level):")
    for c in compilers:
        cs = per_compiler.get(c, Counter())
        print(f"  {c}: {dict(cs)}")

if batch["warnings"]:
    print()
    print("Warnings:")
    for w in batch["warnings"]:
        print(f"  WARNING: {w}")
PY
