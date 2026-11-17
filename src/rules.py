from itertools import combinations


def association_rules(patterns, n, minconf=0.6):
    """Sinh tat ca luat A -> B, A/B khong rong va roi nhau."""
    if n <= 0 or not 0 <= minconf <= 1:
        raise ValueError('n > 0 va 0 <= minconf <= 1')
    for union, count in patterns.items():
        for length in range(1, len(union)):
            for left in combinations(union, length):
                right = tuple(i for i in union if i not in left)
                confidence = count / patterns[left]
                if confidence >= minconf:
                    yield dict(antecedent=left, consequent=right, count=count,
                               support=count/n, confidence=confidence,
                               lift=confidence/(patterns[right]/n))
