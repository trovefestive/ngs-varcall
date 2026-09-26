#!/usr/bin/env bash
# Download reference, reads and GIAB truth set, then index the reference.
set -euo pipefail
source config.sh
mkdir -p "$DATA"/{ref,reads,truth}

fetch() { [ -s "$2" ] || { echo "[download] $1"; curl -fL --retry 3 -o "$2" "$1"; }; }

fetch "$R1_URL" "$R1"
fetch "$R2_URL" "$R2"
fetch "$TRUTH_URL" "$TRUTH_VCF"
fetch "$TRUTH_URL.tbi" "$TRUTH_VCF.tbi"
fetch "$TRUTH_BED_URL" "$TRUTH_BED"

if [ ! -s "$REF" ]; then
  fetch "$REF_URL" "$REF.gz"
  gunzip -c "$REF.gz" > "$REF" && rm "$REF.gz"
fi
[ -s "$REF.fai" ] || samtools faidx "$REF"
[ -s "$REF.bwt" ] || { echo "[index] bwa index (about 1 h for GRCh38)"; bwa index "$REF"; }
echo "[download] done"
