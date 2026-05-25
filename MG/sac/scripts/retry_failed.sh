#!/bin/bash
# Resubmit array tasks whose JSON is missing or has task_status != SUCCESS.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

CLASSES="${CLASSES:-?}"
TARGET="${TARGET:-?}"

# Build combo list in the same order as job_template.sh
COMBOS=()
for cls in ${CLASSES}; do
  for spec in fullspec nospec; do
    for inl in inline noinline; do
      for comp in new orig; do
        COMBOS+=("${cls} ${spec} ${inl} ${comp}")
      done
    done
  done
done

FAILED_INDICES=()
for idx in "${!COMBOS[@]}"; do
  combo="${COMBOS[$idx]}"
  cls=$(echo "$combo"  | cut -d' ' -f1)
  spec=$(echo "$combo" | cut -d' ' -f2)
  inl=$(echo "$combo"  | cut -d' ' -f3)
  comp=$(echo "$combo" | cut -d' ' -f4)
  json="results/mg-${spec}-${inl}-${comp}-${cls}-${TARGET}.json"

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
