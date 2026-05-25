#!/bin/bash
#SBATCH --job-name=mg-bench
#SBATCH --output=slurm-mg-%a-%A.out
#SBATCH --error=slurm-mg-%a-%A.err
#SBATCH --time=__TIMELIMIT__
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=__CPUS__
#SBATCH --mem=__MEM__
#SBATCH --account=__ACCOUNT__
#SBATCH --partition=__PARTITION__
#SBATCH --array=0-7%__ARRAY_CONCURRENCY__
__SLURM_NODE_DIRECTIVE__

# =============================================================================
# MG Benchmark — SLURM array task
# =============================================================================
# One array job with 8 tasks, one per (spec, inline, compiler) combination:
#
#   0: fullspec / inline   / new       4: nospec / inline   / new
#   1: fullspec / inline   / orig      5: nospec / inline   / orig
#   2: fullspec / noinline / new       6: nospec / noinline / new
#   3: fullspec / noinline / orig      7: nospec / noinline / orig
#
# Each task:
#   1. Looks up its (spec, inline, compiler) from the array above.
#   2. Builds the MG binary with sac2c in a per-task scratch directory.
#   3. Runs the binary RUNS times with numactl, capturing GFLOP/s from stdout.
#   4. Writes results/<spec>-<inline>-<compiler>-<class>-<target>.json.
#
# The __PLACEHOLDERS__ below are filled by scripts/generate_jobs.sh.
# =============================================================================

set -u

# -------- placeholders filled by generate_jobs.sh ---------------------------
CLASS="__CLASS__"
TARGET="__TARGET__"
MT_CORES="__MT_CORES__"
RUNS="__RUNS__"
SAC2CFLAGS="__SAC2CFLAGS__"

SAC2C_PATH_new="__SAC2C_PATH_NEW__"
SAC2C_DIR_new="__SAC2C_DIR_NEW__"
SAC2C_SRC_new="__SAC2C_SRC_NEW__"
STDLIB_BUILD_new="__STDLIB_BUILD_NEW__"

SAC2C_PATH_orig="__SAC2C_PATH_ORIG__"
SAC2C_DIR_orig="__SAC2C_DIR_ORIG__"
SAC2C_SRC_orig="__SAC2C_SRC_ORIG__"
STDLIB_BUILD_orig="__STDLIB_BUILD_ORIG__"

STDLIB_SRC="__STDLIB_SRC__"
SLURM_MEM_REQUESTED="__MEM__"
SLURM_TIMELIMIT_REQUESTED="__TIMELIMIT__"
TEMP_ROOT_PREFERRED="__TEMP_ROOT_PREFERRED__"
TEMP_ROOT_FALLBACK="__TEMP_ROOT_FALLBACK__"

# -------- combination lookup (fixed; always 2 specs × 2 inlines × 2 compilers)
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

COMBO="${COMBOS[$SLURM_ARRAY_TASK_ID]}"
SPEC=$(echo "$COMBO" | cut -d' ' -f1)
INLINE_MODE=$(echo "$COMBO" | cut -d' ' -f2)
COMPILER=$(echo "$COMBO" | cut -d' ' -f3)

# Select compiler-specific paths via indirect variable expansion
eval "SAC2C_PATH=\$SAC2C_PATH_${COMPILER}"
eval "SAC2C_DIR=\$SAC2C_DIR_${COMPILER}"
eval "SAC2C_SRC=\$SAC2C_SRC_${COMPILER}"
eval "STDLIB_BUILD=\$STDLIB_BUILD_${COMPILER}"

# -------- per-task identifiers -----------------------------------------------
JOB_ID="${SLURM_ARRAY_JOB_ID:-${SLURM_JOB_ID}}"
TASK_ID="${SLURM_ARRAY_TASK_ID}"
NODE_NAME="$(hostname -s)"
SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$(pwd)}"
RESULT_JSON="${SUBMIT_DIR}/results/mg-${SPEC}-${INLINE_MODE}-${COMPILER}-${CLASS}-${TARGET}.json"
SOURCE_FILE="${SUBMIT_DIR}/src/MG.sac"
mkdir -p "${SUBMIT_DIR}/results"

# Accumulate per-run records here; final JSON wraps them as the "runs" array.
RUNS_TMP="$(mktemp)"
trap 'rm -f "${RUNS_TMP}"' EXIT

# -------- helper: append one run record to RUNS_TMP -------------------------
append_run () {
  python3 - "$@" >> "${RUNS_TMP}" <<'PY'
import json, sys
keys = ["run", "status", "gflops", "wall_seconds", "error_message"]
def parse(v):
    if v in ("", "null", "None"): return None
    try: return int(v)
    except ValueError: pass
    try: return float(v)
    except ValueError: pass
    return v
rec = dict(zip(keys, [parse(v) for v in sys.argv[1:]]))
sys.stdout.write(json.dumps(rec) + "\n")
PY
}

# -------- helper: emit the final per-task JSON --------------------------------
emit_json () {
  local task_status="$1"
  local task_exit="$2"
  local task_err="$3"
  local build_status="${4:-}"
  local build_time="${5:-}"
  local build_rss="${6:-}"

  python3 - >> "${RESULT_JSON}.new" <<PY
import json, os, sys

runs = []
with open("${RUNS_TMP}") as f:
    for line in f:
        line = line.strip()
        if line:
            runs.append(json.loads(line))

def numornull(v):
    return None if v in (None, "", "null") else float(v)

record = {
  "spec":          "${SPEC}",
  "inline":        "${INLINE_MODE}",
  "compiler":      "${COMPILER}",
  "class":         "${CLASS}",
  "target":        "${TARGET}",
  "mt_cores":      int("${MT_CORES}"),
  "runs_requested": int("${RUNS}"),
  "task_status":   "${task_status}",
  "task_exit_code": ${task_exit},
  "task_error_message": """${task_err}""",
  "build_status":  "${build_status}",
  "build_time_seconds": numornull("""${build_time}"""),
  "build_peak_rss_kb":  numornull("""${build_rss}"""),
  "runs": runs,
  "started_at":  os.environ.get("TASK_STARTED_AT", ""),
  "finished_at": os.environ.get("TASK_FINISHED_AT", ""),
  "job_id":       "${JOB_ID}",
  "array_task_id": ${TASK_ID},
  "node":          "${NODE_NAME}",
  "slurm_partition": os.environ.get("SLURM_JOB_PARTITION", ""),
  "slurm_cpus_per_task": int(os.environ.get("SLURM_CPUS_PER_TASK", "0") or 0),
  "slurm_mem_requested": "${SLURM_MEM_REQUESTED}",
  "slurm_timelimit_requested": "${SLURM_TIMELIMIT_REQUESTED}",
  "temp_build_root": os.environ.get("TEMP_BUILD_ROOT", ""),
  "source_file":   "${SOURCE_FILE}",
  "sac2c_path":    "${SAC2C_PATH}",
  "sac2c_version_raw": os.environ.get("SAC2C_VERSION_RAW", ""),
  "sac2c_commit":  os.environ.get("SAC2C_COMMIT", ""),
  "sac2c_branch":  os.environ.get("SAC2C_BRANCH", ""),
  "sac2c_describe": os.environ.get("SAC2C_DESCRIBE", ""),
  "stdlib_src":    "${STDLIB_SRC}",
  "stdlib_build":  "${STDLIB_BUILD}",
  "stdlib_commit": os.environ.get("STDLIB_COMMIT", ""),
  "stdlib_branch": os.environ.get("STDLIB_BRANCH", ""),
  "gcc_version":   os.environ.get("GCC_VERSION", ""),
  "kernel":        os.environ.get("KERNEL", ""),
  "os_release":    os.environ.get("OS_RELEASE", ""),
  "cpu_model":     os.environ.get("CPU_MODEL", ""),
  "total_memory_kb": int(os.environ.get("TOTAL_MEMORY_KB", "0") or 0),
}
json.dump(record, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
  mv "${RESULT_JSON}.new" "${RESULT_JSON}"
}

# Always emit a JSON on exit (even on early crash).
on_exit () {
  local code=$?
  if [[ ! -f "${RESULT_JSON}" ]]; then
    emit_json "ERROR" "${code}" "exited before result was recorded" "" "" ""
  fi
  rm -f "${RUNS_TMP}"
}
trap on_exit EXIT

echo "========================================================================"
echo "MG Benchmark — task ${SLURM_ARRAY_TASK_ID}: ${SPEC}/${INLINE_MODE}/${COMPILER}"
echo "========================================================================"
echo "Compiler   : ${COMPILER}  (${SAC2C_PATH})"
echo "Variant    : ${SPEC} / ${INLINE_MODE}"
echo "Class      : ${CLASS}   Target: ${TARGET}   Cores: ${MT_CORES}"
echo "Source     : ${SOURCE_FILE}"
echo "Stdlib     : ${STDLIB_BUILD}"
echo "Runs       : ${RUNS}"
echo "Job ID     : ${JOB_ID} (task ${TASK_ID})"
echo "Node       : ${NODE_NAME}"
echo "========================================================================"

# -------- 1. Sanity checks ---------------------------------------------------
if [[ ! -x "${SAC2C_PATH}" ]]; then
  emit_json "ERROR" 2 "sac2c binary not found or not executable: ${SAC2C_PATH}" "" "" ""
  exit 2
fi
if [[ ! -f "${SOURCE_FILE}" ]]; then
  emit_json "ERROR" 3 "source file not found: ${SOURCE_FILE}" "" "" ""
  exit 3
fi
if [[ ! -d "${STDLIB_BUILD}" ]]; then
  emit_json "ERROR" 4 "stdlib build dir missing: ${STDLIB_BUILD} — run 'make stdlibs' in param-bench first" "" "" ""
  exit 4
fi

# -------- 2. Environment metadata --------------------------------------------
export SAC2C_VERSION_RAW="$("${SAC2C_PATH}" -V 2>&1 | head -5 | tr '\n' '|' || true)"
if [[ -n "${SAC2C_SRC}" && -d "${SAC2C_SRC}/.git" ]]; then
  export SAC2C_COMMIT="$(git -C "${SAC2C_SRC}" rev-parse HEAD 2>/dev/null || echo "")"
  export SAC2C_BRANCH="$(git -C "${SAC2C_SRC}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  export SAC2C_DESCRIBE="$(git -C "${SAC2C_SRC}" describe --always --dirty --tags 2>/dev/null || echo "")"
else
  export SAC2C_COMMIT=""; export SAC2C_BRANCH=""; export SAC2C_DESCRIBE=""
fi
if [[ -d "${STDLIB_SRC}/.git" ]]; then
  export STDLIB_COMMIT="$(git -C "${STDLIB_SRC}" rev-parse HEAD 2>/dev/null || echo "")"
  export STDLIB_BRANCH="$(git -C "${STDLIB_SRC}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
else
  export STDLIB_COMMIT=""; export STDLIB_BRANCH=""
fi
export GCC_VERSION="$(gcc --version 2>/dev/null | head -1 || echo "")"
export KERNEL="$(uname -r 2>/dev/null || echo "")"
export OS_RELEASE="$( ( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}" ) || echo "")"
export CPU_MODEL="$(lscpu 2>/dev/null | awk -F: '/^Model name/ {gsub(/^ +/,"",$2); print $2; exit}')"
export TOTAL_MEMORY_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"

# -------- 3. Per-task scratch root + isolated $HOME --------------------------
choose_temp_root () {
  local pref="${TEMP_ROOT_PREFERRED:-/scratch}/${USER:-$LOGNAME}"
  if mkdir -p "${pref}" 2>/dev/null && [[ -w "${pref}" ]]; then
    echo "${pref}"; return
  fi
  echo "${TEMP_ROOT_FALLBACK:-$HOME}"
}
TEMP_ROOT="$(choose_temp_root)"
TASK_ROOT="${TEMP_ROOT}/mg_bench_${SPEC}_${INLINE_MODE}_${COMPILER}_${CLASS}_${TARGET}_${JOB_ID}_${TASK_ID}"
export HOME="${TASK_ROOT}/home"
export TMPDIR="${TASK_ROOT}/tmp"
export TEMP_BUILD_ROOT="${TEMP_ROOT}"
mkdir -p "${HOME}" "${TMPDIR}"

echo "Temp root  : ${TEMP_ROOT}"
echo "Task root  : ${TASK_ROOT}"

# -------- 4. sac2c environment in the isolated $HOME -------------------------
unset SAC2CRC SAC2C_STANDARD_PACKAGES SAC2C_INCLUDE_PATH SAC2C_LIBRARY_PATH
export SAC2CBASE="${SAC2C_DIR}"
PRELUDE_PATH="${SAC2C_DIR}/runtime_build/src/runtime_libraries-build/lib/prelude"
export LD_LIBRARY_PATH="${SAC2C_DIR}/runtime_build/src/runtime_libraries-build/lib:${PRELUDE_PATH}:${LD_LIBRARY_PATH:-}"

mkdir -p "${HOME}/.sac2crc"
cat > "${HOME}/.sac2crc/sac2crc.release.prelude" <<EOF
/* Auto-generated for ${COMPILER} compiler, task ${TASK_ID} of job ${JOB_ID} */
target add_local:
TREEPATH       += "${PRELUDE_PATH}:"
LIBPATH        += "${PRELUDE_PATH}:"

target default_sbi :: add_local:
EOF
cp "${HOME}/.sac2crc/sac2crc.release.prelude" "${HOME}/.sac2crc/sac2crc.debug.prelude"

LIBFLAGS=( -L "${PRELUDE_PATH}" -T "${PRELUDE_PATH}"
           -L "${STDLIB_BUILD}/lib" -T "${STDLIB_BUILD}/lib" )

# -------- 5. Build phase -----------------------------------------------------
BUILD_DIR="${TASK_ROOT}/build"
mkdir -p "${BUILD_DIR}"
BINARY="${BUILD_DIR}/MG_${SPEC}_${INLINE_MODE}_${CLASS}_${TARGET}_${COMPILER}"

# Derive sac2c flags for this variant
SPEC_FLAG=""
[[ "${SPEC}" == "fullspec" ]] && SPEC_FLAG="-DSPECS"
INLINE_FLAG=""
[[ "${INLINE_MODE}" == "inline" ]] && INLINE_FLAG="-DISINLINE"
case "${TARGET}" in
  seq)      TARGET_FLAG="" ;;
  mt_pth)   TARGET_FLAG="-tmt_pth" ;;
  cuda_man) TARGET_FLAG="-tcuda_man -nomemrt" ;;
  *)        TARGET_FLAG="" ;;
esac

TIME_LOG="${TASK_ROOT}/build_time.log"
BUILD_LOG="${TASK_ROOT}/build.log"

echo
echo "--- Build: numactl --interleave all sac2c ... ---"
export TASK_STARTED_AT="$(date -Iseconds)"
BUILD_START="$(date +%s.%N)"

/usr/bin/time -v -o "${TIME_LOG}" \
  numactl --interleave all \
  "${SAC2C_PATH}" "${LIBFLAGS[@]}" \
    -DCLASS_${CLASS}=1 ${SPEC_FLAG} ${INLINE_FLAG} ${TARGET_FLAG} \
    ${SAC2CFLAGS} \
    "${SOURCE_FILE}" -o "${BINARY}" \
  > "${BUILD_LOG}" 2>&1
BUILD_EXIT=$?

BUILD_END="$(date +%s.%N)"
BUILD_TIME="$(awk "BEGIN{printf \"%.6f\", ${BUILD_END} - ${BUILD_START}}")"

if [[ -f "${TIME_LOG}" ]]; then
  BUILD_RSS="$(awk -F: '/Maximum resident set size/ {gsub(/^ +/, "", $2); print $2; exit}' "${TIME_LOG}")"
else
  BUILD_RSS=""
fi

echo "Build exit : ${BUILD_EXIT}   wall: ${BUILD_TIME}s   RSS: ${BUILD_RSS:-?}kB"
tail -n 30 "${BUILD_LOG}" || true

if [[ ${BUILD_EXIT} -ne 0 ]]; then
  export TASK_FINISHED_AT="$(date -Iseconds)"
  emit_json "BUILD_FAIL" "${BUILD_EXIT}" "sac2c exited with ${BUILD_EXIT}" "FAIL" "${BUILD_TIME}" "${BUILD_RSS}"
  exit "${BUILD_EXIT}"
fi

# -------- 6. Benchmark phase -------------------------------------------------
case "${TARGET}" in
  mt_pth)   RUN_ARGS="-mt ${MT_CORES}" ;;
  cuda_man) RUN_ARGS="" ;;
  *)        RUN_ARGS="" ;;
esac

echo
echo "--- Benchmark: ${RUNS} runs ---"

for run in $(seq 1 "${RUNS}"); do
  echo
  echo "  run ${run}/${RUNS}"
  RUN_START="$(date +%s.%N)"
  # stdout = GFLOP/s float; stderr = timing/residual diagnostics
  GFLOPS_RAW="$(numactl --interleave all "${BINARY}" ${RUN_ARGS} 2>/dev/null)"
  RUN_EXIT=$?
  RUN_END="$(date +%s.%N)"
  RUN_WALL="$(awk "BEGIN{printf \"%.6f\", ${RUN_END} - ${RUN_START}}")"

  if [[ ${RUN_EXIT} -ne 0 || -z "${GFLOPS_RAW}" ]]; then
    echo "  ERROR exit=${RUN_EXIT} output='${GFLOPS_RAW}'"
    append_run "${run}" "ERROR" "" "${RUN_WALL}" "binary exited with ${RUN_EXIT}"
  else
    GFLOPS="$(echo "${GFLOPS_RAW}" | tr -d '[:space:]')"
    printf "  gflops=%s  wall=%ss\n" "${GFLOPS}" "${RUN_WALL}"
    append_run "${run}" "SUCCESS" "${GFLOPS}" "${RUN_WALL}" ""
  fi
done

export TASK_FINISHED_AT="$(date -Iseconds)"

# -------- 7. Emit final record -----------------------------------------------
emit_json "SUCCESS" 0 "" "SUCCESS" "${BUILD_TIME}" "${BUILD_RSS}"

echo
echo "========================================================================"
echo "Task complete: ${SPEC}/${INLINE_MODE}/${COMPILER}  →  ${RESULT_JSON}"
echo "========================================================================"

cd /
rm -rf "${TASK_ROOT}"
exit 0
