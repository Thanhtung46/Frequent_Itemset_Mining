"""I/O định dạng SPMF và cầu nối negFIN (không cài đặt thuật toán FIM)."""
from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]


def save_transactions(transactions: Iterable[Iterable[int]], output_path: Path) -> int:
    """1 giao dịch / dòng; item ID dương, không trùng nhau trong giao dịch."""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with output_path.open('w', encoding='utf-8', newline='\n') as handle:
        for transaction in transactions:
            items = sorted(set(int(item) for item in transaction))
            if not items or items[0] < 1:
                raise ValueError('Mỗi giao dịch phải chứa các item ID nguyên dương.')
            handle.write(' '.join(map(str, items)) + '\n')
            count += 1
    if not count:
        raise ValueError('Không có giao dịch hợp lệ.')
    return count


def parse_itemsets(output_path: Path) -> dict[frozenset[int], int]:
    """Đọc và kiểm tra dạng '1 3 5 #SUP: 42' do negFIN xuất."""
    path = Path(output_path)
    result: dict[frozenset[int], int] = {}
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if not line.strip():
            continue
        match = re.fullmatch(r'\s*(\d+(?:\s+\d+)*)\s+#SUP:\s*(\d+)\s*', line)
        if not match:
            raise ValueError(f'SPMF output không hợp lệ tại dòng {line_no}: {line[:120]}')
        numbers = [int(x) for x in match.group(1).split()]
        key = frozenset(numbers)
        support = int(match.group(2))
        if len(key) != len(numbers) or support < 1:
            raise ValueError(f'Itemset/support không hợp lệ tại dòng {line_no}')
        if key in result and result[key] != support:
            raise ValueError(f'Support mâu thuẫn tại dòng {line_no}')
        result[key] = support
    return result


def find_julia() -> str:
    command = os.environ.get('JULIA_BIN', 'julia')
    found = shutil.which(command)
    if not found:
        raise RuntimeError(
            'Không tìm thấy Julia. Cài Julia >= 1.9, thêm julia vào PATH '
            'hoặc đặt biến JULIA_BIN trỏ tới julia.exe / julia.'
        )
    return found


def run_negfin(input_path: Path, output_path: Path, min_support: float, timeout: int = 1800) -> dict[frozenset[int], int]:
    """BẮT BUỘC chạy thuật toán của nhóm trong src/negfin_baseline.jl."""
    if min_support <= 0:
        raise ValueError('min_support phải dương.')
    executable = find_julia()
    cmd = [
        executable, '--startup-file=no', f'--project={ROOT}', str(ROOT / 'src' / 'application_mining.jl'),
        '--input', str(Path(input_path).resolve()),
        '--output', str(Path(output_path).resolve()),
        '--minsup', str(min_support),
    ]
    outcome = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout, check=False)
    if outcome.returncode:
        raise RuntimeError(
            'negFIN (Julia) thất bại, KHÔNG thay bằng thuật toán từ thư viện khác.\n'
            f'STDOUT:\n{outcome.stdout[-3500:]}\nSTDERR:\n{outcome.stderr[-5000:]}'
        )
    print(outcome.stdout.strip())
    if not Path(output_path).exists():
        raise FileNotFoundError('Julia không tạo file itemset đầu ra.')
    return parse_itemsets(output_path)
