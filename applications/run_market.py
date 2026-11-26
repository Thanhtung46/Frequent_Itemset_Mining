"""Ứng dụng 1: Market Basket Analysis trên Groceries thực, dùng negFIN Julia.
Chạy tại repo root: python -m applications.run_market
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

import matplotlib.pyplot as plt

from applications.common import ROOT, run_negfin, save_transactions
from applications.market_basket import (
    association_rules, describe_business_rule, encode_baskets, get_groceries_csv,
    load_groceries, rules_frame,
)


def execute(minsup: float = 0.01, minconf: float = 0.15, raw_csv: Path | None = None) -> dict:
    source = get_groceries_csv(raw_csv or (ROOT / 'data' / 'application' / 'groceries.csv'))
    baskets = load_groceries(source)
    numeric_tx, reverse = encode_baskets(baskets)
    work = ROOT / 'results' / 'chapter3' / 'market_basket'
    work.mkdir(parents=True, exist_ok=True)
    input_file = work / 'transactions.spmf'
    output_file = work / 'frequent_itemsets.spmf'
    save_transactions(numeric_tx, input_file)
    itemsets = run_negfin(input_file, output_file, min_support=minsup)
    tx_sets = [set(tx) for tx in numeric_tx]
    # Kiểm chứng trực tiếp số lần xuất hiện của itemsets đã trả về.
    for itemset, declared in itemsets.items():
        observed = sum(itemset.issubset(tx) for tx in tx_sets)
        if observed != declared:
            raise AssertionError(f'Support lỗi {itemset}: negFIN={declared}, đếm thực={observed}')
    rules = association_rules(itemsets, len(baskets), minconf, min_support=minsup)
    frame = rules_frame(rules, reverse)
    frame.to_csv(work / 'association_rules.csv', index=False, encoding='utf-8-sig')
    frame.head(10).to_csv(work / 'top10_by_lift.csv', index=False, encoding='utf-8-sig')
    (work / 'item_mapping.json').write_text(json.dumps(reverse, indent=2, ensure_ascii=False), encoding='utf-8')

    top_counts = Counter(name for basket in baskets for name in basket).most_common(12)
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.barh([name for name, _ in top_counts][::-1], [count for _, count in top_counts][::-1])
    ax.set(xlabel='Number of baskets', title='Groceries: most common products')
    fig.tight_layout()
    fig.savefig(work / 'top_products.png', dpi=150)
    plt.close(fig)
    if not frame.empty:
        top = frame.head(10).iloc[::-1]
        labels = [f"{a} -> {b}" for a, b in zip(top['antecedent'], top['consequent'])]
        fig, ax = plt.subplots(figsize=(11, 6))
        ax.barh(labels, top['lift'])
        ax.set(xlabel='Lift', title=f'Top 10 association rules (minsup={minsup}, minconf={minconf})')
        fig.tight_layout()
        fig.savefig(work / 'top10_lift.png', dpi=150, bbox_inches='tight')
        plt.close(fig)

    metrics = {
        'dataset': 'Groceries (arules, real POS transactions)',
        'transactions': len(baskets), 'distinct_products': len(reverse),
        'minsup': minsup, 'minconf': minconf,
        'frequent_itemsets': len(itemsets), 'association_rules': len(rules),
        'top10_rule_count': min(10, len(rules)),
        'support_validation': 'PASS',
        'source': str(source),
    }
    (work / 'summary.json').write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding='utf-8')
    print('\nTỔNG KẾT:', json.dumps(metrics, ensure_ascii=False, indent=2))
    if not frame.empty:
        print('\nTOP 10 THEO LIFT:')
        print(frame.head(10).to_string(index=False, float_format=lambda x: f'{x:.3f}'))
        print('\nDIỄN GIẢI 3 LUẬT ĐỨNG ĐẦU:')
        for _, row in frame.head(3).iterrows():
            print('-', describe_business_rule(row))
    return {'metrics': metrics, 'rules': frame, 'work_dir': work, 'baskets': baskets, 'mapping': reverse}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--minsup', type=float, default=0.01)
    parser.add_argument('--minconf', type=float, default=0.15)
    parser.add_argument('--csv', type=Path, default=None, help='Tùy chọn: đường dẫn Groceries.csv đã tải về')
    args = parser.parse_args()
    execute(args.minsup, args.minconf, args.csv)


if __name__ == '__main__':
    main()
