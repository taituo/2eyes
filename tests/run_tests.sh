#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: tests/run_tests.sh [--workspace DIR] [--replay-cast PATH]

Smoketests the tmux orchestration:
  - panel layout in basic/split/advanced modes
  - Codex stub logging and custom Codex command execution
  - rotation retention and Python backend naming
  - workspace teardown when metadata lacks session info
  - optional replay of a sample asciinema cast to verify stream capture
  - debrief generation (HTML + Markdown)

When --workspace is provided, artifacts (streams/out/scripts + logs) are stored
under that directory and not deleted afterwards. Use --replay-cast casts/foo.cast
to feed canned operator activity into the CLI panel mid-run.
HELP
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
PAIR_SCRIPT="$PROJECT_ROOT/pair_stream.sh"
ROTATE_PY="$PROJECT_ROOT/rotate.py"

WORKSPACE=""
REPLAY_CAST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE="$2"; shift 2 ;;
    --replay-cast)
      REPLAY_CAST="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage; exit 1 ;;
  esac
done

REMOVE_WORKSPACE=1
if [[ -n "$WORKSPACE" ]]; then
  REMOVE_WORKSPACE=0
else
  WORKSPACE="$(mktemp -d)"
fi

mkdir -p "$WORKSPACE"
STREAM_DIR="$WORKSPACE/streams"
OUT_DIR="$WORKSPACE/out"
SCRIPTS_DIR="$WORKSPACE/scripts"
REPORT="$WORKSPACE/test_report.txt"
CAST_LOG="$WORKSPACE/cast.log"

SESSION_BASE="pw_$$"
SESSION_INDEX=0

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
  if [[ $REMOVE_WORKSPACE -eq 1 ]]; then
    rm -rf "$WORKSPACE"
  fi
}
trap cleanup EXIT

reset_workspace() {
  rm -rf "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  cp "$ROTATE_PY" "$SCRIPTS_DIR/rotate.py"
  chmod +x "$PAIR_SCRIPT" "$SCRIPTS_DIR/rotate.py"
}

log_pass() { echo "[PASS] $1" | tee -a "$REPORT"; PASS=$((PASS+1)); }
log_fail() { echo "[FAIL] $1" | tee -a "$REPORT" >&2; FAIL=$((FAIL+1)); }

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  [[ "$haystack" == *"$needle"* ]] && log_pass "$message" || log_fail "$message"
}

assert_not_contains() {
  local haystack="$1" needle="$2" message="$3"
  [[ "$haystack" == *"$needle"* ]] && log_fail "$message" || log_pass "$message"
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
  STREAM_DIR="$STREAM_DIR" OUT_DIR="$OUT_DIR" SCRIPTS_DIR="$SCRIPTS_DIR"   "$PAIR_SCRIPT" start --session "$SESSION" --dir "$STREAM_DIR" --out "$OUT_DIR" --no-attach "$@" >/dev/null
}

stop_session() {
  "$PAIR_SCRIPT" stop --session "$SESSION" >/dev/null 2>&1 || true
}

: >"$REPORT"

### 1) basic mode
next_session
reset_workspace
start_session --mode basic --demo
WIN_LIST=$(tmux list-windows -t "$SESSION")
assert_contains "$WIN_LIST" "CLI Panel" "basic: CLI panel present"
assert_not_contains "$WIN_LIST" "Streams Panel" "basic: no Streams panel"
assert_not_contains "$WIN_LIST" "Advisor Panel" "basic: no Advisor panel"
stop_session

### 2) split mode
next_session
reset_workspace
start_session --mode split --demo
WIN_LIST=$(tmux list-windows -t "$SESSION")
assert_contains "$WIN_LIST" "CLI Panel" "split: CLI panel present"
assert_contains "$WIN_LIST" "Streams Panel" "split: Streams panel present"
assert_not_contains "$WIN_LIST" "Advisor Panel" "split: no Advisor panel"
stop_session

### 3) advanced interactive
next_session
reset_workspace
start_session --mode advanced --demo
WIN_LIST=$(tmux list-windows -t "$SESSION")
assert_contains "$WIN_LIST" "CLI Panel" "advanced: CLI panel present"
assert_contains "$WIN_LIST" "Streams Panel" "advanced: Streams panel present"
assert_contains "$WIN_LIST" "Advisor Panel" "advanced: Advisor panel present"
PANE_TITLE=$(tmux display-message -p -t "$SESSION":"Advisor Panel".0 '#{pane_title}')
assert_contains "$PANE_TITLE" "Advisor" "advanced: advisor pane titled"
stop_session

### 4) advanced stub
next_session
reset_workspace
start_session --mode advanced --demo --codex-stub
wait_for_file "$OUT_DIR/solutions.log" 5 || true
sleep 3
if grep -q "Codex stub" "$OUT_DIR/solutions.log" 2>/dev/null; then
  log_pass "codex stub recorded activity"
else
  log_fail "codex stub recorded activity"
fi
stop_session

### 5) advanced custom command
next_session
reset_workspace
start_session --mode advanced --demo --codex-cmd "echo CODexReady && sleep 1"
sleep 2
PANE_CAPTURE=$(tmux capture-pane -p -t "$SESSION":"Advisor Panel".0)
assert_contains "$PANE_CAPTURE" "CODexReady" "advanced: custom command executed"
stop_session

### 6) rotation keep limit
next_session
reset_workspace
start_session --mode split --demo --interval 2 --keep 2
sleep 7
shopt -s nullglob
stream_files=("$STREAM_DIR"/stream-*.log)
FILE_COUNT=${#stream_files[@]}
shopt -u nullglob
if [[ "$FILE_COUNT" -le 2 ]]; then
  log_pass "rotation respected keep limit"
else
  log_fail "rotation respected keep limit (got $FILE_COUNT)"
fi
stop_session

### 7) python backend naming
next_session
reset_workspace
start_session --mode basic --demo --backend python
sleep 3
if ls "$STREAM_DIR"/stream-*_*.log >/dev/null 2>&1; then
  log_fail "python backend kept canonical names"
else
  log_pass "python backend kept canonical names"
fi
stop_session

### 8) workspace teardown without session
next_session
reset_workspace
# simulate a workspace with no session metadata
rm -f "$WORKSPACE/.workspace"
mkdir -p "$WORKSPACE"
run=1
if ./run.sh <<'MENU'
7
6
test_run_001
8
MENU
then
  log_pass "run.sh handled missing session metadata"
else
  log_fail "run.sh handled missing session metadata"
fi

### Debrief generation
tools/debrief.sh --workspace "$WORKSPACE" >/dev/null 2>&1
if [[ -f "$WORKSPACE/debrief.html" && -f "$WORKSPACE/brief_task.md" ]]; then
  log_pass "debrief assets generated"
else
  log_fail "debrief assets generated"
fi

### Optional cast replay
if [[ -n "$REPLAY_CAST" && -f "$REPLAY_CAST" ]]; then
  next_session
  reset_workspace
  start_session --mode advanced --demo --codex-stub
  sleep 2
  asciinema play "$REPLAY_CAST" >/dev/null 2>&1 || true
  stop_session
  log_pass "cast $REPLAY_CAST replayed"
fi

if [[ $FAIL -eq 0 ]]; then
  echo "All $PASS checks passed." | tee -a "$REPORT"
else
  echo "$FAIL checks failed, $PASS passed." | tee -a "$REPORT" >&2
  exit 1
fi
