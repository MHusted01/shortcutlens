"""Fail when line coverage of ShortcutLensCore sources is below a threshold.

Usage: python3 -I scripts/check-coverage.py <codecov.json> <min-percent>
The JSON is the llvm-cov export written by `swift test --enable-code-coverage`.
"""

import json
import sys
from pathlib import Path

SOURCE_MARKER = "/ShortcutLensCore/Sources/"


def load_source_files(report_path: Path) -> list[dict]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    files = report["data"][0]["files"]
    return [entry for entry in files if SOURCE_MARKER in entry["filename"]]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    report_path = Path(argv[1])
    threshold = float(argv[2])
    if not report_path.is_file():
        print(f"error: coverage report not found: {report_path}", file=sys.stderr)
        return 2

    files = load_source_files(report_path)
    if not files:
        print("error: no ShortcutLensCore sources in coverage report", file=sys.stderr)
        return 2

    total = sum(entry["summary"]["lines"]["count"] for entry in files)
    covered = sum(entry["summary"]["lines"]["covered"] for entry in files)
    for entry in files:
        lines = entry["summary"]["lines"]
        name = entry["filename"].split(SOURCE_MARKER, 1)[1]
        print(f"{lines['percent']:6.1f}%  {name}")

    percent = 100.0 * covered / total if total else 100.0
    print(f"Total line coverage: {percent:.1f}% (minimum {threshold:.0f}%)")
    if percent < threshold:
        print("error: coverage below minimum", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
