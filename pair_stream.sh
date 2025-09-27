#!/usr/bin/env bash
set -euo pipefail

# Defaults
SESSION="pair"
STREAM_DIR="$HOME/pair/streams"
OUT_DIR="$HOME/pair/out"
INTERVAL=60
KEEP=60
LATEST="latest.log"
MODE="basic"          # basic | split | advanced
CMD=""
DEMO=0
BACKEND="auto"        # auto | rotatelogs | python
SCRIPTS_DIR="$HOME/pair/scripts"

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
    start|stop|status|attach) ACTION="$1"; shift; break ;;
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
  # Luodaan kevyt codex_reader.py jos sitä ei ole.
  if [[ ! -f "$SCRIPTS_DIR/codex_reader.py" ]]; then
    cat > "$SCRIPTS_DIR/codex_reader.py" <<'PY'
#!/usr/bin/env python3
import time, os, re, glob, sys
from datetime import datetime

STREAM_DIR = os.path.expanduser(os.environ.get("STREAM_DIR", "~/pair/streams"))
OUT_DIR = os.path.expanduser(os.environ.get("OUT_DIR", "~/pair/out"))
LATEST = os.path.join(STREAM_DIR, os.environ.get("LATEST", "latest.log"))
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
    with open(OUT_SOL, "a") as f:
        f.write(f"[{ts}] {msg}\n")

def tail_latest():
    # jos latest ei ole symlinkki, valitse uusin pala
    path = LATEST if os.path.exists(LATEST) else sorted(glob.glob(os.path.join(STREAM_DIR,"stream-*.log")))[-1]
    with open(path, "r", errors="ignore") as f:
        f.seek(0,2)
        log(f"Codex käynnissä; seuraan: {os.path.basename(path)}")
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2); continue
            for rx, tip in RULES:
                if rx.search(line):
                    log(f"⚠︎ {tip}\n   ↳ {line.strip()}")

if __name__ == "__main__":
    try:
        tail_latest()
    except KeyboardInterrupt:
        sys.exit(0)
PY
    chmod +x "$SCRIPTS_DIR/codex_reader.py"
  fi
}

start_session() {
  need tmux || { echo "Missing dependency: tmux"; exit 1; }
  mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
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

  tmux new-session -d -s "$SESSION" -n CLI
  tmux send-keys -t "$SESSION":CLI "$run_cmd" C-m

  if [[ "$chosen" == "rotatelogs" ]]; then
    need rotatelogs || { echo "Selected rotatelogs but not installed."; exit 1; }
    backend_cmd="$(rotatelogs_cmd)"
  else
    backend_cmd="$(python_rotate_cmd)"
  fi
  tmux pipe-pane -o -t "$SESSION":CLI "$backend_cmd"

  if [[ "$MODE" == "split" || "$MODE" == "advanced" ]]; then
    tmux new-window -t "$SESSION" -n VIEW
    tmux send-keys -t "$SESSION":VIEW "watch -n 1 'ls -lh $STREAM_DIR | tail -n +1'" C-m
    tmux split-window -v -t "$SESSION":VIEW
    if [[ -n "$LATEST" ]]; then
      tmux send-keys -t "$SESSION":VIEW.2 "tail -F $STREAM_DIR/$LATEST" C-m
    else
      tmux send-keys -t "$SESSION":VIEW.2 "tail -F \$(ls -1t $STREAM_DIR/stream-*.log | head -n1)" C-m
    fi
  fi

  if [[ "$MODE" == "advanced" ]]; then
    ensure_codex
    tmux new-window -t "$SESSION" -n CODEX
    tmux send-keys -t "$SESSION":CODEX "export STREAM_DIR='$STREAM_DIR' OUT_DIR='$OUT_DIR' LATEST='${LATEST:-latest.log}'; $SCRIPTS_DIR/codex_reader.py" C-m
    tmux split-window -v -t "$SESSION":CODEX
    tmux send-keys -t "$SESSION":CODEX.2 "tail -F $OUT_DIR/solutions.log" C-m
  fi

  echo "Started '$SESSION' (mode: $MODE, backend: $chosen)."
  echo "Chunks -> $STREAM_DIR  (interval ${INTERVAL}s, keep $KEEP)"
  [[ -n "$LATEST" ]] && echo "Latest symlink: $STREAM_DIR/$LATEST"
  echo "Spec: $STREAM_DIR/SPEC.md"
  tmux attach -t "$SESSION"
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

