#!/bin/bash
# Produce the final reproducibility-complete reports:
#   summary/report.md           — human-readable, with metadata footer
#   summary/analysis.json       — per-variant stats (machine-readable)
#   summary/thesis_snippet.typ  — paste-ready Typst table

set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"
mkdir -p summary
PY="${PYTHON:-python3}"

"${PY}" - <<'PY'
import csv, json, os, sys
from datetime import datetime

try:
    import numpy as np
    from scipy import stats as scipy_stats
except ImportError:
    sys.stderr.write("ERROR: numpy/scipy missing. Run 'make venv'.\n")
    sys.exit(1)

META          = "summary/metadata.json"
CSV           = "summary/combined_results.csv"
REPORT_MD     = "summary/report.md"
ANALYSIS_JSON = "summary/analysis.json"
SNIPPET_TYP   = "summary/thesis_snippet.typ"

with open(META) as f:
    meta = json.load(f)

cfg         = meta.get("config", {})
compilers   = cfg.get("compilers", ["new", "orig"])
spec_vars   = cfg.get("spec_variants", ["fullspec", "nospec"])
inline_vars = cfg.get("inline_variants", ["inline", "noinline"])
mg_classes  = cfg.get("classes", ["?"])
mg_target   = cfg.get("target", "?")

# Per-(class, spec, inline, compiler) → list of gflops values (successful runs only)
buckets = {}
with open(CSV) as f:
    for row in csv.DictReader(f):
        if row["status"] != "SUCCESS":
            continue
        key = (row["class"], row["spec"], row["inline"], row["compiler"])
        try:
            g = float(row["gflops"])
        except (ValueError, TypeError):
            continue
        buckets.setdefault(key, []).append(g)

def cell_stats(vals):
    if not vals:
        return {"n": 0, "status_label": "NO DATA"}
    a = np.array(vals, dtype=float)
    return {
        "n":    int(len(a)),
        "mean": float(a.mean()),
        "std":  float(a.std(ddof=1)) if len(a) >= 2 else 0.0,
        "min":  float(a.min()),
        "max":  float(a.max()),
        "status_label": "SUCCESS",
    }

# Build full table and t-tests per class
table = {}         # (cls, spec, inline, compiler) → stats
ttest_results = {} # (cls, spec, inline) → ttest

for cls in mg_classes:
    for s in spec_vars:
        for i in inline_vars:
            for c in compilers:
                table[(cls, s, i, c)] = cell_stats(buckets.get((cls, s, i, c), []))
            new_vals  = buckets.get((cls, s, i, "new"),  [])
            orig_vals = buckets.get((cls, s, i, "orig"), [])
            if len(new_vals) >= 2 and len(orig_vals) >= 2:
                t, p = scipy_stats.ttest_ind(new_vals, orig_vals)
                mean_new = float(np.mean(new_vals))
                mean_orig = float(np.mean(orig_vals))
                ttest_results[(cls, s, i)] = {
                    "t_stat":      float(t),
                    "p_value":     float(p),
                    "significant": bool(p < 0.05),
                    "mean_new":    mean_new,
                    "mean_orig":   mean_orig,
                    "speedup":     mean_new / mean_orig if mean_orig else None,
                    "winner":      "TIE" if p >= 0.05 else ("NEW" if mean_new > mean_orig else "ORIG"),
                }

with open(ANALYSIS_JSON, "w") as f:
    json.dump({
        "per_variant": {f"{cls}/{s}/{i}/{c}": v for (cls, s, i, c), v in table.items()},
        "ttest_new_vs_orig": {f"{cls}/{s}/{i}": v for (cls, s, i), v in ttest_results.items()},
        "config":    cfg,
        "compilers": meta.get("compilers", {}),
        "stdlib":    meta.get("stdlib", {}),
    }, f, indent=2, sort_keys=True)

# ----------------------------- Markdown report --------------------------------
hw     = meta.get("hardware", {})
slurm  = meta.get("slurm", {})
stdlib = meta.get("stdlib", {})
nodes  = hw.get("nodes_used", [])
nodes_str = ", ".join(nodes) if nodes else "?"

out = []; w = out.append
w("# MG Benchmark — Report")
w("")
w(f"_Generated: {datetime.now().isoformat(timespec='seconds')}_")
w("")
w(f"Classes: **{', '.join(mg_classes)}**  Target: **{mg_target}**  Node(s): **{nodes_str}**")
w("")

for cls in mg_classes:
    w(f"## Class {cls} — GFLOP/s by variant (new vs orig compiler)")
    w("")
    hdr = ["Spec", "Inline"] + [f"{c} mean" for c in compilers] + [f"{c} std" for c in compilers] + ["Speedup", "Significant?", "Winner"]
    w("| " + " | ".join(hdr) + " |")
    w("|" + "|".join("---" for _ in hdr) + "|")
    for s in spec_vars:
        for i in inline_vars:
            row = [s, i]
            for c in compilers:
                st = table[(cls, s, i, c)]
                row.append(f"{st['mean']:.4f}" if st["n"] else st["status_label"])
            for c in compilers:
                st = table[(cls, s, i, c)]
                row.append(f"{st['std']:.4f}" if st["n"] >= 2 else "—")
            tt = ttest_results.get((cls, s, i))
            if tt:
                row.append(f"{tt['speedup']:.4f}" if tt["speedup"] else "?")
                row.append("YES" if tt["significant"] else "NO")
                row.append(tt["winner"])
            else:
                row += ["—", "—", "—"]
            w("| " + " | ".join(row) + " |")
    w("")

    w(f"### Class {cls} — cross-comparison: nospec/new vs fullspec/orig")
    w("")
    w("| Inline | nospec/new mean | fullspec/orig mean | Speedup | p-value | Winner |")
    w("|--------|----------------|-------------------|---------|---------|--------|")
    for i in inline_vars:
        new_vals  = buckets.get((cls, "nospec",   i, "new"),  [])
        orig_vals = buckets.get((cls, "fullspec",  i, "orig"), [])
        if len(new_vals) >= 2 and len(orig_vals) >= 2:
            t, p = scipy_stats.ttest_ind(new_vals, orig_vals)
            mn = float(np.mean(new_vals)); mo = float(np.mean(orig_vals))
            sp = mn / mo if mo else float("nan")
            winner = "TIE" if p >= 0.05 else ("nospec/new" if mn > mo else "fullspec/orig")
            w(f"| {i} | {mn:.4f} | {mo:.4f} | {sp:.4f} | {p:.4f} | {winner} |")
        else:
            w(f"| {i} | — | — | — | — | — |")
    w("")

# Reproducibility footer
w("## Reproducibility metadata")
w("")
w("### SLURM")
w("")
for k, label in [("partition","Partition"), ("account","Account"),
                  ("cpus_per_task","CPUs per task"),
                  ("mem_requested","Memory requested"),
                  ("timelimit_requested","Wall-clock cap")]:
    v = slurm.get(k, "")
    if v: w(f"- {label}: `{v}`")
if nodes:
    w(f"- Node(s) used: {', '.join(f'`{n}`' for n in nodes)}")
w("")
w("### Host environment")
w("")
for k, label in [("cpu_model","CPU"), ("total_memory_kb","Total memory (kB)"),
                  ("kernel","Kernel"), ("os_release","OS"), ("gcc_version","GCC")]:
    v = hw.get(k, "")
    if v: w(f"- {label}: `{v}`")
w("")
w("### Compilers")
w("")
for c in compilers:
    ci = meta.get("compilers", {}).get(c, {})
    w(f"#### `{c}`")
    w(f"- Path: `{ci.get('sac2c_path','')}`")
    w(f"- Commit: `{ci.get('sac2c_commit','') or '(no .git)'}`")
    w(f"- Branch: `{ci.get('sac2c_branch','')}`")
    w(f"- `git describe`: `{ci.get('sac2c_describe','')}`")
    ver = (ci.get("sac2c_version_raw","") or "").replace("|"," / ")
    if ver: w(f"- `sac2c -V`: {ver}")
    w("")
w("### Stdlib")
w("")
w(f"- Path: `{stdlib.get('src_path','')}`")
w(f"- Commit: `{stdlib.get('commit','') or '(no .git)'}`")
w(f"- Branch: `{stdlib.get('branch','')}`")
w("")
w("### Benchmark configuration")
w("")
w(f"- Classes: `{' '.join(mg_classes)}`   Target: `{mg_target}`")
w(f"- Compilers: `{' '.join(compilers)}`")
w(f"- Spec variants: `{' '.join(spec_vars)}`")
w(f"- Inline variants: `{' '.join(inline_vars)}`")
w(f"- Runs per variant: `{cfg.get('runs','?')}`")
w(f"- MT cores: `{cfg.get('mt_cores','?')}`")
w(f"- Measurement: wall-clock via `date +%s.%N`; GFLOP/s from binary stdout.")
w("")
if meta.get("warnings"):
    w("### Warnings")
    w("")
    for warn in meta["warnings"]:
        w(f"- {warn}")
    w("")
w(f"_Started: {meta.get('started_at','?')} — Finished: {meta.get('finished_at','?')}_")

with open(REPORT_MD, "w") as f:
    f.write("\n".join(out))

# --------------------- Thesis-ready Typst snippet ---------------------------
# One #figure per class; rows = (spec, inline), columns = new mean, orig mean, speedup
new_commit    = (meta.get("compilers",{}).get("new",{}).get("sac2c_commit","") or "?")[:12]
orig_commit   = (meta.get("compilers",{}).get("orig",{}).get("sac2c_commit","") or "?")[:12]
stdlib_commit = (stdlib.get("commit","") or "?")[:12]
n_runs = cfg.get("runs","?")

snippet = []; sw = snippet.append
sw("// Auto-generated by CFAL-bench/MG/sac/scripts/generate_report.sh")
sw("// Paste into the thesis; update caption wording if needed.")
sw("")

for cls in mg_classes:
    sw(f"// ----- Class {cls} -----")
    sw("#figure(")
    sw("  table(")
    sw("    columns: 6,")
    sw("    align: (left, left, center, center, center, center),")
    sw("    table.header(")
    sw("      [Spec], [Inline], [New (GFLOP/s)], [Orig (GFLOP/s)], [Speedup], [p < 0.05?]")
    sw("    ),")
    for s in spec_vars:
        for i in inline_vars:
            new_st  = table[(cls, s, i, "new")]
            orig_st = table[(cls, s, i, "orig")]
            tt = ttest_results.get((cls, s, i))
            new_val  = f"{new_st['mean']:.3f}"  if new_st["n"]  else "—"
            orig_val = f"{orig_st['mean']:.3f}" if orig_st["n"] else "—"
            speedup  = f"{tt['speedup']:.3f}"   if tt and tt["speedup"] else "—"
            sig      = "YES" if tt and tt["significant"] else ("NO" if tt else "—")
            sw(f"    [{s}], [{i}], [{new_val}], [{orig_val}], [{speedup}], [{sig}],")
    sw("  ),")
    sw(f"  caption: [MG benchmark CLASS={cls}, target={mg_target} on {nodes_str}, ")
    sw(f"           N={n_runs} runs per variant. GFLOP/s = higher is better. ")
    sw(f"           Speedup = new / orig. Significance: Welch's t-test at 95 %%. ")
    sw(f"           Modified compiler commit `{new_commit}`; baseline commit `{orig_commit}`; ")
    sw(f"           Stdlib commit `{stdlib_commit}`.],")
    sw(f") <mg-gflops-table-{cls.lower()}>")
    sw("")

with open(SNIPPET_TYP, "w") as f:
    f.write("\n".join(snippet) + "\n")

print(f"wrote {REPORT_MD}")
print(f"wrote {ANALYSIS_JSON}")
print(f"wrote {SNIPPET_TYP}")
PY
