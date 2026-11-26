"""Chuyển dữ liệu Groceries -> giao dịch và sinh luật từ itemsets negFIN."""
from __future__ import annotations

import csv
import itertools
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

GROCERIES_SOURCE = (
    'https://raw.githubusercontent.com/Elthiero/'
    'association-rule-learning-groceries/main/data/groceries.csv'
)


def get_groceries_csv(path: Path, url: str = GROCERIES_SOURCE) -> Path:
    path = Path(path)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            urllib.request.urlretrieve(url, path)
        except Exception as exc:
            raise RuntimeError(
                'Không tải được Groceries. Dùng Colab có Internet hoặc tải '
                f'Groceries.csv từ {url}, đặt ở {path}.'
            ) from exc
    return path


def load_groceries(path: Path) -> list[list[str]]:
    """Đọc CSV không tiêu đề; loại ô rỗng, loại trùng item trong 1 hóa đơn."""
    transactions = []
    with Path(path).open(encoding='utf-8-sig', newline='') as handle:
        for row in csv.reader(handle):
            names = sorted({name.strip() for name in row if name.strip()})
            if names:
                transactions.append(names)
    if not transactions:
        raise ValueError('Không có hóa đơn trong file dữ liệu.')
    return transactions


def encode_baskets(baskets: list[list[str]]) -> tuple[list[list[int]], dict[int, str]]:
    vocabulary = sorted({name for basket in baskets for name in basket})
    lookup = {name: i + 1 for i, name in enumerate(vocabulary)}
    numeric = [[lookup[name] for name in basket] for basket in baskets]
    reverse = {i: name for name, i in lookup.items()}
    return numeric, reverse


@dataclass(frozen=True)
class Rule:
    antecedent: tuple[int, ...]
    consequent: tuple[int, ...]
    support_count: int
    support: float
    confidence: float
    lift: float
    leverage: float


def association_rules(
    itemsets: dict[frozenset[int], int],
    n_transactions: int,
    minconf: float = 0.15,
    min_support: float = 0.01,
) -> list[Rule]:
    """Sinh mọi luật X -> Y từ FIS, với X ∩ Y = ∅ và Y ≠ ∅.

    support(X ∪ Y) = số hóa đơn chứa cả X và Y / N.
    confidence = support(X ∪ Y) / support(X).
    lift = confidence / support(Y).
    """
    if n_transactions <= 0 or not (0 <= minconf <= 1) or not (0 < min_support <= 1):
        raise ValueError('Tham số sinh luật không hợp lệ.')
    rules = []
    for combined, count in itemsets.items():
        if len(combined) < 2 or count / n_transactions < min_support:
            continue
        values = sorted(combined)
        for size in range(1, len(values)):
            for left in itertools.combinations(values, size):
                left_set = frozenset(left)
                right_set = combined - left_set
                left_support = itemsets.get(left_set)
                right_support = itemsets.get(right_set)
                if not left_support or not right_support:
                    # Tập con của itemset phổ biến vẫn phải phổ biến.
                    raise ValueError('Thiếu support của tập con, kiểm tra lại kết quả negFIN.')
                conf = count / left_support
                if conf < minconf:
                    continue
                lift = conf / (right_support / n_transactions)
                rules.append(Rule(
                    tuple(left), tuple(sorted(right_set)), count, count / n_transactions,
                    conf, lift, count / n_transactions
                    - (left_support / n_transactions) * (right_support / n_transactions),
                ))
    return sorted(
        rules,
        key=lambda r: (-r.lift, -r.confidence, -r.support_count, r.antecedent, r.consequent),
    )


def rules_frame(rules: list[Rule], vocab: dict[int, str]) -> pd.DataFrame:
    return pd.DataFrame([
        {
            'antecedent': ' + '.join(vocab[i] for i in r.antecedent),
            'consequent': ' + '.join(vocab[i] for i in r.consequent),
            'support_count': r.support_count,
            'support': r.support,
            'confidence': r.confidence,
            'lift': r.lift,
            'leverage': r.leverage,
        }
        for r in rules
    ], columns=['antecedent', 'consequent', 'support_count', 'support', 'confidence', 'lift', 'leverage'])


def describe_business_rule(row: pd.Series) -> str:
    return (
        f"Khi giỏ hàng có [{row['antecedent']}], xác suất quan sát thấy "
        f"[{row['consequent']}] là {row['confidence']:.1%}, cao gấp "
        f"{row['lift']:.2f} lần mức xuất hiện chung của vế phải. "
        'Có thể thử đề xuất mua kèm hoặc bố trí nhóm hàng gần nhau; '
        'đây là tương quan, chưa chứng minh tác động nhân quả hay lợi nhuận.'
    )
