# MG Benchmark — configuration
# Edit and then run `make` (= `make run`) for an end-to-end rerun.

# =============================================================================
# Compiler paths (on the SLURM compute nodes)
# =============================================================================
SAC2C_NEW_SLURM       := /home/rhensen/sac2c/build_p/sac2c_p
SAC2C_ORIG_SLURM      := /home/rhensen/sacoriginal/sac2c/build_p/sac2c_p
SAC2C_NEW_DIR_SLURM   := /home/rhensen/sac2c/build_p
SAC2C_ORIG_DIR_SLURM  := /home/rhensen/sacoriginal/sac2c/build_p

# Source-tree paths for the compiler repos (for git-commit metadata)
SAC2C_NEW_SRC_SLURM   := /home/rhensen/sac2c
SAC2C_ORIG_SRC_SLURM  := /home/rhensen/sacoriginal/sac2c

# =============================================================================
# Stdlib paths
# =============================================================================
# The Stdlib is the same source clone, but cmake build trees must be separate
# per compiler. If you used param-bench's `make stdlibs`, they are already at
# build-new / build-orig under the same Stdlib source tree.
STDLIB_SRC_SLURM      := /home/rhensen/Stdlib
STDLIB_BUILD_NEW      := $(STDLIB_SRC_SLURM)/build-new
STDLIB_BUILD_ORIG     := $(STDLIB_SRC_SLURM)/build-orig

# =============================================================================
# Benchmark parameters
# =============================================================================
COMPILERS             := new orig
SPEC_VARIANTS         := fullspec nospec
INLINE_VARIANTS       := inline noinline

# CLASSES: space-separated list of NAS classes to run in one submission
CLASSES               := A B C
# TARGET: seq mt_pth cuda_man
TARGET                := mt_pth
MT_CORES              := 32
RUNS                  := 20

# sac2c flags (no -mt_bind; numactl --interleave is handled by the job script)
SAC2CFLAGS            := -maxwlur 27 -v0 -noSOP -noSRP -maxoptcyc 30 -maxspec 100

# How many times to resubmit tasks whose JSON record is missing or failed.
MAX_RETRIES           := 2

# =============================================================================
# SLURM configuration
# =============================================================================
SLURM_ACCOUNT         := csmpi
# Use csmpi_fpga_long for 32-core jobs (cncz nodes only have 4–8 cores).
SLURM_PARTITION       := csmpi_fpga_long
SLURM_CPUS            := 32
SLURM_MEM             := 60G
# Wall clock per task: build (~5 min sac2c) + 20 benchmark runs (~10 min).
SLURM_TIMELIMIT       := 00:30:00

# Cap concurrent array tasks. Empty = no cap.
SLURM_ARRAY_CONCURRENCY := 4

# Restrict which compute node(s) the benchmark runs on. Mixing CPU generations
# produces noise that swamps the signal — pin to one node for validity.
#
# Use EXACTLY ONE of:
#   SLURM_NODELIST := cn99    # pin to one specific node — best for validity
#   SLURM_EXCLUDE  := cn58    # exclude known-slow nodes — keeps parallelism
# Leave both empty to let SLURM decide (NOT recommended for benchmark runs).
SLURM_NODELIST        := cn99
SLURM_EXCLUDE         :=

# Per-task scratch root for builds + isolated $HOME (avoids ~/.sac2crc race).
TEMP_ROOT_PREFERRED   := /scratch
TEMP_ROOT_FALLBACK    := $$HOME

# =============================================================================
# Analysis configuration
# =============================================================================
VENV_DIR := venv
PYTHON   := $(VENV_DIR)/bin/python3
