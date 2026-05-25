#!/bin/bash
# Submit jobs/mg.array.sh and save the job ID to job_ids.txt.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

if [[ ! -f jobs/mg.array.sh ]]; then
  echo "ERROR: jobs/mg.array.sh not found — run 'make jobs' first." >&2
  exit 1
fi

echo "Submitting jobs/mg.array.sh ..."
JOB_ID="$(sbatch --parsable jobs/mg.array.sh)"
echo "  job ID: ${JOB_ID}"

echo "${JOB_ID}" > job_ids.txt
echo "Job IDs written to job_ids.txt"
