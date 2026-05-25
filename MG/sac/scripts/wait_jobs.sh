#!/bin/bash
# Poll squeue every 30 s until all submitted jobs are in a terminal state.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

if [[ ! -f job_ids.txt ]]; then
  echo "No job_ids.txt found — nothing to wait for."
  exit 0
fi

JOBS="$(cat job_ids.txt | tr '\n' ',' | sed 's/,$//')"
if [[ -z "${JOBS}" ]]; then
  echo "job_ids.txt is empty — nothing to wait for."
  exit 0
fi

echo "Waiting for job(s): ${JOBS}"

while true; do
  PENDING="$(squeue -j "${JOBS}" -h 2>/dev/null | wc -l || echo 0)"
  if [[ "${PENDING}" -eq 0 ]]; then
    echo "All jobs complete."
    break
  fi
  echo "  $(date -Iseconds)  ${PENDING} task(s) still running/pending ..."
  sleep 30
done
