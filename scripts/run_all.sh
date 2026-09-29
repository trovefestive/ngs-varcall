#!/usr/bin/env bash
# Run the full pipeline. SKIP_DOWNLOAD=1 if data are already in place; SKIP_FASTP=1 to align raw reads;
# SKIP_ALIGN=1 to reuse an existing $OUT/bam/$SAMPLE.md.bam.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.sh
[ "${SKIP_DOWNLOAD:-0}" = 1 ] || bash scripts/00_download.sh
[ "${SKIP_FASTP:-0}" = 1 ] || [ "${SKIP_ALIGN:-0}" = 1 ] || bash scripts/01_read_qc.sh
[ "${SKIP_ALIGN:-0}" = 1 ]    || bash scripts/02_align.sh
bash scripts/03_bam_qc.sh
bash scripts/04_call.sh
bash scripts/05_evaluate.sh
python3 scripts/06_report.py "$OUT" "$MIN_CALLABLE_DP"
