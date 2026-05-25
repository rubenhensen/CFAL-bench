#!/bin/bash
# Print per-variant status: which result JSONs exist and what task_status they report.

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

printf "%-5s  %-5s  %-9s  %-9s  %-6s  %s\n" "IDX" "CLASS" "SPEC" "INLINE" "COMP" "STATUS / FILE"
printf '%s\n' "-----  -----  ---------  ---------  ------  ----------------------------------------"

ok=0; fail=0; missing=0
for idx in "${!COMBOS[@]}"; do
  combo="${COMBOS[$idx]}"
  cls=$(echo "$combo"  | cut -d' ' -f1)
  spec=$(echo "$combo" | cut -d' ' -f2)
  inl=$(echo "$combo"  | cut -d' ' -f3)
  comp=$(echo "$combo" | cut -d' ' -f4)
  json="results/mg-${spec}-${inl}-${comp}-${cls}-${TARGET}.json"

  if [[ -f "${json}" ]]; then
    status="$(python3 -c "import json; d=json.load(open('${json}')); print(d.get('task_status','?'))" 2>/dev/null || echo "PARSE_ERROR")"
    if [[ "${status}" == "SUCCESS" ]]; then
      runs="$(python3 -c "import json; d=json.load(open('${json}')); print(len([r for r in d.get('runs',[]) if r.get('status')=='SUCCESS']))" 2>/dev/null || echo "?")"
      printf "%-5s  %-5s  %-9s  %-9s  %-6s  %s (%s successful runs)\n" "${idx}" "${cls}" "${spec}" "${inl}" "${comp}" "${status}" "${runs}"
      ok=$((ok+1))
    else
      printf "%-5s  %-5s  %-9s  %-9s  %-6s  %s\n" "${idx}" "${cls}" "${spec}" "${inl}" "${comp}" "${status}"
      fail=$((fail+1))
    fi
  else
    printf "%-5s  %-5s  %-9s  %-9s  %-6s  MISSING  (%s)\n" "${idx}" "${cls}" "${spec}" "${inl}" "${comp}" "${json}"
    missing=$((missing+1))
  fi
done

echo
echo "Summary: ${ok} SUCCESS, ${fail} FAILED, ${missing} MISSING  (classes=${CLASSES}, target=${TARGET})"
