#!/usr/bin/env bash
# Builds a signed Release Tenaz.app, installs it at /Applications/Tenaz.app and turns on "open at login".
# Always the same path, so TCC grants (calendar, mic, speech, Apple Events) stay attached to one identity.
#
# First install only: copies the dev build's data (TenazDev) so progress carries over:
#   - tenaz.sqlite through sqlite3 .backup (consistent copy), audio-cache as an APFS clone (instant);
#   - preferences per TENAZ_COPY_PREFS: "all" (default; the gate and
#     overlays stay on), "safe" (everything except the overlay and gate switches, so they start off
#     as DECISIONS.md rule 2 ships them), or "none".
# The TenazDev folder and preferences are never changed or deleted.
#
# Env: TENAZ_LOGIN_ITEM=0 skips the login item. TENAZ_DERIVED_DATA overrides the build folder.
set -euo pipefail

EXPECTED_ID="com.chere3.tenaz"
DEV_ID="com.chere3.tenaz.dev"
EXPECTED_TEAM="7QQ3Y399CF"
DEST="/Applications/Tenaz.app"
SUPPORT="$HOME/Library/Application Support"
DEV_DATA="$SUPPORT/TenazDev"
DATA="$SUPPORT/Tenaz"
COPY_PREFS="${TENAZ_COPY_PREFS:-all}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${TENAZ_DERIVED_DATA:-$ROOT/.derived-release}"
BUILT="$DERIVED/Build/Products/Release/Tenaz.app"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

log() { printf '[install-tenaz] %s\n' "$*"; }
die() { printf '[install-tenaz] ERROR: %s\n' "$*" >&2; exit 1; }

case "$COPY_PREFS" in safe|all|none) ;; *) die "TENAZ_COPY_PREFS must be safe, all or none (got $COPY_PREFS)" ;; esac

# Stop (never delete) if an existing install has a different identity:
# ditto would merge into the old bundle and leave its stale executable behind.
if [[ -d "$DEST" ]]; then
  current_id="$(codesign -dvv "$DEST" 2>&1 | sed -n 's/^Identifier=//p' | head -n1 || true)"
  if [[ -n "$current_id" && "$current_id" != "$EXPECTED_ID" ]]; then
    die "$DEST has Identifier=$current_id (expected $EXPECTED_ID). Remove the old copy yourself first, then rerun."
  fi
fi

log "Generating Xcode project"
(cd "$ROOT" && xcodegen generate --quiet)

log "Building Release (signed, team $EXPECTED_TEAM)"
(cd "$ROOT" && xcodebuild -project Tenaz.xcodeproj -scheme Tenaz \
  -derivedDataPath "$DERIVED" -configuration Release build -quiet)

[[ -d "$BUILT" ]] || die "build product not found: $BUILT"

# Quit both builds: two running copies would mean two gates and double overlays,
# and the dev database must be idle before it is copied.
quit_app() {
  local id="$1" name="$2"
  pgrep -x "$name" >/dev/null || return 0
  log "Quitting $name"
  osascript -e 'tell application id "'"$id"'" to quit' >/dev/null 2>&1 || true
  for _ in {1..20}; do pgrep -x "$name" >/dev/null || return 0; sleep 0.5; done
  die "$name is still running; quit it from its menu-bar icon and rerun"
}
quit_app "$EXPECTED_ID" Tenaz
quit_app "$DEV_ID" TenazDev

if [[ ! -e "$DATA" && -f "$DEV_DATA/tenaz.sqlite" ]]; then
  log "First install: copying your TenazDev data to $DATA"
  # Staged, then renamed: an interrupted copy never looks like a finished one on the next run.
  staging="$SUPPORT/Tenaz.partial"
  rm -rf "$staging"
  mkdir -p "$staging"
  sqlite3 "$DEV_DATA/tenaz.sqlite" ".backup '$staging/tenaz.sqlite'"
  if [[ -d "$DEV_DATA/audio-cache" ]]; then
    cp -c -R "$DEV_DATA/audio-cache" "$staging/audio-cache"   # APFS clone: instant, no extra space
  fi
  mv "$staging" "$DATA"
else
  log "Data: $DATA already exists or there is no dev data; leaving it as it is"
fi

if [[ "$COPY_PREFS" != none ]] && ! defaults read "$EXPECTED_ID" >/dev/null 2>&1 \
   && defaults read "$DEV_ID" >/dev/null 2>&1; then
  log "First install: copying preferences ($COPY_PREFS)"
  tmp="$(mktemp -d)"; prefs="$tmp/prefs.plist"
  defaults export "$DEV_ID" "$prefs"
  if [[ "$COPY_PREFS" == safe ]]; then
    for key in overlaysEnabled gateEnabled; do plutil -remove "$key" "$prefs" >/dev/null 2>&1 || true; done
  fi
  defaults import "$EXPECTED_ID" "$prefs"
  rm -rf "$tmp"
fi

# Copy to a fresh bundle, verify it, then swap: ditto over an existing bundle would keep files the
# new build dropped and break its signature seal. The fresh copy lives in $TMPDIR (same volume as
# /Applications, so the swap is a rename), never beside the app, where Raycast and Spotlight would
# index it as a second "Tenaz.app.new".
STAGE="$(mktemp -d)"
NEW="$STAGE/Tenaz.app"
ditto "$BUILT" "$NEW"

log "Verifying signature"
codesign --verify --strict --deep --verbose=2 "$NEW"
info="$(codesign -dvv "$NEW" 2>&1)"
grep -q "^Identifier=$EXPECTED_ID$" <<<"$info" || die "unexpected Identifier"
grep -q "^TeamIdentifier=$EXPECTED_TEAM$" <<<"$info" || die "unexpected TeamIdentifier"
! grep -qi 'adhoc' <<<"$info" || die "signature is ad-hoc"

log "Installing to $DEST"
rm -rf "$DEST"
mv "$NEW" "$DEST"
rmdir "$STAGE"

if [[ "${TENAZ_LOGIN_ITEM:-1}" == 1 ]]; then
  log "Turning on open at login (off again: Settings › Data, or System Settings › General › Login Items)"
  "$DEST/Contents/MacOS/Tenaz" --tenaz-login-item on \
    || log "WARNING: login item not enabled yet; approve Tenaz in System Settings › General › Login Items"
fi

log "Opening Tenaz"
open "$DEST"
log "OK: $DEST installed and verified. Use Tenaz from now on, not TenazDev."
