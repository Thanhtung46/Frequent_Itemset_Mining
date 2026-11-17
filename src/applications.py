"""Hai ung dung dung chinh Eclat cua du an; khong dung thu vien FIM."""
import csv,json
from collections import Counter
from pathlib import Path
from .algorithm.eclat import eclat, minimum_count
from .io_utils import read_transactions,write_transactions
from .rules import association_rules
from .experiments import save_csv


def basket():
    rows=read_transactions('data/benchmark/retail.txt')
    patterns=dict(eclat(rows,minimum_count('0.001',len(rows)),'bitset'))
    rules=sorted(association_rules(patterns,len(rows),0.6),
                 key=lambda r:(-r['lift'],-r['confidence'],-r['count'],r['antecedent'],r['consequent']))
    save_csv('results/basket_top10.csv',rules[:10])
    Path('results/basket_summary.json').write_text(json.dumps(dict(
        transactions=len(rows),minsup=.001,minconf=.6,patterns=len(patterns),rules=len(rules),
        note='Retail has anonymous item IDs. Do not invent product names or infer causal sales gains.'),indent=2))
    return rules[:10]


def prepare_dna(path='data/raw/splice.data'):
    rows=[];labels=[];counts=Counter();mapping={}
    # UCI: 60 bases, splice site between positions 30 and 31.
    # Keep positions 25..36: six bases on each side; position is retained.
    for line in Path(path).read_text().splitlines():
        if not line.strip():continue
        label,name,seq=line.split(',',2)
        label=label.strip();seq=''.join(seq.upper().split())
        counts['raw']+=1
        if len(seq)!=60 or label not in ('EI','IE','N'):
            counts['invalid']+=1;continue
        window=seq[24:36]
        # Ambiguous base in selected window: drop and disclose.
        if any(b not in 'ACGT' for b in window):
            counts['ambiguous_window']+=1;continue
        transaction=[]
        for pos,base in enumerate(window):
            item=pos*4+'ACGT'.index(base)+1
            offset=pos-6 if pos<6 else pos-5
            mapping[str(item)]=f'{offset:+d}:{base}'
            transaction.append(item)
        rows.append(tuple(transaction));labels.append(label)
    counts['retained']=len(rows)
    write_transactions('data/processed/dna.txt',rows)
    Path('data/processed/dna_labels.json').write_text(json.dumps(labels))
    Path('data/processed/dna_items.json').write_text(json.dumps(mapping,indent=2))
    return rows,labels,mapping,counts


def biology():
    rows,labels,mapping,quality=prepare_dna()
    patterns=dict(eclat(rows,minimum_count('0.05',len(rows)),'bitset'))
    classes=Counter(labels);results=[]
    # Class labels never become mining items. Descriptive post-hoc enrichment only.
    for pattern,count in patterns.items():
        if len(pattern)<2:continue
        support_by_class=Counter(label for row,label in zip(rows,labels) if set(pattern)<=set(row))
        for label in sorted(classes):
            in_class=support_by_class[label]
            class_support=in_class/classes[label]
            enrichment=class_support/(count/len(rows))
            results.append(dict(pattern=' '.join(mapping[str(i)] for i in pattern),
                                items=' '.join(map(str,pattern)),length=len(pattern),count=count,
                                support=count/len(rows),label=label,class_count=in_class,
                                class_total=classes[label],class_support=class_support,
                                enrichment=enrichment))
    results.sort(key=lambda r:(-r['enrichment'],-r['class_count'],r['pattern'],r['label']))
    save_csv('results/dna_patterns.csv',results)
    save_csv('results/dna_top10.csv',results[:10])
    Path('results/dna_summary.json').write_text(json.dumps(dict(
        quality=dict(quality),classes=dict(classes),minsup=.05,patterns=len(patterns),
        encoding='Position-specific DNA bases, window -6..-1,+1..+6; labels excluded',
        interpretation='Exploratory co-occurrence, not causal biology or validated predictor'),indent=2))
    return results[:10]

if __name__=='__main__':
    print('Basket:',basket(),flush=True)
    print('DNA:',biology(),flush=True)
