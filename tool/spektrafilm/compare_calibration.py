"""Compare native Spektrafilm output with the upstream reference dump.

    python -I R:/Zync/tool/spektrafilm/compare_calibration.py \
        R:/third_party/build/calibration_native.tsv
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def load_reference():
    data = json.loads((ROOT / "tool/spektrafilm/reference_calibration.json").read_text(encoding="utf-8"))
    rows = {}
    for row in data["rows"]:
        if "rgb" in row:
            rows[(row["stock"], row["patch"])] = row["rgb"]
    return rows


def load_native(path):
    rows = {}
    for line in pathlib.Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        stock, _paper, _scan, patch = parts[:4]
        rows[(stock, patch)] = [float(v) for v in parts[-3:]]
    return rows


def main():
    native_path = sys.argv[1] if len(sys.argv) > 1 else "R:/third_party/build/calibration_native.tsv"
    reference = load_reference()
    native = load_native(native_path)
    common = sorted(set(reference) & set(native))
    if not common:
        print("no overlapping rows")
        return 1

    per_stock = {}
    for key in common:
        ref = reference[key]
        got = native[key]
        error = max(abs(ref[i] - got[i]) for i in range(3))
        mean = sum(abs(ref[i] - got[i]) for i in range(3)) / 3.0
        stock, patch = key
        entry = per_stock.setdefault(stock, {"max": 0.0, "mean": 0.0, "count": 0, "worst": ("", 0.0)})
        entry["count"] += 1
        entry["mean"] += mean
        if error > entry["max"]:
            entry["max"] = error
            entry["worst"] = (patch, error)

    print(f"{'stock':32} {'patches':>7} {'mean':>8} {'max':>8}  worst")
    for stock in sorted(per_stock, key=lambda s: -per_stock[s]["max"]):
        entry = per_stock[stock]
        mean = entry["mean"] / entry["count"]
        patch, error = entry["worst"]
        print(f"{stock:32} {entry['count']:7d} {mean:8.4f} {error:8.4f}  {patch}")

    worst = max((e["max"] for e in per_stock.values()), default=0.0)
    mean_all = sum(e["mean"] / e["count"] for e in per_stock.values()) / len(per_stock)
    print(f"\noverall max {worst:.4f}  mean {mean_all:.4f}  stocks {len(per_stock)}  rows {len(common)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
