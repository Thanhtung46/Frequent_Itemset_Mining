"""Unit tests của phần chuẩn bị dữ liệu / sinh luật / trích visual words.
Không giả vờ kiểm chứng negFIN nếu máy chưa cài Julia.
"""
import csv
from pathlib import Path

import numpy as np
import pytest

from applications.common import parse_itemsets, save_transactions
from applications.market_basket import association_rules, encode_baskets, load_groceries, rules_frame
from applications.visual_words import (
    compare_classifiers, descriptors_for_image, encode_pattern_features,
    pattern_enrichment, prepare_images, to_binary_features,
)


def test_spmf_roundtrip(tmp_path):
    inp = tmp_path / 'in.spmf'
    assert save_transactions([[3, 1, 3, 2], [2, 4]], inp) == 2
    assert inp.read_text().splitlines() == ['1 2 3', '2 4']
    out = tmp_path / 'out.spmf'
    out.write_text('1 #SUP: 3\n1 2 #SUP: 2\n', encoding='utf8')
    assert parse_itemsets(out) == {frozenset([1]): 3, frozenset([1, 2]): 2}
    out.write_text('1 2 #SUP: 2\n2 1 #SUP: 3\n', encoding='utf8')
    with pytest.raises(ValueError):
        parse_itemsets(out)


def test_groceries_parser(tmp_path):
    path = tmp_path / 'groceries.csv'
    with path.open('w', newline='', encoding='utf-8') as out:
        csv.writer(out).writerows([[' milk ', 'bread', '', 'milk'], ['bread', 'apples']])
    baskets = load_groceries(path)
    assert baskets == [['bread', 'milk'], ['apples', 'bread']]
    numeric, vocab = encode_baskets(baskets)
    assert len(vocab) == 3 and numeric == [[2, 3], [1, 2]]


def test_association_rules_exact_metrics():
    # {1} xuất hiện 3/4; {2} 3/4; {1,2} 2/4.
    sets = {frozenset([1]): 3, frozenset([2]): 3, frozenset([1, 2]): 2}
    rules = association_rules(sets, 4, minconf=0.5, min_support=0.5)
    assert len(rules) == 2
    assert rules[0].confidence == pytest.approx(2 / 3)
    assert rules[0].support == pytest.approx(0.5)
    assert rules[0].lift == pytest.approx(8 / 9)
    assert len(rules_frame(rules, {1: 'milk', 2: 'bread'})) == 2


def test_visual_features_no_label_in_transaction():
    images, _, labels, _ = prepare_images()
    sample = descriptors_for_image(images[0])
    assert sample.shape == (16, 128)
    assert set(np.unique(labels)).issubset({0, 1, 3, 8})
    txs = [[1, 2], [2, 3], [1, 3]]
    binary = to_binary_features(txs, 3)
    assert binary.shape == (3, 3)
    assert binary[0].tolist() == [1, 1, 0]
    features = encode_pattern_features(txs, [frozenset([1, 2]), frozenset([1, 3])])
    assert features.tolist() == [[1, 0], [0, 0], [0, 1]]


def test_enrichment_and_classifier_without_fim_library():
    txs = [[1, 2], [1, 3], [1, 2], [2, 3], [1, 3], [2, 3], [1, 2], [2, 3]]
    labels = np.array([0, 1, 0, 1, 1, 1, 0, 1])
    sets = {frozenset([1, 2]): 3, frozenset([2, 3]): 3}
    enriched = pattern_enrichment(txs, labels, sets, min_count=2)
    assert len(enriched) > 0
    scores, _ = compare_classifiers(txs, txs, labels, labels, [frozenset([1, 2])], 3)
    assert len(scores) == 2
    assert scores['test_accuracy'].between(0, 1).all()
