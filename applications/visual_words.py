"""Bag of Visual Words dùng dense SIFT + KMeans; FIM được chạy trong Julia."""
from __future__ import annotations

import cv2
import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.datasets import load_digits
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split

SEED = 42


def prepare_images(classes: tuple[int, ...] = (0, 1, 3, 8), seed: int = SEED):
    """UCI Digits (qua scikit-learn): chia train/test trước khi học codebook."""
    digits = load_digits()
    indices = np.flatnonzero(np.isin(digits.target, classes))
    train_ids, test_ids = train_test_split(
        indices, test_size=0.25, stratify=digits.target[indices], random_state=seed
    )
    return digits.images[train_ids], digits.images[test_ids], digits.target[train_ids], digits.target[test_ids]


def descriptors_for_image(image: np.ndarray) -> np.ndarray:
    """Phóng ảnh 8x8 -> 96x96 và tính SIFT trên lưới cố định 4x4.

    Dense sampling được chọn thay cho SIFT.detect để không mất các ảnh nét ít,
    đồng thời đảm bảo số đặc trưng ổn định giữa những lần chạy.
    """
    data = np.clip(image.astype(np.float32) * (255.0 / 16.0), 0, 255).astype(np.uint8)
    resized = cv2.resize(data, (96, 96), interpolation=cv2.INTER_CUBIC)
    sift = cv2.SIFT_create()
    positions = (16, 36, 56, 76)
    keypoints = [cv2.KeyPoint(float(x), float(y), 16) for y in positions for x in positions]
    _, descriptors = sift.compute(resized, keypoints)
    if descriptors is None or len(descriptors) == 0:
        raise RuntimeError('Không tạo được dense SIFT descriptors.')
    return descriptors.astype(np.float32)


def extract_descriptors(images: np.ndarray) -> list[np.ndarray]:
    return [descriptors_for_image(image) for image in images]


def create_codebook(train_features: list[np.ndarray], n_words: int = 24, seed: int = SEED) -> KMeans:
    """Chỉ train codebook từ train images (tránh rò rỉ thông tin test)."""
    stacked = np.vstack(train_features)
    model = KMeans(n_clusters=n_words, random_state=seed, n_init=5, max_iter=150)
    model.fit(stacked)
    return model


def to_visual_transactions(feature_list: list[np.ndarray], model: KMeans) -> list[list[int]]:
    """Mỗi ảnh -> 1 giao dịch chứa ID visual words (tập hợp, không số đếm)."""
    result = []
    for descriptors in feature_list:
        # +1: chỉ số item trên SPMF bắt đầu từ 1.
        words = sorted(set((model.predict(descriptors) + 1).tolist()))
        result.append(words)
    return result


def to_binary_features(transactions: list[list[int]], n_words: int) -> np.ndarray:
    features = np.zeros((len(transactions), n_words), dtype=np.float32)
    for row, words in enumerate(transactions):
        for word in words:
            features[row, word - 1] = 1
    return features


def select_patterns(itemsets: dict[frozenset[int], int], max_patterns: int = 100) -> list[frozenset[int]]:
    """Lọc các pattern dài >= 2; ưu tiên dài vừa, support tốt.

    Chỉ chọn dựa trên itemsets của TRAIN, không dùng nhãn hay dữ liệu TEST.
    """
    candidates = [(items, count) for items, count in itemsets.items() if len(items) >= 2]
    candidates.sort(key=lambda p: (-p[1], len(p[0]), tuple(sorted(p[0]))))
    return [items for items, _ in candidates[:max_patterns]]


def encode_pattern_features(transactions: list[list[int]], patterns: list[frozenset[int]]) -> np.ndarray:
    matrix = np.zeros((len(transactions), len(patterns)), dtype=np.float32)
    for idx, tx in enumerate(transactions):
        current = set(tx)
        for j, pattern in enumerate(patterns):
            matrix[idx, j] = 1.0 if pattern.issubset(current) else 0.0
    return matrix


def pattern_enrichment(
    transactions: list[list[int]], labels: np.ndarray,
    itemsets: dict[frozenset[int], int], min_count: int = 10,
) -> pd.DataFrame:
    """Kiểm tra pattern phân biệt nhãn nào trên TRAIN (không gắn nhãn khi FIM).

    enrichment(P, C) = P(P | class=C) / P(P), không phải confidence của luật.
    """
    tx_sets = [set(tx) for tx in transactions]
    n = len(transactions)
    rows = []
    for itemset, count in itemsets.items():
        if len(itemset) < 2 or count < min_count:
            continue
        mask = np.asarray([itemset.issubset(tx) for tx in tx_sets], dtype=bool)
        for label in sorted(set(labels.tolist())):
            class_mask = labels == label
            matching = int(np.sum(mask & class_mask))
            prevalence = float(mask.mean())
            class_prevalence = float(mask[class_mask].mean())
            rows.append({
                'visual_words': ' + '.join(f'W{i}' for i in sorted(itemset)),
                'digit': int(label), 'count': matching,
                'support': prevalence, 'support_in_class': class_prevalence,
                'enrichment': class_prevalence / prevalence if prevalence else 0,
            })
    if not rows:
        return pd.DataFrame(columns=['visual_words', 'digit', 'count', 'support', 'support_in_class', 'enrichment'])
    frame = pd.DataFrame(rows)
    frame = frame[frame['count'] >= max(2, min_count // 2)]
    return frame.sort_values(['enrichment', 'count'], ascending=[False, False]).reset_index(drop=True)


def compare_classifiers(
    train_tx: list[list[int]], test_tx: list[list[int]],
    train_y: np.ndarray, test_y: np.ndarray,
    patterns: list[frozenset[int]], n_words: int, seed: int = SEED,
) -> tuple[pd.DataFrame, dict]:
    """Giữ cùng cách chia tập, chỉ học trên TRAIN, đánh giá trên TEST."""
    base_train = to_binary_features(train_tx, n_words)
    base_test = to_binary_features(test_tx, n_words)
    enriched_train = np.hstack([base_train, encode_pattern_features(train_tx, patterns)])
    enriched_test = np.hstack([base_test, encode_pattern_features(test_tx, patterns)])
    rows = []
    reports = {}
    for name, x_train, x_test in [
        ('Visual words', base_train, base_test),
        ('Visual words + frequent patterns', enriched_train, enriched_test),
    ]:
        classifier = LogisticRegression(max_iter=1500, random_state=seed)
        classifier.fit(x_train, train_y)
        predicted = classifier.predict(x_test)
        rows.append({'representation': name, 'n_features': x_train.shape[1], 'test_accuracy': accuracy_score(test_y, predicted)})
        reports[name] = classification_report(test_y, predicted, output_dict=True, zero_division=0)
    return pd.DataFrame(rows), reports
