#!/usr/bin/env bash
# Enforces the no-telemetry rule: no networking APIs in shipped code and no
# third-party packages. Fails with a list of offending lines.
# Usage: scripts/check-no-telemetry.sh   (or `make check`; run by CI)
set -euo pipefail

cd "$(dirname "$0")/.."

status=0
source_dirs=(App ShortcutLensCore/Sources)
network_pattern='import (Network|WebKit|CFNetwork)|URLSession|NSURLConnection|NWConnection|NWBrowser|NWListener|CFSocket|CFStreamCreatePairWith|WKWebView|getaddrinfo|socket\('

if grep -rEn --include='*.swift' --include='*.m' --include='*.c' --include='*.h' \
    "$network_pattern" "${source_dirs[@]}"; then
    echo "error: networking API found in shipped code (see lines above)." >&2
    status=1
fi

if grep -En '\.package\(' ShortcutLensCore/Package.swift; then
    echo "error: ShortcutLensCore must not declare package dependencies." >&2
    status=1
fi

if grep -En '^[[:space:]]*url:' project.yml; then
    echo "error: project.yml must not reference remote packages." >&2
    status=1
fi

if [[ $status -eq 0 ]]; then
    echo "no-telemetry check passed."
fi
exit $status
