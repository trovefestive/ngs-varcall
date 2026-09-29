#!/bin/bash
#SBATCH --job-name=giab_exome_dv
#SBATCH --partition=standard
#SBATCH --account=mohilab
#SBATCH --cpus-per-task=32
#SBATCH --mem=96G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out
# DeepVariant (WES model) on the whole-exome BAM and callable BED from run_rivanna_exome.slurm,
# scored with vcfeval on the same evaluation BED, then both callers split by GIAB stratification.
# Run after run_rivanna_exome.slurm: sbatch slurm/run_rivanna_deepvariant.slurm
set -euo pipefail
module load apptainer 2>/dev/null || true
module load miniforge 2>/dev/null || module load anaconda 2>/dev/null || true
source activate ngs-varcall 2>/dev/null || conda activate ngs-varcall
cd "$SLURM_SUBMIT_DIR"

export REGION=autosomes OUT=results_exome THREADS=$SLURM_CPUS_PER_TASK RTG_MEM=24g
bash scripts/09_deepvariant.sh
CALLS=$OUT/deepvariant/NA12878.autosomes.dv.vcf.gz EVAL=$OUT/vcfeval_deepvariant bash scripts/07_vcfeval.sh
bash scripts/08_stratify.sh "$OUT/vcfeval"
bash scripts/08_stratify.sh "$OUT/vcfeval_deepvariant"
