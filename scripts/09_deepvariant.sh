#!/usr/bin/env bash
# Second caller for comparison: DeepVariant (WES model) on the same BAM, restricted to the callable BED.
# Runs the official container with apptainer; score the output with
#   CALLS=$OUT/deepvariant/$SAMPLE.$REGION.dv.vcf.gz EVAL=$OUT/vcfeval_deepvariant bash scripts/07_vcfeval.sh
set -euo pipefail
source config.sh
DV_VERSION=${DV_VERSION:-1.6.1}
SIF=${DV_SIF:-$DATA/containers/deepvariant_${DV_VERSION}.sif}
D=$OUT/deepvariant
mkdir -p "$D/tmp" "$(dirname "$SIF")"/{cache,tmp}
C=$(cd "$(dirname "$SIF")" && pwd)   # apptainer needs absolute cache/tmp paths
export APPTAINER_CACHEDIR=${APPTAINER_CACHEDIR:-$C/cache} APPTAINER_TMPDIR=${APPTAINER_TMPDIR:-$C/tmp}
[ -s "$SIF" ] || { echo "[deepvariant] pulling google/deepvariant:$DV_VERSION"; apptainer pull "$SIF" "docker://google/deepvariant:$DV_VERSION"; }

# The BAM may be a symlink into another results directory; bind the whole working tree
apptainer exec --bind "$PWD:$PWD" --pwd "$PWD" "$SIF" /opt/deepvariant/bin/run_deepvariant \
  --model_type=WES \
  --ref="$REF" \
  --reads="$(readlink -f "$OUT/bam/${SAMPLE}.md.bam")" \
  --regions="$OUT/bamqc/callable.bed" \
  --output_vcf="$D/${SAMPLE}.${REGION}.dv.vcf.gz" \
  --num_shards="$THREADS" \
  --intermediate_results_dir="$D/tmp"
rm -rf "$D/tmp"
bcftools stats -F "$REF" "$D/${SAMPLE}.${REGION}.dv.vcf.gz" > "$D/bcftools_stats.txt"
