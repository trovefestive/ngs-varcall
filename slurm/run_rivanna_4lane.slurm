#!/bin/bash
#SBATCH --job-name=giab_chr20_4lane
#SBATCH --partition=standard
#SBATCH --account=mohilab
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.out
# All four Garvan NA12878 exome lanes (NIST7035 L001+L002, NIST7086 L001+L002) merged, to raise depth.
# Assumes the single-lane run already downloaded the reference, index, truth set and lane 1.
# Run: mkdir -p logs && sbatch slurm/run_rivanna_4lane.slurm
set -euo pipefail
module load miniforge 2>/dev/null || module load anaconda 2>/dev/null || true
source activate ngs-varcall 2>/dev/null || conda activate ngs-varcall
cd "$SLURM_SUBMIT_DIR"
source config.sh

RD=$DATA/reads
mkdir -p "$RD"
# lane 1 was saved as NA12878_R{1,2}.fastq.gz by 00_download.sh; fetch the other three under their original names
for f in NIST7035_TAAGGCGA_L002 NIST7086_CGTACTAG_L001 NIST7086_CGTACTAG_L002; do
  for r in R1 R2; do
    t=$RD/${f}_${r}_001.fastq.gz
    [ -s "$t" ] || { echo "[download] $f $r"; curl -sSL --retry 3 -o "$t" "$GIAB/data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/${f}_${r}_001.fastq.gz"; }
  done
done
# gzip members concatenate into a valid gzip stream
for r in R1 R2; do
  t=$RD/${SAMPLE}_4lane_${r}.fastq.gz
  [ -s "$t" ] || { echo "[merge] $r"; cat "$RD/${SAMPLE}_${r}.fastq.gz" "$RD"/NIST70*_${r}_001.fastq.gz > "$t"; }
done

export R1=$RD/${SAMPLE}_4lane_R1.fastq.gz R2=$RD/${SAMPLE}_4lane_R2.fastq.gz
export OUT=results_4lane SKIP_DOWNLOAD=1 THREADS=$SLURM_CPUS_PER_TASK
bash scripts/run_all.sh
bash scripts/07_vcfeval.sh
