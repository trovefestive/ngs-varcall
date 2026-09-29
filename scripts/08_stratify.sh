#!/usr/bin/env bash
# Stratified accuracy: split a vcfeval result (step 7) by GIAB v3.3 genome stratifications, so errors
# can be attributed to homopolymers, tandem repeats, segmental duplications, low mappability, the MHC.
# Usage: bash scripts/08_stratify.sh [vcfeval_dir]   (default $OUT/vcfeval); writes <dir>/stratified.tsv
# Precision uses call-side TP/FP, recall uses truth-side TP (tp-baseline) and FN, as in vcfeval.
set -euo pipefail
source config.sh
EVAL=${1:-$OUT/vcfeval}
SD=$DATA/strat
STRAT_URL=$GIAB/release/genome-stratifications/v3.3/GRCh38@all
mkdir -p "$SD"

# name  path under STRAT_URL
STRATA="homopolymer_ge7        LowComplexity/GRCh38_AllHomopolymers_ge7bp_imperfectge11bp_slop5.bed.gz
tandem_repeat_or_homopol       LowComplexity/GRCh38_AllTandemRepeatsandHomopolymers_slop5.bed.gz
not_tandem_repeat_or_homopol   LowComplexity/GRCh38_notinAllTandemRepeatsandHomopolymers_slop5.bed.gz
segdup                         SegmentalDuplications/GRCh38_segdups.bed.gz
low_mappability                Mappability/GRCh38_lowmappabilityall.bed.gz
MHC                            OtherDifficult/GRCh38_MHC.bed.gz
all_difficult                  Union/GRCh38_alldifficultregions.bed.gz
not_difficult                  Union/GRCh38_notinalldifficultregions.bed.gz"
echo "$STRATA" | while read -r name path; do
  f=$SD/$(basename "$path")
  [ -s "$f" ] || { echo "[stratify] download $name"; curl -fsSL --retry 3 -o "$f" "$STRAT_URL/$path"; }
done

# SNV/INDEL counts for one vcfeval output file, optionally restricted to a BED
count() {  # file [bed]
  bcftools view -H ${2:+-T "$2"} "$1" 2>/dev/null | awk '{n=split($5,a,","); s=(length($4)==1); for(i=1;i<=n;i++) if(length(a[i])!=1) s=0; if(s) snv++; else ind++}
    END{printf "%d\t%d\n", snv, ind}'
}
stratum() {  # name [bed]
  local tp fp fn tpb
  tp=$(count "$EVAL/tp.vcf.gz" "${2:-}"); fp=$(count "$EVAL/fp.vcf.gz" "${2:-}")
  fn=$(count "$EVAL/fn.vcf.gz" "${2:-}"); tpb=$(count "$EVAL/tp-baseline.vcf.gz" "${2:-}")
  paste <(echo -e "$tp") <(echo -e "$fp") <(echo -e "$fn") <(echo -e "$tpb") | awk -v n="$1" 'BEGIN{OFS="\t"}
    { split("SNV INDEL", t, " "); for (i=1;i<=2;i++) {
        tp=$(i); fp=$(i+2); fn=$(i+4); tpb=$(i+6)
        p=(tp+fp)?tp/(tp+fp):"NA"; r=(tpb+fn)?tpb/(tpb+fn):"NA"; f=(p!="NA"&&r!="NA"&&p+r)?2*p*r/(p+r):"NA"
        printf "%s\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s\n", n, t[i], tpb+fn, tp, fp, fn,
          (p=="NA"?p:sprintf("%.4f",p)), (r=="NA"?r:sprintf("%.4f",r)), (f=="NA"?f:sprintf("%.4f",f)) } }'
}
export -f count stratum; export EVAL
{
  printf "stratum\ttype\ttruth\tTP\tFP\tFN\tprecision\trecall\tF1\n"
  stratum all
  echo "$STRATA" | while read -r name path; do echo "$name $SD/$(basename "$path")"; done \
    | xargs -P "$THREADS" -L1 bash -c 'stratum "$0" "$1" > "$EVAL/.strat_$0.tsv"'
  echo "$STRATA" | while read -r name path; do cat "$EVAL/.strat_$name.tsv"; rm "$EVAL/.strat_$name.tsv"; done
} > "$EVAL/stratified.tsv"
column -t "$EVAL/stratified.tsv"
