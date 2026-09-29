#!/bin/bash
#SBATCH --job-name=giab_exome
#SBATCH --partition=standard
#SBATCH --account=mohilab
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out
# Whole-exome (chr1-22) calling and evaluation on the four-lane merged BAM.
# bwa aligned against the whole genome, so this reuses results_4lane/bam and skips download,
# fastp and alignment; it reruns BAM QC, calling, evaluation, report and vcfeval on all autosomes.
# Run after run_rivanna_4lane.slurm: mkdir -p logs && sbatch slurm/run_rivanna_exome.slurm
set -euo pipefail
module load miniforge 2>/dev/null || module load anaconda 2>/dev/null || true
source activate ngs-varcall 2>/dev/null || conda activate ngs-varcall
cd "$SLURM_SUBMIT_DIR"

export REGION=autosomes OUT=results_exome SKIP_DOWNLOAD=1 SKIP_ALIGN=1 THREADS=$SLURM_CPUS_PER_TASK
export RTG_MEM=24g   # vcfeval over all autosomes needs more than the default heap
SRC=results_4lane
mkdir -p "$OUT/bam" "$OUT/qc"
for f in bam/NA12878.md.bam bam/NA12878.md.bam.bai bam/markdup.stats.txt qc/fastp.json qc/fastp.html; do
  ln -sfn "$PWD/$SRC/$f" "$OUT/$f"
done
bash scripts/run_all.sh
bash scripts/07_vcfeval.sh
