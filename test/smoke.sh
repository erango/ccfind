#!/usr/bin/env bash
# Exercises ccfind against a fabricated session store, so CI needs no real Claude Code data.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CCFIND="$ROOT/bin/ccfind"

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

export CLAUDE_CONFIG_DIR="$TMP/cfg"
export CCFIND_NO_UPDATE_CHECK=1
export NO_COLOR=1

mkdir -p "$CLAUDE_CONFIG_DIR/projects/-tmp-demo"
cat > "$CLAUDE_CONFIG_DIR/projects/-tmp-demo/s1.jsonl" <<'JSON'
{"type":"user","origin":{"kind":"human"},"timestamp":"2026-01-02T03:04:05.000Z","cwd":"/tmp/demo","sessionId":"11111111-1111-1111-1111-111111111111","message":{"role":"user","content":"teach me about widgets"}}
{"type":"user","origin":{"kind":"human"},"timestamp":"2026-01-02T03:05:05.000Z","cwd":"/tmp/demo","sessionId":"11111111-1111-1111-1111-111111111111","message":{"role":"user","content":"<command-message>deploy</command-message><command-name>/deploy</command-name><command-args>prod</command-args>"}}
{"type":"user","origin":{"kind":"human"},"timestamp":"2026-01-03T09:00:00.000Z","cwd":"/tmp/demo","sessionId":"22222222-2222-2222-2222-222222222222","message":{"role":"user","content":[{"type":"text","text":"שלום widgets in an array block"}]}}
{"type":"user","message":{"role":"user","content":[{"tool_use_id":"t1","type":"tool_result","content":"widgets tool output that must not be indexed"}]}}
{"type":"assistant","message":{"role":"assistant","content":"widgets assistant text that must not be indexed"}}
not valid json at all
JSON

fails=0
check() {
  if [ "$1" -eq 0 ]; then
    printf '  ok   %s\n' "$2"
  else
    printf '  FAIL %s\n' "$2"
    fails=$((fails + 1))
  fi
}

out=$("$CCFIND" -l widgets 2>&1)
case "$out" in *"teach me about widgets"*) check 0 "renders a matching prompt" ;;
                                        *) check 1 "renders a matching prompt"; echo "$out" ;; esac
case "$out" in *"/tmp/demo"*) check 0 "renders the session directory" ;;
                           *) check 1 "renders the session directory" ;; esac
case "$out" in *"שלום"*) check 0 "renders non-ASCII prompt text" ;;
                      *) check 1 "renders non-ASCII prompt text" ;; esac
case "$out" in *"tool output"*|*"assistant text"*) check 1 "indexes only typed prompts" ;;
                                                *) check 0 "indexes only typed prompts" ;; esac

# Both sessions mention widgets; one row each, never two rows for one session.
rows=$(printf '%s\n' "$out" | grep -cE '^ +[0-9]+  [~/]')
[ "$rows" -eq 2 ]
check $? "one row per session (got $rows, want 2)"

out=$("$CCFIND" -l deploy 2>&1)
case "$out" in *"/deploy prod"*) check 0 "slash commands render as typed" ;;
                              *) check 1 "slash commands render as typed"; echo "$out" ;; esac
case "$out" in *"command-name"*) check 1 "no raw command XML leaks" ;;
                              *) check 0 "no raw command XML leaks" ;; esac

"$CCFIND" --version | grep -qE '^ccfind [0-9]+\.[0-9]+\.[0-9]+$'
check $? "--version prints a semver"

"$CCFIND" --help | grep -q 'usage:'
check $? "--help prints usage"

"$CCFIND" -l zzzz-no-such-prompt-zzzz >/dev/null 2>&1
[ $? -eq 1 ]
check $? "exits 1 when nothing matches"

# A second run must reuse the index rather than rebuild it.
before=$(wc -l < "$CLAUDE_CONFIG_DIR/ccfind-cache/index.tsv")
"$CCFIND" -l widgets >/dev/null 2>&1
after=$(wc -l < "$CLAUDE_CONFIG_DIR/ccfind-cache/index.tsv")
[ "$before" -eq "$after" ]
check $? "incremental refresh does not duplicate rows ($before then $after)"

if [ "$fails" -eq 0 ]; then
  echo "all checks passed"
else
  echo "$fails check(s) failed"
  exit 1
fi
