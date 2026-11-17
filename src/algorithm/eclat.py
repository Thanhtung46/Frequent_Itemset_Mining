"""Eclat tu viet: prefix classes + vertical tidsets (Zaki, 2000).
Khong dung hoac sao chep ma nguon SPMF. Python >= 3.10.
"""
from collections import defaultdict
from decimal import Decimal, ROUND_CEILING


def minimum_count(value, n):
    """0.4 hoac 40% la support tuong doi; count phai truyen rieng."""
    s = str(value).strip()
    q = Decimal(s[:-1]) / 100 if s.endswith('%') else Decimal(s)
    if not q.is_finite() or not 0 < q <= 1:
        raise ValueError('minsup phai thuoc (0, 1], hoac (0%, 100%].')
    return max(1, int((q * n).to_integral_value(rounding=ROUND_CEILING)))


def eclat(transactions, min_count, backend='set'):
    """Yield (tuple item tang dan, support count). Khong gioi han do dai.
    Cung thu tu duyet cho hai backend de tach tac dong cua bieu dien.
    Moi giao dich la mot set; giao dich giong nhau van duoc dem rieng.
    """
    if not isinstance(min_count, int) or isinstance(min_count, bool) or min_count < 1:
        raise ValueError('min_count phai la so nguyen duong')
    if backend not in ('set', 'bitset'):
        raise ValueError('backend phai la set hoac bitset')
    vertical = defaultdict(set)
    for tid, transaction in enumerate(transactions):
        for item in set(transaction):
            vertical[item].add(tid)
    candidates = [(i, tids) for i, tids in sorted(vertical.items())
                  if len(tids) >= min_count]
    if backend == 'bitset':
        # Tao bytearray truoc, tranh lien tuc OR so nguyen dai luc xay dung.
        def pack(tids):
            data = bytearray((max(tids) // 8) + 1)
            for t in tids:
                data[t // 8] |= 1 << (t % 8)
            return int.from_bytes(data, 'little')
        candidates = [(i, pack(t)) for i, t in candidates]
        size = int.bit_count
    else:
        size = len
    del vertical

    def visit(prefix, extensions):
        for pos, (item, tids) in enumerate(extensions):
            pattern = prefix + (item,)
            yield pattern, size(tids)
            children = []
            for j in range(pos + 1, len(extensions)):
                other, other_tids = extensions[j]
                common = tids & other_tids
                if size(common) >= min_count:
                    children.append((other, common))
            if children:
                yield from visit(pattern, children)
    yield from visit((), candidates)
