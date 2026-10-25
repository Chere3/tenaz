#!/bin/zsh
# Verify a milestone: tests, project generation, Debug build, snapshots, smoke runs, cleanup.
# Usage: scripts/verify.sh [label] [--snap name ...] [--smoke surface ...] [--selftest name ...]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
LABEL="${1:-check}"; shift || true
APP=.derived/Build/Products/Debug/TenazDev.app
BIN="$APP/Contents/MacOS/TenazDev"
mkdir -p .derived/shots

echo "== swift test"
swift test 2>&1 | tail -n 3
swift test 2>&1 | grep -q "failed" && { echo "TESTS FAILED"; exit 1; }

echo "== xcodegen + build"
xcodegen generate --quiet
out=$(xcodebuild -project Tenaz.xcodeproj -scheme Tenaz -configuration Debug -derivedDataPath .derived build 2>&1 || true)
echo "$out" | grep -E "^/.*: (error|warning): " | sort -u | head -40 || true
echo "$out" | grep -q "\*\* BUILD SUCCEEDED \*\*" || { echo "BUILD FAILED"; exit 1; }
echo "BUILD SUCCEEDED"

while (( $# > 0 )); do
  case "$1" in
    --snap) "$BIN" --tenaz-snapshot "$2" --out ".derived/shots/$LABEL-$2.png"; shift 2 ;;
    --smoke) "$BIN" --tenaz-smoke "$2"; shift 2 ;;
    --selftest) "$BIN" --tenaz-selftest "$2"; shift 2 ;;
    *) echo "unknown arg $1"; exit 2 ;;
  esac
done

pkill -x TenazDev 2>/dev/null || true
# Overnight rule: intrusions must never be left enabled in the dev build.
[[ "$(defaults read com.chere3.tenaz.dev overlaysEnabled 2>/dev/null || echo 0)" == "1" ]] && { echo "overlaysEnabled left ON"; exit 1; }
echo "== verify $LABEL OK"
