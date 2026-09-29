# bcftools vs DeepVariant, whole exome (chr1-22)

Job 20627173 (52 min on 32 cores, including a one-time 43 min container pull). DeepVariant 1.6.1, WES model,
run on the four-lane BAM over the callable BED (≥10x) from job 20625597, and scored with rtg vcfeval
(genotype-aware, PASS calls, QUAL as score) on the same 101.3 Mb evaluation BED as the bcftools calls.
bcftools calls include the `LowQual` and `IndelLowAF` soft filters.

## Overall

| caller | type | TP | FP | FN | precision | recall | F1 |
|:--|:--|--:|--:|--:|--:|--:|--:|
| bcftools | SNV | 92317 | 1741 | 3285 | 0.9815 | 0.9656 | 0.9735 |
| DeepVariant | SNV | 94231 | 746 | 1349 | 0.9921 | 0.9859 | 0.9890 |
| bcftools | INDEL | 8376 | 2829 | 2632 | 0.7475 | 0.7609 | 0.7542 |
| DeepVariant | INDEL | 9994 | 533 | 945 | 0.9494 | 0.9136 | 0.9311 |

## By GIAB v3.3 stratification (F1; full tables in `stratified/`)

Recall here uses truth-side counts (tp-baseline), so it can differ from the table above in the fourth decimal.

| stratum | truth SNV / INDEL | bcftools SNV | DeepVariant SNV | bcftools INDEL | DeepVariant INDEL |
|:--|--:|--:|--:|--:|--:|
| all | 95584 / 10929 | 0.974 | 0.989 | 0.753 | 0.931 |
| homopolymer ≥7 bp | 1757 / 3868 | 0.945 | 0.979 | 0.606 | 0.890 |
| tandem repeat or homopolymer | 3665 / 5368 | 0.942 | 0.983 | 0.594 | 0.874 |
| not tandem repeat / homopolymer | 91919 / 5561 | 0.975 | 0.989 | 0.926 | 0.985 |
| segmental duplication | 12140 / 859 | 0.898 | 0.946 | 0.800 | 0.926 |
| low mappability | 5272 / 330 | 0.835 | 0.899 | 0.714 | 0.850 |
| MHC | 1937 / 130 | 0.928 | 0.956 | 0.769 | 0.911 |
| all difficult | 29419 / 6873 | 0.943 | 0.974 | 0.648 | 0.893 |
| not difficult | 66165 / 4056 | 0.987 | 0.996 | 0.945 | 0.994 |

## Takeaways

- **The bcftools indel problem is a repeat problem.** Half of all truth indels (5368 of 10929) sit in tandem
  repeats or homopolymers, and 2669 of the 2829 bcftools indel FPs (94%) fall there; indel precision in
  repeats is 0.56 versus 0.97 outside. DeepVariant raises indel precision in repeats to 0.90 and F1 from 0.59
  to 0.87. Outside repeats the gap between callers is much smaller (0.926 vs 0.985).
- **Outside difficult regions both callers are near the ceiling.** In GIAB's "not difficult" territory
  DeepVariant reaches SNV F1 0.996 and indel F1 0.994, bcftools 0.987 and 0.945.
- **Mapping limits persist with either caller.** Low-mappability regions and segmental duplications stay the
  weakest strata for both (DeepVariant SNV F1 0.899 and 0.946). Both callers miss all six SNVs in the
  chr20:5474151-5474467 paralog cluster; DeepVariant cuts MHC SNV false negatives from 210 to 144.
