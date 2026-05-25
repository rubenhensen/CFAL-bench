# MG Benchmark — Report

_Generated: 2026-05-25T21:07:01_

Classes: **A, B, C**  Target: **mt_pth**  Node(s): **cn99**

## Class A — GFLOP/s by variant (new vs orig compiler)

| Spec | Inline | new mean | orig mean | new std | orig std | Speedup | Significant? | Winner |
|---|---|---|---|---|---|---|---|---|
| fullspec | inline | 3.7020 | 3.7066 | 0.0770 | 0.0355 | 0.9987 | NO | TIE |
| fullspec | noinline | 1.8504 | 1.8191 | 0.0167 | 0.0203 | 1.0172 | YES | NEW |
| nospec | inline | 3.1796 | 0.5301 | 0.1508 | 0.0260 | 5.9981 | YES | NEW |
| nospec | noinline | 1.7042 | 0.4130 | 0.0336 | 0.0124 | 4.1266 | YES | NEW |

### Class A — cross-comparison: nospec/new vs fullspec/orig

| Inline | nospec/new mean | fullspec/orig mean | Speedup | p-value | Winner |
|--------|----------------|-------------------|---------|---------|--------|
| inline | 3.1796 | 3.7066 | 0.8578 | 0.0000 | fullspec/orig |
| noinline | 1.7042 | 1.8191 | 0.9369 | 0.0000 | fullspec/orig |

## Class B — GFLOP/s by variant (new vs orig compiler)

| Spec | Inline | new mean | orig mean | new std | orig std | Speedup | Significant? | Winner |
|---|---|---|---|---|---|---|---|---|
| fullspec | inline | 3.6583 | 3.6682 | 0.2726 | 0.0835 | 0.9973 | NO | TIE |
| fullspec | noinline | 1.6069 | 1.5368 | 0.1437 | 0.1557 | 1.0456 | NO | TIE |
| nospec | inline | 3.5186 | 0.5237 | 0.0594 | 0.0157 | 6.7187 | YES | NEW |
| nospec | noinline | 1.8105 | 0.4166 | 0.0408 | 0.0094 | 4.3460 | YES | NEW |

### Class B — cross-comparison: nospec/new vs fullspec/orig

| Inline | nospec/new mean | fullspec/orig mean | Speedup | p-value | Winner |
|--------|----------------|-------------------|---------|---------|--------|
| inline | 3.5186 | 3.6682 | 0.9592 | 0.0000 | fullspec/orig |
| noinline | 1.8105 | 1.5368 | 1.1781 | 0.0000 | nospec/new |

## Class C — GFLOP/s by variant (new vs orig compiler)

| Spec | Inline | new mean | orig mean | new std | orig std | Speedup | Significant? | Winner |
|---|---|---|---|---|---|---|---|---|
| fullspec | inline | 2.8925 | 2.5586 | 0.2430 | 0.3868 | 1.1305 | YES | NEW |
| fullspec | noinline | 1.3967 | 1.2379 | 0.1792 | 0.0818 | 1.1283 | YES | NEW |
| nospec | inline | 2.2254 | 0.5230 | 0.0411 | 0.0076 | 4.2551 | YES | NEW |
| nospec | noinline | 1.6782 | 0.4409 | 0.0971 | 0.0034 | 3.8059 | YES | NEW |

### Class C — cross-comparison: nospec/new vs fullspec/orig

| Inline | nospec/new mean | fullspec/orig mean | Speedup | p-value | Winner |
|--------|----------------|-------------------|---------|---------|--------|
| inline | 2.2254 | 2.5586 | 0.8698 | 0.0005 | fullspec/orig |
| noinline | 1.6782 | 1.2379 | 1.3557 | 0.0000 | nospec/new |

## Reproducibility metadata

### SLURM

- Partition: `cncz`
- Account: `csmpi`
- CPUs per task: `4`
- Memory requested: `14G`
- Wall-clock cap: `00:30:00`
- Node(s) used: `cn99`

### Host environment

- CPU: `Intel(R) Xeon(R) CPU E5-2630 v3 @ 2.40GHz`
- Total memory (kB): `264023620`
- Kernel: `6.17.0-14-generic`
- OS: `Ubuntu 24.04.4 LTS`
- GCC: `gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`

### Compilers

#### `new`
- Path: `/home/rhensen/sac2c/build_p/sac2c_p`
- Commit: `f2870cfeac931033f66bf11ab827beee08030327`
- Branch: `progressive-dispatch-clean`
- `git describe`: `v2.1.0-PuurGeluk-327-gf2870cfea`
- `sac2c -V`: sac2c 2.1.0-PuurGeluk-327-gf2870 / build-type: RELEASE / built-by: "rhensen" at 2026-05-24T17:49:38 / 

#### `orig`
- Path: `/home/rhensen/sacoriginal/sac2c/build_p/sac2c_p`
- Commit: `ab3bbecacf1a978daf64b88cabc4b9df53d4b2e8`
- Branch: `develop`
- `git describe`: `v2.1.0-PuurGeluk-269-gab3bbecac`
- `sac2c -V`: sac2c 2.1.0-PuurGeluk-269-gab3bb / build-type: RELEASE / built-by: "rhensen" at 2026-05-24T17:37:57 / 

### Stdlib

- Path: `/home/rhensen/Stdlib`
- Commit: `9afffd46db51fd6877048f34fbd6c5a5de5eede5`
- Branch: `master`

### Benchmark configuration

- Classes: `A B C`   Target: `mt_pth`
- Compilers: `new orig`
- Spec variants: `fullspec nospec`
- Inline variants: `inline noinline`
- Runs per variant: `20`
- MT cores: `4`
- Measurement: wall-clock via `date +%s.%N`; GFLOP/s from binary stdout.

_Started: 2026-05-25T18:49:22+00:00 — Finished: 2026-05-25T19:46:19+00:00_