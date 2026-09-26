#!/bin/bash
#SBATCH --job-name=giab_chr20
#SBATCH --partition=standard
#SBATCH --account=YOUR_ALLOCATION
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.out
# Full run on UVA HPC (Rivanna/Afton). The first run includes bwa index of GRCh38 (~1 h).
set -euo pipefail
module load miniforge 2>/dev/null || module load anaconda 2>/dev/null || true
source activate ngs-varcall 2>/dev/null || conda activate ngs-varcall
cd "$SLURM_SUBMIT_DIR"
mkdir -p logs
THREADS=$SLURM_CPUS_PER_TASK bash scripts/run_all.sh
