#!/bin/bash
# Generate the SLURM array script jobs/mg.array.sh from job_template.sh.
#
# All parameters come from env vars exported by the Makefile (from config.mk).

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p jobs

NUM_CLASSES=$(echo ${CLASSES} | wc -w | tr -d ' ')
NUM_COMBOS=$(( NUM_CLASSES * 8 ))   # 8 = 2 specs × 2 inlines × 2 compilers
ARRAY_MAX=$(( NUM_COMBOS - 1 ))
ARRAY_SPEC="0-${ARRAY_MAX}"
if [[ -n "${SLURM_ARRAY_CONCURRENCY:-}" ]]; then
  ARRAY_SPEC="${ARRAY_SPEC}%${SLURM_ARRAY_CONCURRENCY}"
fi

# Node constraint: SLURM_NODELIST wins (pin), then SLURM_EXCLUDE, then nothing.
if [[ -n "${SLURM_NODELIST:-}" ]]; then
  NODE_DIRECTIVE="#SBATCH --nodelist=${SLURM_NODELIST}"
  echo "constraining tasks to node(s): ${SLURM_NODELIST}"
elif [[ -n "${SLURM_EXCLUDE:-}" ]]; then
  NODE_DIRECTIVE="#SBATCH --exclude=${SLURM_EXCLUDE}"
  echo "excluding node(s): ${SLURM_EXCLUDE}"
else
  NODE_DIRECTIVE="# (no node constraint — SLURM may pick any node in the partition)"
  echo "WARNING: no node constraint set; mixing CPU generations will add noise"
fi

OUT="jobs/mg.array.sh"

sed \
  -e "s|__CLASSES__|${CLASSES}|g" \
  -e "s|__ARRAY_SPEC__|${ARRAY_SPEC}|g" \
  -e "s|__TARGET__|${TARGET}|g" \
  -e "s|__MT_CORES__|${MT_CORES}|g" \
  -e "s|__RUNS__|${RUNS}|g" \
  -e "s|__SAC2CFLAGS__|${SAC2CFLAGS}|g" \
  -e "s|__SAC2C_PATH_NEW__|${SAC2C_NEW_SLURM}|g" \
  -e "s|__SAC2C_DIR_NEW__|${SAC2C_NEW_DIR_SLURM}|g" \
  -e "s|__SAC2C_SRC_NEW__|${SAC2C_NEW_SRC_SLURM}|g" \
  -e "s|__STDLIB_BUILD_NEW__|${STDLIB_BUILD_NEW}|g" \
  -e "s|__SAC2C_PATH_ORIG__|${SAC2C_ORIG_SLURM}|g" \
  -e "s|__SAC2C_DIR_ORIG__|${SAC2C_ORIG_DIR_SLURM}|g" \
  -e "s|__SAC2C_SRC_ORIG__|${SAC2C_ORIG_SRC_SLURM}|g" \
  -e "s|__STDLIB_BUILD_ORIG__|${STDLIB_BUILD_ORIG}|g" \
  -e "s|__STDLIB_SRC__|${STDLIB_SRC_SLURM}|g" \
  -e "s|__TIMELIMIT__|${SLURM_TIMELIMIT}|g" \
  -e "s|__CPUS__|${SLURM_CPUS}|g" \
  -e "s|__MEM__|${SLURM_MEM}|g" \
  -e "s|__ACCOUNT__|${SLURM_ACCOUNT}|g" \
  -e "s|__PARTITION__|${SLURM_PARTITION}|g" \
  -e "s|__SLURM_NODE_DIRECTIVE__|${NODE_DIRECTIVE}|g" \
  -e "s|__TEMP_ROOT_PREFERRED__|${TEMP_ROOT_PREFERRED:-/scratch}|g" \
  -e "s|__TEMP_ROOT_FALLBACK__|${TEMP_ROOT_FALLBACK:-\$HOME}|g" \
  job_template.sh > "${OUT}"

chmod +x "${OUT}"
echo "wrote ${OUT}  (array ${ARRAY_SPEC}, classes=${CLASSES}, target=${TARGET})"
echo
echo "Done. Submit with: make submit  (or 'make run' for one-command end-to-end)"
