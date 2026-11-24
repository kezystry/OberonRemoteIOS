#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cp "$ROOT/Tests/check_protocol.swift" "$TMP_DIR/main.swift"
swiftc "$ROOT/App/OberonProtocol.swift" "$TMP_DIR/main.swift" -o "$TMP_DIR/check-protocol"
"$TMP_DIR/check-protocol"
