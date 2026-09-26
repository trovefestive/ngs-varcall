#!/usr/bin/env python3
"""Score variant calls against a truth set.

Both VCFs are expected to be restricted to the same evaluation regions and
left-normalized with multiallelic records split (see 05_evaluate.sh).

Matching is on (chrom, pos, ref, alt). This is a simple allele-level match; it
does not reconcile different representations of the same complex variant. For a
formal benchmark use hap.py or rtg vcfeval (see README), which do haplotype-aware
comparison. On chr20 exome data the two usually agree closely for SNVs and differ
mostly on indels in repeats.
"""
import argparse, csv, os
import pysam


def vtype(ref, alt):
    return "SNV" if len(ref) == 1 and len(alt) == 1 else "INDEL"


def zyg(rec):
    s = rec.samples[0]
    gt = s.get("GT")
    if gt is None or None in gt:
        return "unknown"
    alts = [a for a in gt if a and a > 0]
    if len(alts) == 2 and alts[0] == alts[1]:
        return "hom_alt"
    return "het" if alts else "hom_ref"


def load(path):
    out = {}
    with pysam.VariantFile(path) as vf:
        for rec in vf:
            if rec.alts is None:
                continue
            for alt in rec.alts:
                if alt == "*":
                    continue
                key = (rec.chrom, rec.pos, rec.ref, alt)
                s = rec.samples[0]
                dp = s.get("DP") if "DP" in rec.format else None
                out[key] = {"type": vtype(rec.ref, alt), "zyg": zyg(rec),
                            "qual": rec.qual, "dp": dp,
                            "filter": ";".join(rec.filter.keys()) or "PASS"}
    return out


def prf(tp, fp, fn):
    p = tp / (tp + fp) if tp + fp else float("nan")
    r = tp / (tp + fn) if tp + fn else float("nan")
    f = 2 * p * r / (p + r) if p + r else float("nan")
    return p, r, f


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--truth", required=True)
    ap.add_argument("--calls", required=True, help="PASS calls")
    ap.add_argument("--all-calls", help="all calls incl. filtered, for the QUAL table")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    truth, calls = load(a.truth), load(a.calls)
    rows = []
    for t in ("SNV", "INDEL", "ALL"):
        T = {k: v for k, v in truth.items() if t == "ALL" or v["type"] == t}
        C = {k: v for k, v in calls.items() if t == "ALL" or v["type"] == t}
        tp = T.keys() & C.keys()
        fp, fn = C.keys() - T.keys(), T.keys() - C.keys()
        gt_ok = sum(1 for k in tp if T[k]["zyg"] == C[k]["zyg"])
        p, r, f = prf(len(tp), len(fp), len(fn))
        rows.append({"type": t, "truth": len(T), "calls": len(C), "TP": len(tp),
                     "FP": len(fp), "FN": len(fn), "precision": round(p, 4),
                     "recall": round(r, 4), "F1": round(f, 4),
                     "GT_concordance": round(gt_ok / len(tp), 4) if tp else float("nan")})

    with open(os.path.join(a.out, "metrics.tsv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]), delimiter="\t")
        w.writeheader(); w.writerows(rows)

    # Per-site table for review (FP/FN lists and QUAL distributions)
    allc = load(a.all_calls) if a.all_calls else calls
    with open(os.path.join(a.out, "sites.tsv"), "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["chrom", "pos", "ref", "alt", "type", "status", "filter", "qual", "dp",
                    "call_zyg", "truth_zyg"])
        for k in sorted(allc.keys() | truth.keys(), key=lambda x: (x[0], x[1])):
            c, t = allc.get(k), truth.get(k)
            if c and t:
                status = "TP" if c["filter"] == "PASS" else "FN_filtered"
            elif c:
                status = "FP" if c["filter"] == "PASS" else "FP_filtered"
            else:
                status = "FN"
            src = c or t
            w.writerow([*k, src["type"], status, c["filter"] if c else "",
                        f'{c["qual"]:.1f}' if c and c["qual"] is not None else "",
                        c["dp"] if c else "", c["zyg"] if c else "", t["zyg"] if t else ""])

    for r in rows:
        print("{type:6s} TP={TP:6d} FP={FP:5d} FN={FN:5d}  precision={precision:.4f} "
              "recall={recall:.4f} F1={F1:.4f} GT_conc={GT_concordance}".format(**r))


if __name__ == "__main__":
    main()
