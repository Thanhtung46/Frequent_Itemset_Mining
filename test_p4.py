"""Chạy test P4 và lưu báo cáo. Dùng --with-data khi đã có kit train BTC."""
import argparse
import importlib
import json
import os
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

UNIT_MODULES = [
    "tests.test_time_resolver", "tests.test_itn", "tests.test_eval_params",
    "tests.test_p4_regressions", "tests.test_router", "tests.test_parsing",
    "tests.test_asr_metrics",
]
DATA_MODULES = ["tests.test_param_normalizer", "tests.test_retriever"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--with-data", action="store_true")
    parser.add_argument("--data", type=Path, help="thư mục chứa train/")
    parser.add_argument("--report", type=Path, default=Path("results/runs/p4_tests/report.json"))
    options = parser.parse_args()
    if options.data:
        os.environ["LIFEMATE_DATA"] = str(options.data.resolve())
    modules = list(UNIT_MODULES)
    if options.with_data:
        from infra import config
        required = [config.split_dir("train") / "train.jsonl",
                    config.catalog_path("train"),
                    config.split_dir("train") / "zaic_tools",
                    config.split_dir("train") / "train_environment",
                    config.DEV_IDS, config.REPO / "configs/train_ids.txt"]
        missing = [str(path) for path in required if not path.exists()]
        if missing:
            parser.error("Thiếu kit train hoặc split:\n" + "\n".join(missing))
        modules.extend(DATA_MODULES)

    suite = unittest.TestSuite()
    for name in modules:
        suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(importlib.import_module(name)))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "mode": "unit_and_official_train" if options.with_data else "unit_and_synthetic",
        "modules": modules,
        "tests": result.testsRun,
        "failures": len(result.failures),
        "errors": len(result.errors),
        "skipped": len(result.skipped),
        "passed": result.wasSuccessful(),
        "model_evaluation": "not_run",
    }
    options.report.parent.mkdir(parents=True, exist_ok=True)
    options.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Report: {options.report}")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
