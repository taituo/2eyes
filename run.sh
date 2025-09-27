#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAIR_SCRIPT="$PROJECT_ROOT/pair_stream.sh"
ROTATE_PY="$PROJECT_ROOT/rotate.py"
TEST_SUITE="$PROJECT_ROOT/tests/run_tests.sh"
WORKSPACES_DIR="$PROJECT_ROOT/workspaces"
mkdir -p "$WORKSPACES_DIR"

prompt() {
  local prompt_text="$1"
  read -rp "$prompt_text" REPLY
  echo "$REPLY"
}

next_workspace_name() {
  local idx=1
  while :; do
    local candidate
    candidate=$(printf "workspace_%03d" "$idx")
    if [[ ! -e "$WORKSPACES_DIR/$candidate" ]]; then
      echo "$candidate"
      return
    fi
    idx=$((idx+1))
  done
}

workspace_path() {
  local name="$1"
  echo "$WORKSPACES_DIR/$name"
}

workspace_session() {
  local name="$1" suffix="$2"
  echo "ws_${name}_${suffix}"
}

ensure_workspace_structure() {
  local ws_path="$1"
  mkdir -p "$ws_path/streams" "$ws_path/out" "$ws_path/scripts" "$ws_path/logs"
  cp "$ROTATE_PY" "$ws_path/scripts/rotate.py"
  chmod +x "$ws_path/scripts/rotate.py"
}

record_workspace_meta() {
  local ws_name="$1" key="$2" value="$3"
  local meta_file="$WORKSPACES_DIR/$ws_name/.workspace"
  mkdir -p "$(dirname "$meta_file")"
  if [[ -f "$meta_file" ]]; then
    grep -v "^$key=" "$meta_file" >"$meta_file.tmp" && mv "$meta_file.tmp" "$meta_file"
  fi
  printf '%s=%s\n' "$key" "$value" >>"$meta_file"
}

list_workspaces() {
  local ws
  printf '%-15s %-10s %-20s\n' "Workspace" "State" "Session"
  for ws in $(ls "$WORKSPACES_DIR" 2>/dev/null | sort); do
    [[ -d "$WORKSPACES_DIR/$ws" ]] || continue
    local meta="$WORKSPACES_DIR/$ws/.workspace"
    local session=""
    local state="idle"
    if [[ -f "$meta" ]]; then
      session=$(grep '^session=' "$meta" | head -n1 | cut -d= -f2- || true)
    fi
    if [[ -n "$session" && $(tmux has-session -t "$session" 2>/dev/null && echo running) ]]; then
      state="running"
    fi
    printf '%-15s %-10s %-20s\n' "$ws" "$state" "${session:--}"
  done
}

start_session() {
  local ws_name="$1" advisor_mode="$2" codex_cmd="$3"
  local ws_path
  ws_path=$(workspace_path "$ws_name")
  ensure_workspace_structure "$ws_path"
  local session
  session=$(workspace_session "$ws_name" "adv")
  record_workspace_meta "$ws_name" session "$session"
  record_workspace_meta "$ws_name" mode "advanced"
  record_workspace_meta "$ws_name" advisor "$advisor_mode"

  local extra_flags=()
  case "$advisor_mode" in
    stub) extra_flags+=(--codex-stub) ;;
    cmd)  extra_flags+=(--codex-cd "$ws_path" --codex-cmd "$codex_cmd") ;;
  esac

  echo "Launching workspace '$ws_name' (session: $session)"
  env \
    STREAM_DIR="$ws_path/streams" \
    OUT_DIR="$ws_path/out" \
    SCRIPTS_DIR="$ws_path/scripts" \
    "$PAIR_SCRIPT" start --session "$session" --mode advanced \
      --dir "$ws_path/streams" --out "$ws_path/out" \
      "${extra_flags[@]}"
}

run_tests() {
  local ws_name
  ws_name=$(next_workspace_name)
  local ws_path
  ws_path=$(workspace_path "$ws_name")
  mkdir -p "$ws_path"
  echo "Running regression suite in $ws_name"
  if "$TEST_SUITE" --workspace "$ws_path"; then
    echo "Tests completed. Report -> $ws_path/test_report.txt"
  else
    echo "Tests failed. See $ws_path/test_report.txt" >&2
  fi
}

attach_workspace() {
  list_workspaces
  local choice
  choice=$(prompt 'Workspace to attach (name): ')
  [[ -n "$choice" ]] || return
  local meta="$WORKSPACES_DIR/$choice/.workspace"
  if [[ ! -f "$meta" ]]; then
    echo "Unknown workspace." >&2
    return
  fi
  local session
  session=$(grep '^session=' "$meta" | head -n1 | cut -d= -f2- || true)
  if [[ -z "$session" ]]; then
    echo "Workspace has no recorded session." >&2
    return
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux attach -t "$session"
  else
    echo "Session $session not running." >&2
  fi
}

stop_workspace() {
  list_workspaces
  local choice
  choice=$(prompt 'Workspace to stop (name): ')
  [[ -n "$choice" ]] || return
  local meta="$WORKSPACES_DIR/$choice/.workspace"
  local session
  [[ -f "$meta" ]] && session=$(grep '^session=' "$meta" | head -n1 | cut -d= -f2- || true)
  if [[ -n "$session" ]]; then
    "$PAIR_SCRIPT" stop --session "$session" || true
  fi
  rm -rf "$WORKSPACES_DIR/$choice"
  echo "Workspace $choice removed."
}

start_interactive_menu() {
  while true; do
    cat <<'MENU'

--- 2eyes Command Center ---
1) Start advanced workspace (interactive advisor)
2) Start advanced workspace (Codex stub)
3) Start advanced workspace (custom Codex command)
4) Run automated regression suite
5) Attach to existing workspace
6) Stop & remove workspace
7) List workspaces
8) Exit
MENU
    local choice
    choice=$(prompt 'Select option: ')
    case "$choice" in
      1)
        local ws_name=$(next_workspace_name)
        start_session "$ws_name" "shell" "" ;;
      2)
        local ws_name=$(next_workspace_name)
        start_session "$ws_name" "stub" "" ;;
      3)
        local ws_name=$(next_workspace_name)
        local cmd=$(prompt 'Codex command to run: ')
        start_session "$ws_name" "cmd" "$cmd" ;;
      4)
        run_tests ;;
      5)
        attach_workspace ;;
      6)
        stop_workspace ;;
      7)
        list_workspaces ;;
      8)
        echo "Bye."; break ;;
      *)
        echo "Unknown selection." ;;
    esac
  done
}

start_interactive_menu
