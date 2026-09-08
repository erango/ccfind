#!/usr/bin/env bash
# Regenerate docs/preview.svg and docs/browse.svg from a fabricated session store,
# so the README always shows the real renderer rather than hand-written ASCII.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
CCFIND="$REPO/bin/ccfind"
COLS=76

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
HOME_DIR="$WORK/home"; CFG="$WORK/cfg"
mkdir -p "$HOME_DIR" "$CFG/projects/api" "$CFG/projects/web" "$CFG/projects/infra"
ln -sfn "$CFG" "$HOME_DIR/.claude"

row() { # dir timestamp cwd-leaf session content-json
  printf '{"type":"user","origin":{"kind":"human"},"timestamp":"%s","cwd":"%s","sessionId":"%s","message":{"role":"user","content":%s}}\n' \
    "$2" "$HOME_DIR/code/$3" "$4" "$5" > "$CFG/projects/$1"
}
row api/a.jsonl   2026-09-07T14:12:00.000Z api   demo-0001 '"the payment webhook fires twice for every refund - find out whether that is our retry policy or Stripe redelivering"'
row api/b.jsonl   2026-09-04T09:41:00.000Z api   demo-0002 '"walk me through how the rate limiter buckets requests per tenant, and where the webhook sender sits in that"'
row web/c.jsonl   2026-08-30T18:05:00.000Z web   demo-0003 '"the settings page should remember the dark mode toggle across reloads - webhook status widget too"'
row infra/d.jsonl 2026-08-24T11:20:00.000Z infra demo-0004 '"<command-message>deploy</command-message><command-name>/deploy</command-name><command-args>staging --wait</command-args>"'

run() { env -i HOME="$HOME_DIR" PATH="$PATH" TERM=xterm-256color ${1:+"$@"}; }
# The transient "indexing..." notice ends in \r and shares its line with what
# follows, so drop everything up to each \r rather than the whole line.
strip() { perl -0777 -pe 's/[^\n\r]*\r(?!\n)//g; s/(resume.*?>\x1b\[0m) q/$1/s'; }

# CCFIND_TUI_FRAME draws exactly one frame of the picker, so the capture shows
# the real interactive view without driving keystrokes through the pty.
run CCFIND_NO_UPDATE_CHECK=1 CCFIND_TUI_FRAME=1 CCFIND_TUI_FRAME_SEL=2 \
  python3 "$HERE/capture.py" "$COLS" 22 "$CCFIND" webhook | strip > "$WORK/hero.ansi"

# A cached "newer release" far in the future keeps the banner offline and
# deterministic. Derive it from the current VERSION: a hardcoded number stops
# being newer the moment that version ships, and the banner silently vanishes.
NEXT=$(awk -F'"' '/^VERSION=/ { split($2, v, "."); printf "%d.%d.0", v[1], v[2] + 1; exit }' "$CCFIND")
mkdir -p "$CFG/ccfind-cache"
printf '9999999999\t%s\n' "$NEXT" > "$CFG/ccfind-cache/latest"
run python3 "$HERE/capture.py" "$COLS" 30 "$CCFIND" -l | strip > "$WORK/browse.ansi"

python3 "$HERE/ansi2svg.py" "$WORK/hero.ansi"   "$REPO/docs/preview.svg" ccfind "ccfind webhook" "$COLS"
python3 "$HERE/ansi2svg.py" "$WORK/browse.ansi" "$REPO/docs/browse.svg"  ccfind "ccfind"         "$COLS"
