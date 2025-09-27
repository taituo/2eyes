#!/usr/bin/env bash
set -euo pipefail

# Defaults
SESSION="${SESSION:-pair}"
STREAM_DIR="${STREAM_DIR:-$HOME/pair/streams}"
OUT_DIR="${OUT_DIR:-$HOME/pair/out}"
INTERVAL=${INTERVAL:-60}
KEEP=${KEEP:-60}
LATEST="${LATEST:-latest.log}"
MODE="${MODE:-split}"          # basic | split | advanced
CMD="${CMD-}"
DEMO=${DEMO:-0}
BACKEND="${BACKEND:-auto}"        # auto | rotatelogs | python
SCRIPTS_DIR="${SCRIPTS_DIR:-$HOME/pair/scripts}"
CODEX_MODE="shell"                # shell | stub | cmd
CODEX_CMD=""
CODEX_CD="$PWD"
ATTACH=1

usage() {
  cat <<EOF
Usage: $0 [options] <start|stop|status|attach>

Options:
  -s, --session NAME         tmux session name (default: $SESSION)
  -d, --dir PATH             directory for chunks (default: $STREAM_DIR)
  -o, --out PATH             output dir for agent (default: $OUT_DIR)
  -i, --interval SECS        rotation interval seconds (default: $INTERVAL)
  -k, --keep N               keep last N chunks (default: $KEEP)
  -l, --latest NAME          symlink name for latest chunk (default: $LATEST; empty disables)
  -m, --mode MODE            basic | split | advanced (default: $MODE)
  -c, --cmd 'COMMAND'        command to run in CLI pane
      --demo                 demo loop if --cmd empty
  -b, --backend NAME         auto | rotatelogs | python (default: auto)
      --no-attach            leave tmux session detached
  -h, --help                 show this help

Examples:
  $0 start --mode basic --cmd 'ssh user@router'
  $0 start -m split  -i 30 -k 120 -c 'ssh netops@router'
  $0 start -m advanced -b python -c 'ssh user@router'
EOF
}

# --- parse args ---
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    start|stop|status|attach)
      ACTION="${ACTION:-$1}";
      shift;
      ;;
    -s|--session) SESSION="$2"; shift 2 ;;
    -d|--dir) STREAM_DIR="$2"; shift 2 ;;
    -o|--out) OUT_DIR="$2"; shift 2 ;;
    -i|--interval) INTERVAL="$2"; shift 2 ;;
    -k|--keep) KEEP="$2"; shift 2 ;;
    -l|--latest) LATEST="${2-}"; shift 2 ;;
    -m|--mode) MODE="$2"; shift 2 ;;
    -c|--cmd) CMD="$2"; shift 2 ;;
    --demo) DEMO=1; shift ;;
    -b|--backend) BACKEND="$2"; shift 2 ;;
    --codex-cmd) CODEX_MODE="cmd"; CODEX_CMD="$2"; shift 2 ;;
    --codex-cd) CODEX_CD="$2"; shift 2 ;;
    --codex-stub) CODEX_MODE="stub"; shift ;;
    --no-attach) ATTACH=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done
ACTION="${ACTION:-start}"

# --- helpers ---
need() { command -v "$1" >/dev/null 2>&1 || return 1; }
session_exists() { tmux has-session -t "$SESSION" 2>/dev/null; }

backend_pick() {
  case "$BACKEND" in
    rotatelogs) echo "rotatelogs" ;;
    python)     echo "python" ;;
    auto)       if need rotatelogs; then echo "rotatelogs"; else echo "python"; fi ;;
    *)          echo "python" ;;
  esac
}

rotatelogs_cmd() {
  local tmpl="$STREAM_DIR/stream-%Y%m%d-%H%M.log"
  if [[ -n "$LATEST" ]]; then
    echo "rotatelogs -L $STREAM_DIR/$LATEST -n $KEEP $tmpl $INTERVAL"
  else
    echo "rotatelogs -n $KEEP $tmpl $INTERVAL"
  fi
}

python_rotate_cmd() {
  local script="$SCRIPTS_DIR/rotate.py"
  echo "python3 $script --outdir '$STREAM_DIR' --interval $INTERVAL --keep $KEEP ${LATEST:+--latest '$LATEST'}"
}

write_spec() {
  mkdir -p "$STREAM_DIR"
  cat > "$STREAM_DIR/SPEC.md" <<'EOF'
# STREAMS SPEC

## Yleiskuva
- Hakemisto sisältää aikaperusteisesti pilkotut tekstitiedostot yhteen (1) streamiin.
- Jokainen pala on minuutin (tai määritellyn INTERVAL-sekunnin) mittainen *n. seinäkellon mukainen* jakso.

## Tiedostonimet ja rakenne
- `stream-YYYYMMDD-HHMM.log` — esim. `stream-20250927-1423.log`
- Valinnainen symlink: `latest.log` → osoittaa aina käynnissä olevaan/tuoreimpaan palaan.
- Maksimimäärä säilytettäviä paloja: `KEEP` (vanhimmat poistetaan).

## Aikaleimat
- Rivien aikaleimat ovat tuotoksen omia (jos komento tuottaa).
- Jako ei muuta rivien sisältöä; vain tiedostojen rajat vaihtuvat INTERVAL-välein.

## Yhteensopivuus
- Sekä `rotatelogs`- että `rotate.py`-backend tuottavat identtisen nimeämisen.
- Agentit voivat:
  1) lukea `latest.log` (reaaliaikainen tail)
  2) iteroda `stream-*.log` aikajärjestyksessä.

## Käyttöagentti (Codex)
- Lukee uusia paloja/juoksevaa `latest.log`:ia.
- Tuottaa ohjeet ja huomioita tiedostoon: `../out/solutions.log`.
EOF
}

ensure_codex() {
  mkdir -p "$SCRIPTS_DIR" "$OUT_DIR"
  cat > "$SCRIPTS_DIR/codex_reader.py" <<'PY'
#!/usr/bin/env python3
import time
import os
import re
import glob
from datetime import datetime
from pathlib import Path

HOME = Path.home()
DEFAULT_STREAM_DIR = str(HOME / "pair" / "streams")
DEFAULT_OUT_DIR = str(HOME / "pair" / "out")

STREAM_DIR = os.path.expanduser(os.environ.get("STREAM_DIR", DEFAULT_STREAM_DIR))
OUT_DIR = os.path.expanduser(os.environ.get("OUT_DIR", DEFAULT_OUT_DIR))
LATEST_NAME = os.environ.get("LATEST", "latest.log")
LATEST = os.path.join(STREAM_DIR, LATEST_NAME) if LATEST_NAME else ""
OUT_SOL = os.path.join(OUT_DIR, "solutions.log")

RULES = [
    (re.compile(r"(Invalid input|unknown command|syntax error)", re.I),
     "Syntaksivirhe → kokeile 'show ?' / 'help' (hierarkiassa)."),
    (re.compile(r"(authentication failed|login incorrect)", re.I),
     "Auth-virhe → käyttäjä/AAA, kellonaika (NTP), reachability AAA:han."),
    (re.compile(r"([Ll]ink).*(down|disabled|lower|not present)", re.I),
     "Link DOWN → kaapeli/SFP, vastapään portti, autoneg/speed/duplex."),
    (re.compile(r"(administratively down)", re.I),
     "Admin DOWN → 'no shutdown' kyseiselle rajapinnalle."),
    (re.compile(r"(No such file|not found|command not found)", re.I),
     "Komento/polku puuttuu → täysi polku tai asenna binääri; tarkista PATH."),
]


def log(msg):
    ts = datetime.now().strftime("%F %T")
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT_SOL, "a", encoding="utf-8") as fh:
        fh.write(f"[{ts}] {msg}\n")


def resolve_path():
    if LATEST and os.path.exists(LATEST):
        return LATEST
    candidates = sorted(glob.glob(os.path.join(STREAM_DIR, "stream-*.log")))
    return candidates[-1] if candidates else None


def tail():
    current_path = None
    file_handle = None
    log("Codex stub käynnistyy")

    try:
        while True:
            target = resolve_path()
            if not target:
                time.sleep(0.5)
                continue

            if target != current_path:
                if file_handle:
                    file_handle.close()
                    file_handle = None
                try:
                    file_handle = open(target, "r", errors="ignore")
                except FileNotFoundError:
                    current_path = None
                    time.sleep(0.5)
                    continue
                current_path = target
                file_handle.seek(0, os.SEEK_END)
                log(f"Codex stub seuraa: {os.path.basename(target)}")

            line = file_handle.readline()
            if not line:
                if not os.path.exists(current_path):
                    current_path = None
                    continue
                time.sleep(0.2)
                continue

            for rx, tip in RULES:
                if rx.search(line):
                    log(f"⚠︎ {tip}\n   ↳ {line.strip()}")
    except KeyboardInterrupt:
        pass
    finally:
        if file_handle:
            file_handle.close()


if __name__ == "__main__":
    tail()
PY
  chmod +x "$SCRIPTS_DIR/codex_reader.py"
}

start_session() {
  need tmux || { echo "Missing dependency: tmux"; exit 1; }
  mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  touch "$OUT_DIR/solutions.log"
  write_spec

  # varmista backend
  local chosen backend_cmd
  chosen="$(backend_pick)"
  if [[ "$chosen" == "python" ]]; then
    [[ -f "$SCRIPTS_DIR/rotate.py" ]] || { echo "rotate.py missing at $SCRIPTS_DIR (use the Python backend file I gave)."; exit 1; }
  fi

  if session_exists; then
    echo "Session '$SESSION' already exists. Use '$0 attach' or stop first."
    exit 0
  fi

  local run_cmd
  if [[ -n "$CMD" ]]; then
    run_cmd="$CMD"
  elif [[ $DEMO -eq 1 ]]; then
    run_cmd='while true; do echo "$(date +%F\ %T) demo: hello"; sleep 1; done'
  else
    run_cmd='echo "No --cmd provided. Type your SSH here when attached."'
  fi

  tmux new-session -d -s "$SESSION" -n "CLI Panel"
  tmux send-keys -t "$SESSION":"CLI Panel" "$run_cmd" C-m

  if [[ "$chosen" == "rotatelogs" ]]; then
    need rotatelogs || { echo "Selected rotatelogs but not installed."; exit 1; }
    backend_cmd="$(rotatelogs_cmd)"
  else
    backend_cmd="$(python_rotate_cmd)"
  fi
  tmux pipe-pane -o -t "$SESSION":"CLI Panel" "$backend_cmd"

  if [[ "$MODE" == "split" || "$MODE" == "advanced" ]]; then
    tmux new-window -t "$SESSION" -n "Streams Panel"
    tmux send-keys -t "$SESSION":"Streams Panel" "watch -n 1 'ls -lh $STREAM_DIR | tail -n +1'" C-m
    tmux split-window -v -t "$SESSION":"Streams Panel"
    tmux select-pane -t "$SESSION":"Streams Panel".0 -T "Directory Watch"
    if [[ -n "$LATEST" ]]; then
      tmux select-pane -t "$SESSION":"Streams Panel".1 -T "Latest Tail"
      tmux send-keys -t "$SESSION":"Streams Panel".1 "tail -F $STREAM_DIR/$LATEST" C-m
    else
      tmux select-pane -t "$SESSION":"Streams Panel".1 -T "Latest Tail"
      tmux send-keys -t "$SESSION":"Streams Panel".1 "tail -F \$(ls -1t $STREAM_DIR/stream-*.log | head -n1)" C-m
    fi
  fi

  if [[ "$MODE" == "advanced" ]]; then
    tmux new-window -t "$SESSION" -n "Advisor Panel"
    tmux split-window -v -t "$SESSION":"Advisor Panel"

    printf -v env_prefix 'export STREAM_DIR=%q; export OUT_DIR=%q; export LATEST=%q;' \
      "$STREAM_DIR" "$OUT_DIR" "${LATEST:-latest.log}"
    printf -v codex_cd_cmd 'cd %q' "$CODEX_CD"

    case "$CODEX_MODE" in
      stub)
        ensure_codex
        tmux select-pane -t "$SESSION":"Advisor Panel".0 -T "Codex Stub"
        tmux send-keys -t "$SESSION":"Advisor Panel".0 "$env_prefix $SCRIPTS_DIR/codex_reader.py" C-m
        ;;
      cmd)
        tmux select-pane -t "$SESSION":"Advisor Panel".0 -T "Codex Command"
        tmux send-keys -t "$SESSION":"Advisor Panel".0 "$env_prefix $codex_cd_cmd" C-m
        tmux send-keys -t "$SESSION":"Advisor Panel".0 "$CODEX_CMD" C-m
        ;;
      *)
        tmux select-pane -t "$SESSION":"Advisor Panel".0 -T "Advisor Console"
        tmux send-keys -t "$SESSION":"Advisor Panel".0 "$env_prefix $codex_cd_cmd" C-m
        ;;
    esac

    tmux select-pane -t "$SESSION":"Advisor Panel".1 -T "Advisor Log"
    printf -v tail_cmd 'tail -F %q' "$OUT_DIR/solutions.log"
    tmux send-keys -t "$SESSION":"Advisor Panel".1 "$tail_cmd" C-m
  fi

  echo "Started '$SESSION' (mode: $MODE, backend: $chosen)."
  echo "Chunks -> $STREAM_DIR  (interval ${INTERVAL}s, keep $KEEP)"
  [[ -n "$LATEST" ]] && echo "Latest symlink: $STREAM_DIR/$LATEST"
  echo "Spec: $STREAM_DIR/SPEC.md"
  if [[ ${PAIRSTREAM_NO_ATTACH:-0} != 0 || $ATTACH -eq 0 ]]; then
    echo "Session '$SESSION' left detached."
  else
    tmux attach -t "$SESSION"
  fi
}

stop_session() {
  if session_exists; then
    tmux kill-session -t "$SESSION"
    echo "Stopped tmux session '$SESSION'."
  else
    echo "Session '$SESSION' not running."
  fi
}

status_session() {
  if session_exists; then
    echo "Session '$SESSION' is running."
    echo "Directory: $STREAM_DIR"
    ls -1 "${STREAM_DIR}"/stream-*.log 2>/dev/null | tail -n 5 || true
    [[ -n "$LATEST" && -L "$STREAM_DIR/$LATEST" ]] && ls -l "$STREAM_DIR/$LATEST"
    [[ -f "$STREAM_DIR/SPEC.md" ]] && echo "SPEC present: $STREAM_DIR/SPEC.md"
  else
    echo "Session '$SESSION' not running."
  fi
}

attach_session() {
  session_exists && tmux attach -t "$SESSION" || { echo "Session '$SESSION' not running."; exit 1; }
}

case "${ACTION}" in
  start) start_session ;;
  stop)  stop_session ;;
  status) status_session ;;
  attach) attach_session ;;
  *) usage; exit 1 ;;
esac
