#!/usr/bin/env python3
"""Build a small synthetic test case: reference, diploid truth VCF, high-confidence BED,
and paired-end reads. Used only to check the pipeline runs end to end; real results come
from the GIAB data (see README)."""
import gzip, os, random, sys

random.seed(7)
OUT = sys.argv[1] if len(sys.argv) > 1 else "test/data"
L, COV, RL, INS, ERR = 300_000, 40, 150, 350, 0.002
N_SNV, N_INDEL = 300, 50
os.makedirs(OUT, exist_ok=True)
comp = str.maketrans("ACGT", "TGCA")

# Reference with some low-complexity stretches so indel calling is not trivial
ref = [random.choices("ACGT", weights=[3, 2, 2, 3])[0] for _ in range(L)]
for _ in range(40):
    p = random.randrange(1000, L - 1000); unit = random.choice(["A", "AC", "CAG", "T"])
    rep = (unit * 30)[:random.randint(10, 30)]; ref[p:p + len(rep)] = list(rep)
ref = "".join(ref)
with open(f"{OUT}/ref.fa", "w") as fh:
    fh.write(">chr20\n" + "\n".join(ref[i:i + 60] for i in range(0, L, 60)) + "\n")

# Variants, spaced >= 30 bp apart and away from the ends
pos = sorted(random.sample(range(2000, L - 2000, 37), N_SNV + N_INDEL))
kinds = ["SNV"] * N_SNV + ["INDEL"] * N_INDEL; random.shuffle(kinds)
var = []
for p, k in zip(pos, kinds):
    r = ref[p - 1]
    if k == "SNV":
        alt = random.choice([b for b in "ACGT" if b != r]); rr = r
    elif random.random() < 0.5:
        n = random.randint(1, 8); rr = ref[p - 1:p + n]; alt = r
    else:
        n = random.randint(1, 8); rr = r; alt = r + "".join(random.choices("ACGT", k=n))
    gt = random.choices([(0, 1), (1, 1)], weights=[6, 4])[0]
    var.append((p, rr, alt, gt))

with open(f"{OUT}/truth.vcf", "w") as fh:
    fh.write("##fileformat=VCFv4.2\n##contig=<ID=chr20,length=%d>\n" % L)
    fh.write('##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">\n')
    fh.write("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tNA12878\n")
    for p, rr, alt, gt in var:
        fh.write(f"chr20\t{p}\t.\t{rr}\t{alt}\t50\tPASS\t.\tGT\t{gt[0]}/{gt[1]}\n")
with open(f"{OUT}/truth.bed", "w") as fh:
    fh.write(f"chr20\t1000\t{L - 1000}\n")

def haplotype(h):
    s, last = [], 0
    for p, rr, alt, gt in var:
        if gt[h]:
            s.append(ref[last:p - 1]); s.append(alt); last = p - 1 + len(rr)
    s.append(ref[last:]); return "".join(s)

def qual_and_err(seq):
    out, q = [], []
    for i, b in enumerate(seq):
        e = ERR * (1 + 3 * i / RL)          # error rises along the read
        if random.random() < e:
            b = random.choice([x for x in "ACGT" if x != b]); q.append(chr(33 + random.randint(8, 20)))
        else:
            q.append(chr(33 + max(2, min(40, int(random.gauss(36 - 8 * i / RL, 3))))))
        out.append(b)
    return "".join(out), "".join(q)

haps = [haplotype(0), haplotype(1)]
n_pairs = COV * L // (2 * RL)
with gzip.open(f"{OUT}/reads_R1.fastq.gz", "wt") as f1, gzip.open(f"{OUT}/reads_R2.fastq.gz", "wt") as f2:
    for i in range(n_pairs):
        h = haps[random.randrange(2)]; ins = max(2 * RL, int(random.gauss(INS, 40)))
        s = random.randrange(0, len(h) - ins); frag = h[s:s + ins]
        if random.random() < 0.5:
            frag = frag.translate(comp)[::-1]
        r1, q1 = qual_and_err(frag[:RL]); r2, q2 = qual_and_err(frag[-RL:].translate(comp)[::-1])
        f1.write(f"@sim{i}/1\n{r1}\n+\n{q1}\n"); f2.write(f"@sim{i}/2\n{r2}\n+\n{q2}\n")
print(f"[simulate] {len(var)} variants, {n_pairs:,} read pairs -> {OUT}")
