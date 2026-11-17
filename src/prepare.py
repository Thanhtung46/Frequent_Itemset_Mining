"""Download official data with bounded timeouts; record exact hashes.
If network unavailable, use already bundled files or download manually.
"""
import hashlib,json,subprocess,zipfile
from pathlib import Path
SOURCES={
'data/benchmark/chess.txt':'https://www.philippe-fournier-viger.com/spmf/publicdatasets/chess.txt',
'data/benchmark/mushrooms.txt':'https://www.philippe-fournier-viger.com/spmf/publicdatasets/mushrooms.txt',
'data/benchmark/retail.txt':'https://www.philippe-fournier-viger.com/spmf/publicdatasets/retail.txt',
'data/benchmark/T10I4D100K.txt':'https://www.philippe-fournier-viger.com/spmf/publicdatasets/T10I4D100K.txt',
'tools/spmf.jar':'https://www.philippe-fournier-viger.com/spmf/spmf2.64.jar',
'data/raw/splice.zip':'https://archive.ics.uci.edu/static/public/69/molecular+biology+splice+junction+gene+sequences.zip'}


def main():
    manifest=[]
    for name,url in SOURCES.items():
        path=Path(name);path.parent.mkdir(parents=True,exist_ok=True)
        if not path.exists():
            subprocess.run(['curl','-fL','--retry','2','--max-time','90',url,'-o',str(path)],check=True)
        if path.read_bytes().lstrip().startswith(b'<html'):
            raise ValueError(f'{name}: downloaded HTML instead of data; remove and retry')
        manifest.append(dict(path=name,url=url,size=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    with zipfile.ZipFile('data/raw/splice.zip') as z:
        for name in ('splice.data','splice.names'):
            Path('data/raw',name).write_bytes(z.read(name))
    Path('data/source_manifest.json').write_text(json.dumps(manifest,indent=2))
    print('Prepared data and pinned SPMF 2.64b. Check Java with java -version.')

if __name__=='__main__':main()
