#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
PAIR_SCRIPT="$PROJECT_ROOT/pair_stream.sh"
ROTATE_PY="$PROJECT_ROOT/rotate.py"

SESSION_BASE="pairtest_$$"
SESSION_INDEX=0

WORKDIR="$(mktemp -d)"
STREAM_ROOT="$WORKDIR"
STREAM_DIR="$STREAM_ROOT/streams"
OUT_DIR="$STREAM_ROOT/out"
SCRIPTS_DIR="$STREAM_ROOT/scripts"

PASS=0
FAIL=0

next_session() {
  SESSION_INDEX=$((SESSION_INDEX + 1))
  SESSION="${SESSION_BASE}_${SESSION_INDEX}"
}

cleanup() {
  if tmux ls >/dev/null 2>&1; then
    while read -r sess; do
      "$PAIR_SCRIPT" stop --session "$sess" >/dev/null 2>&1 || true
    done < <(tmux list-sessions -F '#S' | grep "^${SESSION_BASE}_" || true)
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

reset_workspace() {
  rm -rf "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  cp "$ROTATE_PY" "$SCRIPTS_DIR/rotate.py"
  chmod +x "$PAIR_SCRIPT" "$SCRIPTS_DIR/rotate.py"
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "[PASS] $msg"
    PASS=$((PASS+1))
  else
    echo "[FAIL] $msg" >&2
    echo "  expected to find: $needle" >&2
    echo "  in: $haystack" >&2
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "[FAIL] $msg" >&2
    echo "  did not expect: $needle" >&2
    echo "  in: $haystack" >&2
    FAIL=$((FAIL+1))
  else
    echo "[PASS] $msg"
    PASS=$((PASS+1))
  fi
}

wait_for_file() {
  local file="$1" timeout="${2:-10}" waited=0
  while [[ $waited -lt $timeout ]]; do
    [[ -f "$file" ]] && return 0
    sleep 1
    waited=$((waited+1))
  done
  return 1
}

start_session() {
  STREAM_DIR="$STREAM_DIR" OUT_DIR="$OUT_DIR" SCRIPTS_DIR="$SCRIPTS_DIR" \
  "$PAIR_SCRIPT" start --session "$SESSION" --dir "$STREAM_DIR" --out "$OUT_DIR" --no-attach "$@" >/dev/null
}

stop_session() {
  "$PAIR_SCRIPT" stop --session "$SESSION" >/dev/null
}

########################################
# 1) Basic mode (CLI only)
########################################
next_session
reset_workspace
start_session --mode basic --demo
WIN_LIST=$(tmux list-windows -t "$SESSION")
assert_contains "$WIN_LIST" "CLI Panel" "basic mode exposes CLI Panel"
assert_not_contains "$WIN_LIST" "Streams Panel" "basic mode omits Streams Panel"
assert_not_contains "$WIN_LIST" "Advisor Panel" "basic mode omits Advisor Panel"
stop_session

########################################
# 2) Split mode (CLI + Streams)
########################################
next_session
reset_workspace
start_session --mode split --demo
WIN_LIST=$(tmux list-windows -t "$SESSION")
assert_contains "$WIN_LIST" "CLI Panel" "split mode has CLI Panel"
assert_contains "$WIN_LIST" "Streams Panel" "split mode has Streams Panel"
assert_not_contains "$WIN_LIST" "Advisor Panel" "split mode omits Advisor Panel"
stop_session

########################################
# 3) Advanced default (interactive advisor)
########################################
next_session
reset_workspace
start_session --mode advanced --demo
WIN_LIST=$(tmux list-windows -t "$SESSION")
assert_contains "$WIN_LIST" "CLI Panel" "advanced mode CLI"
assert_contains "$WIN_LIST" "Streams Panel" "advanced mode Streams"
assert_contains "$WIN_LIST" "Advisor Panel" "advanced mode Advisor"
PANE_TITLE=$(tmux display-message -p -t "$SESSION":"Advisor Panel".0 '#{pane_title}')
assert_contains "$PANE_TITLE" "Advisor" "advisor pane default title"
stop_session

########################################
# 4) Advanced stub
########################################
next_session
reset_workspace
start_session --mode advanced --demo --codex-stub
wait_for_file "$OUT_DIR/solutions.log" 5 || true
sleep 3
if grep -q "Codex stub" "$OUT_DIR/solutions.log" 2>/dev/null; then
  echo "[PASS] codex stub writes log"
  PASS=$((PASS+1))
else
  echo "[FAIL] codex stub log missing" >&2
  FAIL=$((FAIL+1))
fi
stop_session

########################################
# 5) Rotation keep limit
########################################
next_session
reset_workspace
start_session --mode split --demo --interval 2 --keep 2
sleep 7
FILE_COUNT=$(ls "$STREAM_DIR"/stream-*.log 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT" -le 2 ]]; then
  echo "[PASS] rotation keep limit"
  PASS=$((PASS+1))
else
  echo "[FAIL] rotation keep limit (got $FILE_COUNT)" >&2
  FAIL=$((FAIL+1))
fi
stop_session

########################################
# 6) Python backend naming
########################################
next_session
reset_workspace
start_session --mode basic --demo --backend python
sleep 3
if ls "$STREAM_DIR"/stream-*_*.log >/dev/null 2>&1; then
  echo "[FAIL] python backend produced suffixed names" >&2
  FAIL=$((FAIL+1))
else
  echo "[PASS] python backend canonical names"
  PASS=$((PASS+1))
fi
stop_session

if [[ $FAIL -eq 0 ]]; then
  echo "All $PASS checks passed."
  exit 0
else
  echo "$FAIL checks failed, $PASS passed." >&2
  exit 1
fi
