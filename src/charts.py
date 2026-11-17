"""Ve SVG bang standard library; khong can matplotlib/seaborn."""
import csv,html
from collections import defaultdict
from pathlib import Path
from statistics import median

COLORS={'set':'#d97706','bitset':'#087f8c','spmf':'#7c3aed'}


def chart(path,title,xlabel,ylabel,series,reverse=False):
    W,H=700,380;L,R,T,B=80,35,60,65
    points=[point for data in series.values() for point in data]
    if not points:return
    xs=[p[0] for p in points];ys=[p[1] for p in points]
    low,high=min(xs),max(xs); top=max(ys)*1.12 or 1
    def x(v):
        t=(v-low)/(high-low or 1)
        if reverse:t=1-t
        return L+t*(W-L-R)
    def y(v):return H-B-v/top*(H-T-B)
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
         '<rect width="100%" height="100%" fill="white"/>',
         '<g font-family="Arial,sans-serif" fill="#243746" font-size="13">',
         f'<text x="{L}" y="24" font-size="18" font-weight="bold">{html.escape(title)}</text>']
    for i in range(6):
        value=top*i/5; yy=y(value)
        out += [f'<line x1="{L}" y1="{yy}" x2="{W-R}" y2="{yy}" stroke="#e2e8f0"/>',
                f'<text x="{L-10}" y="{yy+4}" text-anchor="end">{value:.3g}</text>']
    for v in sorted(set(xs)):
        out.append(f'<text x="{x(v)}" y="{H-B+23}" text-anchor="middle">{v:g}</text>')
    for k,(name,data) in enumerate(series.items()):
        color=COLORS.get(name,'#087f8c')
        coords=' '.join(f'{x(a):.2f},{y(b):.2f}' for a,b in data)
        out.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="2.5"/>')
        for a,b in data:out.append(f'<circle cx="{x(a)}" cy="{y(b)}" r="3.5" fill="{color}"/>')
        out.append(f'<text x="{L+k*140}" y="45" fill="{color}">{html.escape(name)}</text>')
    out += [f'<text x="{(W+L-R)/2}" y="{H-12}" text-anchor="middle">{html.escape(xlabel)}</text>',
            f'<text transform="translate(18,{H/2}) rotate(-90)" text-anchor="middle">{html.escape(ylabel)}</text>','</g></svg>']
    Path(path).parent.mkdir(parents=True,exist_ok=True)
    Path(path).write_text('\n'.join(out))


def load(name):return list(csv.DictReader(open(f'results/{name}.csv')))

def grouped_chart(rows,xkey,ykey,path,title,xlabel,ylabel,reverse=False):
    groups=defaultdict(list)
    for r in rows:groups[(r['method'],float(r[xkey]))].append(float(r[ykey]))
    series={m:sorted((x,median(v)) for (method,x),v in groups.items() if method==m) for m in ('set','bitset','spmf')}
    chart(path,title,xlabel,ylabel,{k:v for k,v in series.items() if v},reverse)


def main():
    rows=load('benchmark')
    for name in ('chess','mushrooms','retail','T10I4D100K'):
        subset=[r for r in rows if Path(r['input']).stem==name]
        for y,title,unit in [('wall_seconds','Runtime','seconds'),('patterns','Frequent itemsets','count'),('peak_rss_mib','Peak RSS','MiB')]:
            grouped_chart(subset,'minsup',y,f'results/charts/{name}_{y}.svg',f'{name}: {title}','minsup (decreasing)',unit,True)
    for source,xkey,title in [('scalability','transactions','Retail: scalability'),('width','width','Synthetic: transaction width')]:
        grouped_chart(load(source),xkey,'wall_seconds',f'results/charts/{source}.svg',title,xkey,'seconds')

if __name__=='__main__':main()
