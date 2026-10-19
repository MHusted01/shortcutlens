"""Fail when line coverage of ShortcutLensCore sources is below a threshold.

Usage: python3 -I scripts/check-coverage.py <coverage.json> <min-percent>
The JSON is `xcrun xccov view --report --json` of the result bundle that
`make test` writes. A source linked into several targets is counted once,
with the target that covers most of its lines.
"""

import json
import sys
from pathlib import Path

SOURCE_MARKER = "/ShortcutLensCore/Sources/"


def load_source_files(report_path: Path) -> list[dict]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    files = {}
    for target in report["targets"]:
        for entry in target["files"]:
            path = entry["path"]
            if SOURCE_MARKER in path and entry["coveredLines"] >= files.get(path, {}).get("coveredLines", -1):
                files[path] = entry
    return sorted(files.values(), key=lambda entry: entry["path"])


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    report_path = Path(argv[1])
    threshold = float(argv[2])
    if not report_path.is_file():
        print(f"error: coverage report not found: {report_path}", file=sys.stderr)
        return 2

    try:
        files = load_source_files(report_path)
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"error: unexpected coverage report format: {error!r}", file=sys.stderr)
        return 2
    if not files:
        print("error: no ShortcutLensCore sources in coverage report", file=sys.stderr)
        return 2

    total = sum(entry["executableLines"] for entry in files)
    covered = sum(entry["coveredLines"] for entry in files)
    for entry in files:
        name = entry["path"].split(SOURCE_MARKER, 1)[1]
        print(f"{100.0 * entry['lineCoverage']:6.1f}%  {name}")

    percent = 100.0 * covered / total if total else 100.0
    print(f"Total line coverage: {percent:.1f}% (minimum {threshold:.0f}%)")
    if percent < threshold:
        print("error: coverage below minimum", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
