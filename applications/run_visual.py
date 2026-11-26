"""Ứng dụng 2: Bag of Visual Words trên UCI Digits; frequent patterns lấy từ Julia negFIN.
Chạy tại repo root: python -m applications.run_visual
"""
from __future__ import annotations

import argparse
import json

import matplotlib.pyplot as plt
import numpy as np

from applications.common import ROOT, run_negfin, save_transactions
from applications.visual_words import (
    SEED, compare_classifiers, create_codebook, encode_pattern_features,
    extract_descriptors, pattern_enrichment, prepare_images,
    select_patterns, to_visual_transactions,
)


def execute(minsup: float = 0.08, n_words: int = 24) -> dict:
    np.random.seed(SEED)
    output = ROOT / 'results' / 'chapter3' / 'visual_words'
    output.mkdir(parents=True, exist_ok=True)
    train_x, test_x, train_y, test_y = prepare_images()
    train_features = extract_descriptors(train_x)
    test_features = extract_descriptors(test_x)
    kmeans = create_codebook(train_features, n_words=n_words)
    train_tx = to_visual_transactions(train_features, kmeans)
    test_tx = to_visual_transactions(test_features, kmeans)
    save_transactions(train_tx, output / 'train_transactions.spmf')
    save_transactions(test_tx, output / 'test_transactions.spmf')
    itemsets = run_negfin(
        output / 'train_transactions.spmf',
        output / 'train_frequent_itemsets.spmf', min_support=minsup,
    )
    # Đối chiếu support trả về với giao dịch train thực tế.
    for itemset, declared in itemsets.items():
        observed = sum(itemset.issubset(tx) for tx in train_tx)
        if observed != declared:
            raise AssertionError(f'Support lỗi: {itemset}, {declared} vs {observed}')

    patterns = select_patterns(itemsets, max_patterns=100)
    enrichment = pattern_enrichment(train_tx, train_y, itemsets, min_count=10)
    enrichment.to_csv(output / 'patterns_by_class.csv', index=False, encoding='utf-8-sig')
    evaluation, _ = compare_classifiers(train_tx, test_tx, train_y, test_y, patterns, n_words)
    evaluation.to_csv(output / 'test_accuracy_comparison.csv', index=False, encoding='utf-8-sig')
    (output / 'selected_patterns.json').write_text(
        json.dumps([sorted(p) for p in patterns], ensure_ascii=False, indent=2), encoding='utf-8'
    )

    fig, axes = plt.subplots(2, 5, figsize=(10, 4))
    for ax, img, label in zip(axes.flat, test_x[:10], test_y[:10]):
        ax.imshow(img, cmap='gray_r', interpolation='nearest')
        ax.set_title(f'Digit {label}')
        ax.axis('off')
    fig.tight_layout()
    fig.savefig(output / 'sample_digits.png', dpi=160)
    plt.close(fig)

    if len(enrichment):
        # Đánh giá mức độ giàu tính đặc trưng theo từng nhãn (trên train).
        top_enriched = enrichment.head(15).iloc[::-1]
        fig, ax = plt.subplots(figsize=(10, 6))
        ax.barh(
            [f"Digit {r.digit}: {r.visual_words}" for r in top_enriched.itertuples()],
            top_enriched['enrichment'],
        )
        ax.set(xlabel='P(pattern | class) / P(pattern)', title='Most class-enriched frequent visual patterns')
        fig.tight_layout()
        fig.savefig(output / 'enriched_patterns.png', dpi=150, bbox_inches='tight')
        plt.close(fig)

    metrics = {
        'dataset': 'UCI optical recognition handwritten digits (via sklearn.datasets.load_digits)',
        'classes': [0, 1, 3, 8], 'seed': SEED,
        'train_images': len(train_tx), 'test_images': len(test_tx),
        'visual_words': n_words, 'dense_sift_per_image': len(train_features[0]),
        'minsup': minsup, 'train_frequent_itemsets': len(itemsets),
        'selected_patterns': len(patterns), 'support_validation': 'PASS',
        'test_results': evaluation.to_dict(orient='records'),
    }
    (output / 'summary.json').write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding='utf-8')
    print('\nTỔNG KẾT:\n', json.dumps(metrics, indent=2, ensure_ascii=False))
    print('\nSO SÁNH ĐỘ CHÍNH XÁC (TRAIN/TEST CỐ ĐỊNH):\n', evaluation.to_string(index=False))
    print('\nTOP 10 VISUAL PATTERN THEO CLASS-ENRICHMENT:\n', enrichment.head(10).to_string(index=False))
    print('\nLƯU Ý: visual word là centroid SIFT, không phải một bộ phận hình ảnh được gán nhãn thủ công.')
    return {'metrics': metrics, 'evaluation': evaluation, 'enrichment': enrichment, 'work_dir': output}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--minsup', type=float, default=0.08)
    parser.add_argument('--words', type=int, default=24)
    args = parser.parse_args()
    execute(args.minsup, args.words)


if __name__ == '__main__':
    main()
