
# MG Benchmark Makefile
# Builds and benchmarks MG with all combinations of:
#   - 2 compilers: new, orig
#   - 2 specialization modes: fullspec (-DSPECS), nospec
#   - 2 inlining modes: inline (-DISINLINE), noinline
#   - 3 build targets: seq, mt_pth, cuda_man
#
# Statistical analysis:
#   - Performs Student's t-test comparing new vs orig compiler (95% confidence)
#   - Outputs: T-statistic, p-value, significance, means, speedup, winner (TIE if not significant)
#   - Requires: make venv (sets up Python with scipy/numpy)

# Configuration
COMPILERS := new orig
SAC2C_new := /home/ruben/Repos/sac2c/build_p/sac2c_p
SAC2C_orig := /home/ruben/Repos/sacoriginal/sac2c/build_p/sac2c_p
# Library paths for each compiler
LIBFLAGS_new := -L /home/ruben/Repos/sac2c/build_p/lib -T /home/ruben/Repos/sac2c/build_p/tree
LIBFLAGS_orig := -L /home/ruben/Repos/sacoriginal/sac2c/build_p/lib -T /home/ruben/Repos/sacoriginal/sac2c/build_p/tree
SPEC_VARIANTS := fullspec nospec
INLINE_VARIANTS := inline noinline
VARIANT_COMBINATIONS := $(foreach s,$(SPEC_VARIANTS),$(foreach i,$(INLINE_VARIANTS),$s_$i))

# SLURM Configuration (set SLURM_ENABLE=1 to enable)
SLURM_CPUS ?= 32
SLURM_MEM ?= 60G
SLURM_ACCOUNT ?= csmpi
SLURM_PARTITION ?= csmpi_fpga_long
SLURM_GPU ?= 0 #nvidia_a30:1
SLURM_TIMELIMIT ?= 00:20:00

# SLURM-specific compilers and library paths (can use numactl on cluster)
SAC2C_new_slurm := numactl --interleave all /home/rhensen/sac2c/build_p/sac2c_p
SAC2C_orig_slurm := numactl --interleave all /home/rhensen/sacoriginal/sac2c/build_p/sac2c_p
LIBFLAGS_new_slurm := -L /home/rhensen/sac2c/build_p/lib -T /home/rhensen/sac2c/build_p/tree
LIBFLAGS_orig_slurm := -L /home/rhensen/sacoriginal/sac2c/build_p/lib -T /home/rhensen/sacoriginal/sac2c/build_p/tree

# Select compilers and execution wrapper based on SLURM mode
ifdef SLURM_ENABLE
  SAC2C_new := $(SAC2C_new_slurm)
  SAC2C_orig := $(SAC2C_orig_slurm)
  LIBFLAGS_new := $(LIBFLAGS_new_slurm)
  LIBFLAGS_orig := $(LIBFLAGS_orig_slurm)
  SAC2CFLAGS := $(SAC2CFLAGS_slurm)
  # SLURM output directory
  SLURM_LOGS := slurm_logs
  # Build sbatch command with SLURM options
  SBATCH_BASE := sbatch --parsable --cpus-per-task=$(SLURM_CPUS) --mem=$(SLURM_MEM) --partition=$(SLURM_PARTITION) --time=$(SLURM_TIMELIMIT)
  ifneq ($(SLURM_GPU),)
    SBATCH_BASE += --gres=gpu:$(SLURM_GPU)
  endif
  ifneq ($(SLURM_ACCOUNT),)
    SBATCH_BASE += --account=$(SLURM_ACCOUNT)
  endif
else
  SLURM_LOGS :=
endif

# Build settings
TARGET ?= mt_pth
MT_CORES ?= 32
CLASS ?= S
RUNS := 20
SOURCE := src/MG.sac
SAC2CFLAGS := -maxwlur 27 -v0 -noSOP -noSRP -maxoptcyc 30 -maxspec 100
SAC2CFLAGS_slurm ?= $(SAC2CFLAGS) -mt_bind NUMA
PYTHON := venv/bin/python3

# Create sanitized flag string for filenames (remove - and spaces)
empty :=
space := $(empty) $(empty)
FLAGS_HASH := $(subst $(space),_,$(subst -,,$(SAC2CFLAGS)))

# Target-specific flags
TARGET_FLAG_seq :=
TARGET_FLAG_mt_pth := -tmt_pth
TARGET_FLAG_cuda_man := -tcuda_man -nomemrt
TARGET_RUNTIME_seq :=
TARGET_RUNTIME_mt_pth := -mt $(MT_CORES)
TARGET_RUNTIME_cuda_man :=

all: build

# Setup Python virtual environment for statistical analysis
venv: venv/bin/activate

venv/bin/activate:
	python3 -m venv venv
	venv/bin/pip install scipy numpy
	@echo "Virtual environment created. Run 'make benchmark' to use it."

S A B C D:
	@$(MAKE) CLASS=$@ benchmark

build: build_new build_orig

# Run benchmarks - only if .raw files don't exist
benchmark: benchmark_new benchmark_orig comparison

benchmark_new: out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_new.csv

benchmark_orig: out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_orig.csv

# Comparison target - generates comparison file (depends on .raw files)
comparison: out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv
	@cat out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv

# Wait for all SLURM jobs to complete
sync:
ifdef SLURM_ENABLE
	@echo "=== Waiting for all SLURM jobs to complete ==="
	@for jobfile in out/*.raw.jobid; do \
		if [ -f "$$jobfile" ]; then \
			jobid=$$(cat "$$jobfile"); \
			echo "Waiting for job $$jobid..."; \
			while scontrol show job $$jobid 2>/dev/null | grep -q "JobState=PENDING\|JobState=RUNNING"; do \
				sleep 5; \
			done; \
		fi; \
	done
	@echo "All jobs completed"
endif

# Comparison file target - only regenerates if .raw files are newer
out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv: $(foreach v,$(VARIANT_COMBINATIONS),out/MG_$(v)_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_new.raw out/MG_$(v)_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_orig.raw) sync
	@echo "=== Running statistical comparison (95% confidence) ==="
	@printf 'Variant,T-statistic,P-value,Significant(95%%),Mean_new(GFLOP/s),Mean_orig(GFLOP/s),Speedup,Winner\n' > out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv
	@for v in $(VARIANT_COMBINATIONS); do \
		$(PYTHON) -c "import scipy.stats as stats; import numpy as np; \
		new = np.loadtxt('out/MG_$${v}_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_new.raw'); \
		orig = np.loadtxt('out/MG_$${v}_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_orig.raw'); \
		t_stat, p_val = stats.ttest_ind(new, orig); \
		sig = 'YES' if p_val < 0.05 else 'NO'; \
		speedup = new.mean() / orig.mean(); \
		winner = 'TIE' if p_val >= 0.05 else ('NEW' if new.mean() > orig.mean() else 'ORIG'); \
		print(f'$$v,{t_stat:.4f},{p_val:.6f},{sig},{new.mean():.6f},{orig.mean():.6f},{speedup:.4f},{winner}')" >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv || echo "$$v,ERROR,,,,,," >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv; \
	done
	@echo ""
	@echo "=== Cross-comparison: nospec_new vs fullspec_orig ==="
	@printf '\nCross-comparison: nospec_new vs fullspec_orig\n' >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv
	@printf 'Variant,T-statistic,P-value,Significant(95%%),Mean_nospec_new(GFLOP/s),Mean_fullspec_orig(GFLOP/s),Speedup,Winner\n' >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv
	@for inline_v in inline noinline; do \
		$(PYTHON) -c "import scipy.stats as stats; import numpy as np; \
		new = np.loadtxt('out/MG_nospec_$${inline_v}_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_new.raw'); \
		orig = np.loadtxt('out/MG_fullspec_$${inline_v}_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_orig.raw'); \
		t_stat, p_val = stats.ttest_ind(new, orig); \
		sig = 'YES' if p_val < 0.05 else 'NO'; \
		speedup = new.mean() / orig.mean(); \
		winner = 'TIE' if p_val >= 0.05 else ('NEW' if new.mean() > orig.mean() else 'ORIG'); \
		print(f'$${inline_v},{t_stat:.4f},{p_val:.6f},{sig},{new.mean():.6f},{orig.mean():.6f},{speedup:.4f},{winner}')" >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv || echo "$${inline_v},ERROR,,,,,," >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv; \
	done
	@echo ""
	@echo "=== Inline vs Noinline comparison (same compiler/spec) ==="
	@printf '\nInline vs Noinline comparison (same compiler/spec)\n' >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv
	@printf 'Compiler_Spec,T-statistic,P-value,Significant(95%%),Mean_inline(GFLOP/s),Mean_noinline(GFLOP/s),Speedup,Winner\n' >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv
	@for c in $(COMPILERS); do \
		for s in $(SPEC_VARIANTS); do \
			$(PYTHON) -c "import scipy.stats as stats; import numpy as np; \
			inline = np.loadtxt('out/MG_$${s}_inline_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_$${c}.raw'); \
			noinline = np.loadtxt('out/MG_$${s}_noinline_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_$${c}.raw'); \
			t_stat, p_val = stats.ttest_ind(inline, noinline); \
			sig = 'YES' if p_val < 0.05 else 'NO'; \
			speedup = inline.mean() / noinline.mean(); \
			winner = 'TIE' if p_val >= 0.05 else ('INLINE' if inline.mean() > noinline.mean() else 'NOINLINE'); \
			print(f'$${c}_$${s},{t_stat:.4f},{p_val:.6f},{sig},{inline.mean():.6f},{noinline.mean():.6f},{speedup:.4f},{winner}')" >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv || echo "$${c}_$${s},ERROR,,,,,," >> out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv; \
		done; \
	done
	@echo "Comparison saved to out/MG_$(CLASS)_$(TARGET)_$(FLAGS_HASH)_comparison.csv"

# Generate CSV from raw files for each compiler
define BENCHMARK_CSV_template
out/MG_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(1).csv: $$(foreach v,$$(VARIANT_COMBINATIONS),out/MG_$$v_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(1).raw) sync
	@echo "=== Generating CSV for $(1) compiler ==="
	@mkdir -p out
	@printf 'Binary,Class,Type,Mean,StdDev\n' > $$@
	@for v in $$(VARIANT_COMBINATIONS); do \
		printf 'sac2c_$(1)_'$$$$v',$$(CLASS),$$(TARGET),' >> $$@; \
		cat out/MG_$$$${v}_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(1).raw | variance >> $$@; \
	done
endef

$(foreach c,$(COMPILERS),$(eval $(call BENCHMARK_CSV_template,$(c))))

# Run actual benchmarks to generate .raw files
define RAW_template
out/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3).raw: bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3)
	@echo "=== Running benchmark: $(1)_$(2) with $(3) compiler ==="
	@mkdir -p out
ifdef SLURM_ENABLE
	@mkdir -p $$(SLURM_LOGS)
	@if [ -f bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3).jobid ]; then \
		BUILD_JOB=$$$$(cat bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3).jobid); \
		echo "Submitting benchmark with dependency on build job $$$$BUILD_JOB..."; \
		$$(SBATCH_BASE) --dependency=afterok:$$$$BUILD_JOB --kill-on-invalid-dep=yes --output=$$@ --error=$$(SLURM_LOGS)/bench_$(1)_$(2)_$(3)_%j.err --wrap "echo 'Running benchmark: bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3) $$(TARGET_RUNTIME_$$(TARGET)) ($$(RUNS) runs)' && for i in \$$$$(seq 1 $$(RUNS)); do bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3) $$(TARGET_RUNTIME_$$(TARGET)); done" > $$@.jobid; \
		echo "Benchmark job ID: $$$$(cat $$@.jobid) submitted"; \
	else \
		echo "Binary exists but no build job ID found - submitting benchmark without dependency..."; \
		$$(SBATCH_BASE) --output=$$@ --error=$$(SLURM_LOGS)/bench_$(1)_$(2)_$(3)_%j.err --wrap "echo 'Running benchmark: bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3) $$(TARGET_RUNTIME_$$(TARGET)) ($$(RUNS) runs)' && for i in \$$$$(seq 1 $$(RUNS)); do bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3) $$(TARGET_RUNTIME_$$(TARGET)); done" > $$@.jobid; \
		echo "Benchmark job ID: $$$$(cat $$@.jobid) submitted"; \
	fi
else
	@i=1; while [ $$$$i -le $$(RUNS) ]; do bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3) $$(TARGET_RUNTIME_$$(TARGET)); i=$$$$((i+1)); done > $$@
endif
endef

$(foreach s,$(SPEC_VARIANTS),$(foreach i,$(INLINE_VARIANTS),$(foreach c,$(COMPILERS),$(eval $(call RAW_template,$s,$i,$c)))))

# Generate build targets for each compiler
define BUILD_TARGETS
build_$(1): $$(foreach v,$$(VARIANT_COMBINATIONS),bin/MG_$$v_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(1))
endef

$(foreach c,$(COMPILERS),$(eval $(call BUILD_TARGETS,$(c))))

# Pattern rule for building binaries
define BUILD_template
bin/MG_$(1)_$(2)_$$(CLASS)_$$(TARGET)_$$(FLAGS_HASH)_$(3): $$(SOURCE)
	@mkdir -p bin
	@echo "Building $(1)_$(2) with $(3) compiler..."
ifdef SLURM_ENABLE
	@mkdir -p $$(SLURM_LOGS)
	@echo "Submitting build job for $(1)_$(2)_$(3)..."
	@$$(SBATCH_BASE) --output=$$(SLURM_LOGS)/build_$(1)_$(2)_$(3)_%j.out --wrap "echo 'Running: $$(SAC2C_$(3)) $$(LIBFLAGS_$(3)) -DCLASS_$$(CLASS)=1 $(if $(filter fullspec,$(1)),-DSPECS) $(if $(filter inline,$(2)),-DISINLINE) $$(TARGET_FLAG_$$(TARGET)) $$(SAC2CFLAGS) $$< -o$$@' && $$(SAC2C_$(3)) $$(LIBFLAGS_$(3)) -DCLASS_$$(CLASS)=1 $(if $(filter fullspec,$(1)),-DSPECS) $(if $(filter inline,$(2)),-DISINLINE) $$(TARGET_FLAG_$$(TARGET)) $$(SAC2CFLAGS) $$< -o$$@" > $$@.jobid
	@echo "Build job ID: $$$$(cat $$@.jobid) submitted"
else
	$$(SAC2C_$(3)) $$(LIBFLAGS_$(3)) -DCLASS_$$(CLASS)=1 $(if $(filter fullspec,$(1)),-DSPECS) $(if $(filter inline,$(2)),-DISINLINE) $$(TARGET_FLAG_$$(TARGET)) $$(SAC2CFLAGS) $$< -o$$@
endif
endef

$(foreach s,$(SPEC_VARIANTS),$(foreach i,$(INLINE_VARIANTS),$(foreach c,$(COMPILERS),$(eval $(call BUILD_template,$s,$i,$c)))))

# Test all combinations
test:
	@$(MAKE) CLASS=S TARGET=mt_pth build_new build_orig
	@echo "=== Testing all combinations ==="
	@for c in $(COMPILERS); do \
		echo "Testing $$c compiler:"; \
		for v in $(VARIANT_COMBINATIONS); do \
			echo "  $$v..."; \
			bin/MG_$${v}_S_mt_pth_$(FLAGS_HASH)_$$c -mt 2 > /dev/null || exit 1; \
		done; \
	done
	@echo "All tests passed!"

clean:
	$(RM) -rf bin out slurm_logs

distclean: clean
	$(RM) -rf venv

.PHONY: all benchmark benchmark_new benchmark_orig comparison build build_new build_orig sync test clean distclean venv S A B C D
