#!/bin/bash
# Umbrella script: generate → submit → wait → retry (×MAX_RETRIES) → collect → report.
# Invoked by `make run`.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

MAX_RETRIES="${MAX_RETRIES:-2}"

echo "========================================================================"
echo "MG Benchmark — full run  (classes=${CLASSES}, target=${TARGET})"
echo "========================================================================"

echo
echo "--- [1/6] Generating job scripts ---"
bash "${SCRIPT_DIR}/generate_jobs.sh"

echo
echo "--- [2/6] Submitting jobs ---"
bash "${SCRIPT_DIR}/submit_all.sh"

echo
echo "--- [3/6] Waiting for jobs to finish ---"
bash "${SCRIPT_DIR}/wait_jobs.sh"

echo
echo "--- [4/6] Retrying failed tasks (up to ${MAX_RETRIES} rounds) ---"
for round in $(seq 1 "${MAX_RETRIES}"); do
  # Check if anything still needs to run
  NEED_RETRY=0
  bash "${SCRIPT_DIR}/retry_failed.sh" 2>&1 | tee /tmp/retry_out_$$.txt || true
  if grep -q "nothing to retry" /tmp/retry_out_$$.txt 2>/dev/null; then
    rm -f /tmp/retry_out_$$.txt
    break
  fi
  rm -f /tmp/retry_out_$$.txt
  # Wait for the new jobs
  echo "  waiting for retry round ${round} ..."
  bash "${SCRIPT_DIR}/wait_jobs.sh"
done

echo
echo "--- [5/6] Collecting results ---"
bash "${SCRIPT_DIR}/collect_results.sh"

echo
echo "--- [6/6] Generating report ---"
bash "${SCRIPT_DIR}/generate_report.sh"

echo
echo "========================================================================"
echo "Done. Outputs in summary/:"
echo "  report.md          — human-readable results"
echo "  thesis_snippet.typ — paste-ready Typst figure"
echo "  analysis.json      — machine-readable stats"
echo "  metadata.json      — reproducibility footer"
echo "========================================================================"
