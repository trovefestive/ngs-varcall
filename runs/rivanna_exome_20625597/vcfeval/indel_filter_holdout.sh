#!/usr/bin/env bash
# Held-out check of the IndelLowAF filter: exome calls with vs without it, on chr20 (tuning) and chr1-19,21,22 (held out).
set -euo pipefail
cd /sfs/weka/scratch/uwy2ak/2026-ngs-varcall/ngs-variant-calling-giab
S=$1; R=results_exome; export RTG_MEM=24g
awk '$1=="chr20"' $R/bamqc/eval.bed > $S/eb_chr20.bed
awk '$1!="chr20"' $R/bamqc/eval.bed > $S/eb_heldout.bed
cp $R/vcf/NA12878.autosomes.vcf.gz $S/filt.vcf.gz; bcftools index -f -t $S/filt.vcf.gz
bcftools annotate -x FILTER/IndelLowAF -Oz -o $S/nofilt.vcf.gz $R/vcf/NA12878.autosomes.vcf.gz; bcftools index -f -t $S/nofilt.vcf.gz
printf "set\tfilter\tmode\tTP\tFP\tFN\tprecision\trecall\tF1\n" > $S/holdout.tsv
for set in chr20 heldout; do for v in nofilt filt; do for mode in gt allele; do
  o=$S/ho_${set}_${v}_${mode}; rm -rf $o
  rtg vcfeval $([ $mode = allele ] && echo --squash-ploidy) -t data/ref/autosomes.sdf -b data/truth/HG001_v4.2.1.vcf.gz \
    -c $S/$v.vcf.gz --bed-regions $S/eb_$set.bed --vcf-score-field QUAL --threads 8 -o $o > /dev/null
  tp=$(bcftools view -H -i 'TYPE!="snp"' $o/tp.vcf.gz | wc -l); fp=$(bcftools view -H -i 'TYPE!="snp"' $o/fp.vcf.gz | wc -l)
  fn=$(bcftools view -H -i 'TYPE!="snp"' $o/fn.vcf.gz | wc -l)
  awk -v s=$set -v v=$v -v m=$mode -v tp=$tp -v fp=$fp -v fn=$fn 'BEGIN{p=tp/(tp+fp); r=tp/(tp+fn); printf "%s\t%s\t%s\t%d\t%d\t%d\t%.4f\t%.4f\t%.4f\n",s,v,m,tp,fp,fn,p,r,2*p*r/(p+r)}' >> $S/holdout.tsv
done; done; done
column -t $S/holdout.tsv
