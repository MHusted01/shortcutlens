#!/usr/bin/env bash
# Creates a self-signed code signing identity for local Debug builds and
# points Config/Local.xcconfig at it. Ad-hoc signatures change on every
# build, so macOS drops the Accessibility permission each time; a stable
# certificate keeps it. Safe to run again. Nothing is written to the repo
# except the gitignored Config/Local.xcconfig.
set -euo pipefail

cd "$(dirname "$0")/.."

identity="ShortcutLens Development"
# SHORTCUTLENS_KEYCHAIN overrides the target keychain (for testing).
keychain="${SHORTCUTLENS_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
local_config="Config/Local.xcconfig"
valid_days=3650

if security find-certificate -c "$identity" "$keychain" >/dev/null 2>&1; then
    echo "Identity \"$identity\" already exists in $(basename "$keychain")."
else
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT
    p12_phrase="$(openssl rand -hex 16)"  # throwaway, wraps the temp .p12 only

    openssl req -x509 -newkey rsa:2048 -nodes -days "$valid_days" \
        -subj "/CN=$identity" \
        -addext "basicConstraints=critical,CA:false" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -keyout "$workdir/key.pem" -out "$workdir/cert.pem" 2>/dev/null
    # 3DES/SHA-1 PKCS#12: the encryption `security import` understands.
    openssl pkcs12 -export -inkey "$workdir/key.pem" -in "$workdir/cert.pem" \
        -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
        -passout "pass:$p12_phrase" -out "$workdir/identity.p12"
    security import "$workdir/identity.p12" -k "$keychain" \
        -P "$p12_phrase" -T /usr/bin/codesign >/dev/null
    echo "Created \"$identity\" in $(basename "$keychain")."
fi

if [ -f "$local_config" ]; then
    echo "$local_config already exists; left unchanged."
else
    printf '// Local only (gitignored). Written by scripts/create-dev-cert.sh.\nCODE_SIGN_IDENTITY = %s\n' \
        "$identity" > "$local_config"
    echo "Wrote $local_config."
fi

echo "Next: make build, then grant Accessibility to build/Build/Products/Debug/ShortcutLens.app once."
