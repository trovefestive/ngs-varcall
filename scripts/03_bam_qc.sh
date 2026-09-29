#!/usr/bin/env bash
# Alignment QC and the "callable" region mask (depth >= MIN_CALLABLE_DP within REGION).
set -euo pipefail
source config.sh
BAM=$OUT/bam/${SAMPLE}.md.bam
Q=$OUT/bamqc
mkdir -p "$Q/tmp"
samtools flagstat "$BAM" > "$Q/flagstat.txt"
samtools stats -@ "$THREADS" "$BAM" $CHROMS > "$Q/samtools_stats.txt"

# Per-base depth, one chromosome per process (MAPQ/BASEQ filtered, duplicates excluded by default;
# -J counts deletions so homozygous deletions do not punch holes in the callable mask).
# Depth is streamed into a callable BED (contiguous bases at >= MIN_CALLABLE_DP) and a depth
# histogram instead of being stored per base, which would be ~1e9 lines genome-wide.
depth_chrom() {
  samtools depth -J -r "$1" -Q "$MIN_MAPQ" -q "$MIN_BASEQ" "$BAM" \
    | awk -v m="$MIN_CALLABLE_DP" -v hist="$Q/tmp/$1.hist" 'BEGIN{OFS="\t"}
        { h[$3]++ }
        $3>=m { if (s && $2==e+1) e=$2; else { if (s) print $1,s-1,e; s=$2; e=$2 }; c=$1 }
        END { if (s) print c,s-1,e; for (d in h) print d, h[d] > hist }' \
    > "$Q/tmp/$1.callable.bed"
}
export -f depth_chrom; export BAM Q MIN_MAPQ MIN_BASEQ MIN_CALLABLE_DP
printf '%s\n' $CHROMS | xargs -P "$THREADS" -I{} bash -c 'depth_chrom {}'
for c in $CHROMS; do cat "$Q/tmp/$c.callable.bed"; done > "$Q/callable.bed"
cat "$Q"/tmp/*.hist | awk 'BEGIN{OFS="\t"} {h[$1]+=$2} END{for (d in h) print d, h[d]}' \
  | sort -k1,1n > "$Q/depth_hist.tsv"
rm -rf "$Q/tmp"

# Evaluation BED = GIAB high-confidence regions  ∩  callable  (on REGION only)
awk -v cs="$CHROMS" 'BEGIN{n=split(cs,a," "); for(i=1;i<=n;i++) k[a[i]]=1} $1 in k' "$TRUTH_BED" \
  | sort -k1,1 -k2,2n > "$Q/truth_region.bed"
bedtools intersect -a "$Q/truth_region.bed" -b "$Q/callable.bed" \
  | sort -k1,1 -k2,2n | bedtools merge -i - > "$Q/eval.bed"
awk '{s+=$3-$2} END{printf "[bamqc] evaluation territory: %d bp\n", s}' "$Q/eval.bed"
