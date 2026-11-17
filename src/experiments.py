"""Benchmark tai lap: moi phep do trong process moi; wall time va peak RSS.
resource.getrusage can co tren Linux/Colab. Khong dung tracemalloc de gia lam RAM.
"""
import argparse, csv, hashlib, json, os, platform, random, subprocess, sys, time
from pathlib import Path
from statistics import median
from .io_utils import read_transactions, write_transactions, read_patterns, compare_patterns

CONFIG = {
    'chess': ['0.9','0.85','0.8','0.75','0.7'],
    'mushrooms': ['0.8','0.7','0.6','0.5','0.4'],
    'retail': ['0.02','0.015','0.01','0.0075','0.005'],
    'T10I4D100K': ['0.02','0.015','0.01','0.0075','0.005'],
}


def save_csv(path, rows):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    if rows:
        with path.open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)


def measure(command, tag, timeout=180):
    target=Path('results/logs');target.mkdir(parents=True,exist_ok=True)
    mem=target/f'{tag}.rss'
    started=time.perf_counter()
    run=subprocess.run([sys.executable,'-m','src.meter',str(mem)]+command,
                       text=True,capture_output=True,timeout=timeout)
    wall=time.perf_counter()-started
    (target/f'{tag}.log').write_text(run.stdout+'\n'+run.stderr)
    if run.returncode:
        raise RuntimeError(f'{tag} failed: {run.stderr[-1200:]}')
    measurement=json.loads(mem.read_text())
    return measurement['wall_seconds'],measurement['peak_rss_mib']


def run_one(path, support, name, repeats=3, spmf=True):
    records=[]; output=Path('results/outputs');output.mkdir(parents=True,exist_ok=True)
    methods=['set','bitset']+(['spmf'] if spmf else [])
    for method in methods:
        out=output/f'{name}_{method}.txt'
        if method=='spmf':
            command=[os.environ.get('JAVA','java'),'-Xmx2g','-jar','tools/spmf.jar','run','Eclat',str(path),str(out),support]
        else:
            command=[sys.executable,'-m','src.cli',str(path),str(out),'--minsup',support,'--backend',method]
        times=[]; memories=[]
        for r in range(repeats):
            wall,rss=measure(command,f'{name}_{method}_{r}')
            times.append(wall);memories.append(rss)
            records.append(dict(case=name,input=str(path),minsup=support,method=method,
                                repetition=r+1,wall_seconds=wall,peak_rss_mib=rss))
        patterns=read_patterns(out)
        records[-1]['patterns']=len(patterns)
    # Fill pattern count for every repeated run; each deterministic output verified below.
    for row in records:
        row['patterns']=len(read_patterns(output/f'{name}_{row["method"]}.txt'))
    baseline=read_patterns(output/f'{name}_set.txt')
    optimized=read_patterns(output/f'{name}_bitset.txt')
    assert baseline==optimized, f'Backend mismatch: {name}'
    reference=read_patterns(output/f'{name}_spmf.txt') if spmf else baseline
    comparison=compare_patterns(optimized,reference)
    comparison.update(case=name,input=str(path),minsup=support,reference='SPMF' if spmf else 'set')
    if not comparison['equal']:raise AssertionError(comparison)
    return records,comparison


def toy():
    dest=Path('results/reference/toy');dest.mkdir(parents=True,exist_ok=True)
    comparisons=[]
    for p in sorted(Path('data/toy').glob('*.txt')):
        rows,check=run_one(p,'0.4',p.stem,1)
        (dest/p.name).write_text(Path(f'results/outputs/{p.stem}_spmf.txt').read_text())
        comparisons.append(check)
    save_csv('results/toy_correctness.csv',comparisons)


def benchmark(repeats):
    records=[];checks=[];stats=[]
    for name,supports in CONFIG.items():
        path=Path(f'data/benchmark/{name}.txt');rows=read_transactions(path)
        items=set().union(*map(set,rows)); width=sum(map(len,rows))/len(rows)
        stats.append(dict(dataset=name,transactions=len(rows),items=len(items),
                          average_width=width,density=width/len(items),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        for support in supports:
            case=f'{name}_{support}'
            print(case,flush=True)
            rec,check=run_one(path,support,case,repeats)
            records.extend(rec);checks.append(check)
            save_csv('results/benchmark.csv',records);save_csv('results/correctness.csv',checks)
    save_csv('results/dataset_stats.csv',stats)


def scalability(repeats):
    rows=read_transactions('data/benchmark/retail.txt')
    random.Random(42).shuffle(rows)
    records=[]
    for fraction in (.1,.25,.5,.75,1.):
        n=max(1,int(len(rows)*fraction))
        path=Path(f'results/subsets/retail_{fraction}.txt');write_transactions(path,rows[:n])
        rec,_=run_one(path,'0.01',f'scale_{fraction}',repeats)
        for r in rec:r.update(fraction=fraction,transactions=n)
        records.extend(rec)
    save_csv('results/scalability.csv',records)


def widths(repeats):
    # Cung universe va cung thu tu ngau nhien; moi transaction la prefix
    # cua cung mot permutation, nen cac tap long hon bao ham tap ngan hon.
    rng=random.Random(42)
    permutations=[rng.sample(range(1,61),60) for _ in range(2000)]
    records=[]
    for width in (5,10,15,20,25):
        path=Path(f'results/subsets/width_{width}.txt')
        write_transactions(path,[row[:width] for row in permutations])
        rec,_=run_one(path,'0.2',f'width_{width}',repeats)
        for r in rec:r.update(width=width,transactions=2000)
        records.extend(rec)
    save_csv('results/width.csv',records)


def main():
    p=argparse.ArgumentParser();p.add_argument('--toy',action='store_true')
    p.add_argument('--all',action='store_true');p.add_argument('--repeats',type=int,default=3)
    a=p.parse_args()
    if a.repeats<1:p.error('repeats >= 1')
    Path('results').mkdir(exist_ok=True)
    env=dict(python=sys.version,platform=platform.platform(),cpu=platform.processor(),
             java=subprocess.run([os.environ.get('JAVA','java'),'-version'],capture_output=True,text=True).stderr,
             seed=42,spmf_sha256=hashlib.sha256(Path('tools/spmf.jar').read_bytes()).hexdigest(),
             repeats=a.repeats,timing='Fresh process wall time including startup, input and output',
             memory='resource.getrusage of one child: peak RSS, MiB. Python process only; entire Java process for SPMF.')
    Path('results/environment.json').write_text(json.dumps(env,indent=2))
    if a.toy or a.all:toy()
    if a.all:benchmark(a.repeats);scalability(a.repeats);widths(a.repeats)

if __name__=='__main__':main()
