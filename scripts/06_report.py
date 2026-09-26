#!/usr/bin/env python3
"""Collect read, alignment, coverage and accuracy QC into results/report.md with figures."""
import gzip, json, os, re, sys
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = sys.argv[1] if len(sys.argv) > 1 else "results"
MIN_DP = int(sys.argv[2]) if len(sys.argv) > 2 else 10
FIG = os.path.join(OUT, "figures"); os.makedirs(FIG, exist_ok=True)
lines = ["# Variant-calling QC report", ""]

# Read QC (fastp)
fj = os.path.join(OUT, "qc", "fastp.json")
if os.path.exists(fj):
    s = json.load(open(fj))["summary"]
    b, a = s["before_filtering"], s["after_filtering"]
    lines += ["## Read QC (fastp)", "", "| metric | before | after |", "|---|---|---|",
              f"| reads | {b['total_reads']:,} | {a['total_reads']:,} |",
              f"| Q30 bases | {b['q30_rate']:.1%} | {a['q30_rate']:.1%} |",
              f"| GC content | {b['gc_content']:.1%} | {a['gc_content']:.1%} |", ""]

# Alignment QC
sn = {}
for l in open(os.path.join(OUT, "bamqc", "samtools_stats.txt")):
    if l.startswith("SN\t"):
        k, v = l.rstrip("\n").split("\t")[1:3]; sn[k.rstrip(":")] = v
fs = open(os.path.join(OUT, "bamqc", "flagstat.txt")).read()
mapped = re.search(r"mapped \(([\d.]+)%", fs)
pp = re.search(r"properly paired \(([\d.]+)%", fs)
dup = ""
md = os.path.join(OUT, "bam", "markdup.stats.txt")
if os.path.exists(md):
    t = open(md).read()
    d = re.search(r"DUPLICATE TOTAL: (\d+)", t); r = re.search(r"READ: (\d+)", t)
    if d and r and int(r.group(1)):
        dup = f"{int(d.group(1)) / int(r.group(1)):.1%}"
lines += ["## Alignment QC", "", "| metric | value |", "|---|---|",
          f"| mapped (whole BAM) | {mapped.group(1) if mapped else 'NA'}% |",
          f"| properly paired | {pp.group(1) if pp else 'NA'}% |",
          f"| duplicate rate | {dup or 'NA'} |",
          f"| mismatch/error rate (region) | {float(sn.get('error rate', 'nan')):.4f} |",
          f"| mean insert size (region) | {sn.get('insert size average', 'NA')} |",
          f"| mean base quality (region) | {sn.get('average quality', 'NA')} |", ""]

# Coverage over the GIAB high-confidence territory
depth = pd.read_csv(os.path.join(OUT, "bamqc", "depth.tsv.gz"), sep="\t", header=None,
                    names=["chrom", "pos", "dp"])
bed = pd.read_csv(os.path.join(OUT, "bamqc", "truth_region.bed"), sep="\t", header=None,
                  usecols=[0, 1, 2], names=["chrom", "s", "e"])
covered = depth[depth.dp > 0]
lines += ["## Coverage", "",
          f"- Bases with any coverage: {len(covered):,}",
          f"- Median depth where covered: {covered.dp.median():.0f}x",
          f"- Bases at >= {MIN_DP}x: {(depth.dp >= MIN_DP).sum():,}",
          f"- GIAB high-confidence bases on this chromosome: {int((bed.e - bed.s).sum()):,}", ""]
fig, ax = plt.subplots(figsize=(6, 3.5))
ax.hist(covered.dp.clip(upper=300), bins=60, color="#3b6ea5")
ax.axvline(MIN_DP, color="#c0392b", ls="--", lw=1, label=f"callable ≥{MIN_DP}x")
ax.set_xlabel("depth (capped at 300)"); ax.set_ylabel("bases"); ax.set_title("Per-base depth, covered bases")
ax.legend(frameon=False); fig.tight_layout(); fig.savefig(os.path.join(FIG, "depth_hist.png"), dpi=150)
lines += ["![depth](figures/depth_hist.png)", ""]

# Accuracy
m = pd.read_csv(os.path.join(OUT, "eval", "metrics.tsv"), sep="\t")
lines += ["## Accuracy vs GIAB truth (high-confidence ∩ callable)", "", m.to_markdown(index=False), ""]
sites = pd.read_csv(os.path.join(OUT, "eval", "sites.tsv"), sep="\t")
called = sites[sites.qual.notna()]
fig, ax = plt.subplots(figsize=(6, 3.5))
for st, col in [("TP", "#3b6ea5"), ("FP", "#c0392b"), ("FP_filtered", "#e59866"), ("FN_filtered", "#7f8c8d")]:
    q = called[called.status == st].qual
    if len(q):
        ax.hist(q.clip(upper=250), bins=50, alpha=0.6, label=f"{st} (n={len(q)})", color=col)
ax.set_yscale("log"); ax.set_xlabel("QUAL (capped at 250)"); ax.set_ylabel("sites (log)")
ax.set_title("Call quality by truth status"); ax.legend(frameon=False, fontsize=8)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "qual_by_status.png"), dpi=150)
lines += ["![qual](figures/qual_by_status.png)", ""]

fp = sites[sites.status == "FP"].sort_values("qual", ascending=False).head(15)
fn = sites[sites.status == "FN"].head(15)
lines += ["## Sites to review in IGV", "", "Highest-QUAL false positives:", "",
          fp.to_markdown(index=False) if len(fp) else "_none_", "",
          "False negatives (first 15):", "", fn.to_markdown(index=False) if len(fn) else "_none_", ""]

open(os.path.join(OUT, "report.md"), "w").write("\n".join(lines))
print(f"[report] wrote {OUT}/report.md")
