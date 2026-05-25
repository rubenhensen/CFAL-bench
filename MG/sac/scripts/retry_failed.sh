#!/bin/bash
# Resubmit array tasks whose JSON is missing or has task_status != SUCCESS.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

CLASS="${CLASS:-?}"
TARGET="${TARGET:-?}"

COMBOS=(
  "fullspec inline new"
  "fullspec inline orig"
  "fullspec noinline new"
  "fullspec noinline orig"
  "nospec inline new"
  "nospec inline orig"
  "nospec noinline new"
  "nospec noinline orig"
)

FAILED_INDICES=()
for idx in "${!COMBOS[@]}"; do
  combo="${COMBOS[$idx]}"
  spec=$(echo "$combo" | cut -d' ' -f1)
  inl=$(echo "$combo"  | cut -d' ' -f2)
  comp=$(echo "$combo" | cut -d' ' -f3)
  json="results/mg-${spec}-${inl}-${comp}-${CLASS}-${TARGET}.json"

  if [[ ! -f "${json}" ]]; then
    echo "  MISSING: ${json}"
    FAILED_INDICES+=("${idx}")
  else
    status="$(python3 -c "import json; d=json.load(open('${json}')); print(d.get('task_status','?'))" 2>/dev/null || echo "PARSE_ERROR")"
    if [[ "${status}" != "SUCCESS" ]]; then
      echo "  FAILED (${status}): ${json}"
      FAILED_INDICES+=("${idx}")
    fi
  fi
done

if [[ ${#FAILED_INDICES[@]} -eq 0 ]]; then
  echo "No failed or missing tasks — nothing to retry."
  exit 0
fi

ARRAY_SPEC="$(IFS=','; echo "${FAILED_INDICES[*]}")"
echo "Resubmitting array tasks: ${ARRAY_SPEC}"

NEW_JOB_ID="$(sbatch --parsable --array="${ARRAY_SPEC}" jobs/mg.array.sh)"
echo "  new job ID: ${NEW_JOB_ID}"

echo "${NEW_JOB_ID}" >> job_ids.txt
echo "Appended job ID to job_ids.txt"
