import argparse
import json
import time
from pathlib import Path
from .algorithm.eclat import eclat, minimum_count
from .io_utils import read_transactions


def main():
    parser = argparse.ArgumentParser(description='Eclat: tat ca frequent itemset + support')
    parser.add_argument('input')
    parser.add_argument('output')
    parser.add_argument('--backend', choices=['set','bitset'], default='bitset')
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument('--minsup')
    g.add_argument('--min-count', type=int)
    args = parser.parse_args()
    transactions = read_transactions(args.input)
    threshold = args.min_count if args.min_count is not None else minimum_count(args.minsup, len(transactions))
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    count = 0
    # Stream output, khong giu toan bo patterns trong RAM khi benchmark.
    with open(args.output, 'w') as f:
        for items, support in eclat(transactions, threshold, args.backend):
            f.write(' '.join(map(str, items)) + f' #SUP: {support}\n')
            count += 1
    print(json.dumps(dict(transactions=len(transactions), min_count=threshold,
                         patterns=count, mining_and_write_seconds=time.perf_counter()-start)))

if __name__ == '__main__':
    main()
