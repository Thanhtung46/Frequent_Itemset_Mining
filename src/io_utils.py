from pathlib import Path


def read_transactions(path):
    result = []
    for no, line in enumerate(Path(path).read_text(encoding='utf-8-sig').splitlines(), 1):
        line = line.strip()
        if not line or line[0] in '#%@':
            continue
        try:
            values = [int(x) for x in line.split()]
        except ValueError as exc:
            raise ValueError(f'{path}: dong {no} khong phai transaction FIM') from exc
        if any(x < 0 for x in values):
            raise ValueError(f'Dong {no}: khong chap nhan -1/-2 cua sequence format')
        result.append(tuple(sorted(set(values))))
    return result


def write_transactions(path, rows):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as f:
        for row in rows:
            if not row:
                raise ValueError('Khong ghi transaction rong: SPMF bo qua dong trong')
            f.write(' '.join(map(str, sorted(set(row)))) + '\n')


def read_patterns(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        if not line.strip() or line.startswith(('#', '%', '@')):
            continue
        left, right = line.split('#SUP:')
        key = tuple(sorted(map(int, left.split())))
        if key in result:
            raise ValueError('Ket qua chua itemset lap')
        result[key] = int(right.strip())
    return result


def compare_patterns(actual, reference):
    keys = set(actual) | set(reference)
    matches = sum(k in actual and k in reference and actual[k] == reference[k] for k in keys)
    return dict(actual_count=len(actual), reference_count=len(reference),
                exact_matches=matches, union_count=len(keys),
                exact_ratio=matches / len(keys) if keys else 1.0,
                equal=actual == reference)
