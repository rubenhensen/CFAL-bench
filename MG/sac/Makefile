SEQ_LPATH  := host/seq
MT_LPATH   := host/mt-pth
CUDA_LPATH := host/cuda

DYLIB := so                          # adjust to your system (e.g. so)

SAC2C := /home/rhensen/sac2c/build_p/sac2c_p                  # may need to adjust if sac2c is not in your PATH
SAC2CFLAGS := -maxwlur 27 -maxlur 20 -v3 -maxoptcyc 20 # when changing you may want to include -check c

all: seq test mt cuda

seq: | bin/MG_fullspec_${CLASS}_seq bin/MG_nospec_${CLASS}_seq

mt: | bin/MG_fullspec_${CLASS}_mt bin/MG_nospec_${CLASS}_mt

cuda: | bin/MG_fullspec_${CLASS}_cuda bin/MG_nospec_${CLASS}_cuda 
cuda: SAC2CFLAGS += -nomemrt

bin/MG_fullspec_${CLASS}_seq: src/MG_fullspec.sac 
	mkdir -p bin
	$(SAC2C) -D CLASS_${CLASS}=1 $(SAC2CFLAGS) $< -o$@
	$(RM) bin/MG_fullspec_seq.*

bin/MG_fullspec_${CLASS}_mt: src/MG_fullspec.sac 
	mkdir -p bin
	$(SAC2C) -D CLASS_${CLASS}=1 -tmt_pth $(SAC2CFLAGS) $< -o$@
	$(RM) bin/MG_fullspec_mt.*

bin/MG_fullspec_${CLASS}_cuda: src/MG_fullspec.sac 
	mkdir -p bin
	$(SAC2C) -D CLASS_${CLASS}=1 -tcuda_man $(SAC2CFLAGS) $< -o$@
	$(RM) bin/MG_fullspec_cuda.*

bin/MG_nospec_${CLASS}_seq: src/MG_nospec.sac 
	mkdir -p bin
	$(SAC2C) -D CLASS_${CLASS}=1 $(SAC2CFLAGS) $< -o$@
	$(RM) bin/MG_nospec_seq.*

bin/MG_nospec_${CLASS}_mt: src/MG_nospec.sac 
	mkdir -p bin
	$(SAC2C) -D CLASS_${CLASS}=1 -tmt_pth $(SAC2CFLAGS) $< -o$@
	$(RM) bin/MG_nospec_mt.*

bin/MG_nospec_${CLASS}_cuda: src/MG_nospec.sac 
	mkdir -p bin
	$(SAC2C) -D CLASS_${CLASS}=1 -tcuda_man $(SAC2CFLAGS) $< -o$@
	$(RM) bin/MG_nospec_cuda.*

bench: bench_seq bench_mt bench_cuda

bench_seq:
	sbatch bench_seq.sh C 10 out

bench_mt:
	sbatch bench_mt.sh C 10 out 32

bench_cuda:
	sbatch bench_cuda.sh C 10 out

switch_orig: 
	@echo "Switching to SAC2C_ORIG configuration..."
	@sed -i 's|/home/rhensen/sac2c/|/home/rhensen/sacoriginal/sac2c/|g' ~/.sac2crc/sac2crc.debug.prelude ~/.sac2crc/sac2crc.release.prelude
	@sed -i 's|/home/rhensen/Stdlib/|/home/rhensen/sacoriginal/Stdlib/|g' ~/.sac2crc/sac2crc.package.stdlib

switch_new:
	@echo "Switching to SAC2C_NEW configuration..."
	@sed -i 's|/home/rhensen/sacoriginal/sac2c/|/home/rhensen/sac2c/|g' ~/.sac2crc/sac2crc.debug.prelude ~/.sac2crc/sac2crc.release.prelude
	@sed -i 's|/home/rhensen/sacoriginal/Stdlib/|/home/rhensen/Stdlib/|g' ~/.sac2crc/sac2crc.package.stdlib


$(SEQ_LPATH)/lib%Mod.$(DYLIB): src/%.sac
	$(SAC2C) $(SAC_FLAGS) $<

$(MT_LPATH)/lib%Mod.$(DYLIB): src/%.sac
	$(SAC2C) $(SAC_FLAGS) -tmt_pth $<

$(CUDA_LPATH)/lib%Mod.$(DYLIB): src/%.sac
	$(SAC2C) $(SAC_FLAGS) -tcuda_man $<


clean:
	$(RM) bin/*
	$(RM) -rf host tree
