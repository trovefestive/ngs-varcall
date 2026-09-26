# Configuration for the NA12878 (GIAB HG001) chr20 exome variant-calling benchmark.
# Edit paths here; every script sources this file.

SAMPLE=NA12878
THREADS=${THREADS:-8}
REGION=chr20                       # restrict calling and evaluation to one chromosome

# Working directories
DATA=${DATA:-data}
OUT=${OUT:-results}

# Reference: GRCh38 no-alt analysis set (the build GIAB v4.2.1 truth is on).
# If your cluster already has a BWA index for this exact build, set REF to it and skip indexing.
REF=${REF:-$DATA/ref/GRCh38_no_alt_analysis_set.fna}
REF_URL=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz

# Reads: Garvan NA12878 HiSeq exome (NIST7035), lane 1. Check the URLs still resolve before a long run;
# GIAB occasionally reorganizes its FTP.
GIAB=https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab
R1_URL=$GIAB/data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/NIST7035_TAAGGCGA_L001_R1_001.fastq.gz
R2_URL=$GIAB/data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/NIST7035_TAAGGCGA_L001_R2_001.fastq.gz
R1=${R1:-$DATA/reads/${SAMPLE}_R1.fastq.gz}
R2=${R2:-$DATA/reads/${SAMPLE}_R2.fastq.gz}

# Truth set: GIAB HG001 v4.2.1 benchmark calls and high-confidence regions (GRCh38)
TRUTH_URL=$GIAB/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
TRUTH_BED_URL=$GIAB/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.bed
TRUTH_VCF=${TRUTH_VCF:-$DATA/truth/HG001_v4.2.1.vcf.gz}
TRUTH_BED=${TRUTH_BED:-$DATA/truth/HG001_v4.2.1.bed}

# QC / calling thresholds
MIN_MAPQ=20
MIN_BASEQ=20
MIN_CALLABLE_DP=10     # a base counts as "callable" at >= this depth
FILTER_QUAL=20
FILTER_DP=10
