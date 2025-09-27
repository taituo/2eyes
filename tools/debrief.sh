#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: tools/debrief.sh --workspace PATH [--codex-cmd CMD]

Aggregates a 2eyes workspace into:
  - debrief.html  (self-contained HTML with Mermaid diagrams)
  - brief_task.md (prompt scaffolding for Codex or human reviewers)

Optionally record a suggested Codex command via --codex-cmd.
HELP
}

WORKSPACE=""
CODEX_CMD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE="$2"; shift 2 ;;
    --codex-cmd)
      CODEX_CMD="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

[[ -n "$WORKSPACE" ]] || { echo "--workspace required" >&2; exit 1; }
WORKSPACE="$(cd "$WORKSPACE" && pwd)"
STREAM_DIR="$WORKSPACE/streams"
OUT_DIR="$WORKSPACE/out"
META_FILE="$WORKSPACE/.workspace"
HTML_OUT="$WORKSPACE/debrief.html"
TASK_OUT="$WORKSPACE/brief_task.md"
REPORT_OUT="$WORKSPACE/test_report.txt"

[[ -d "$STREAM_DIR" ]] || { echo "Missing streams directory: $STREAM_DIR" >&2; exit 1; }
[[ -d "$OUT_DIR" ]] || { echo "Missing out directory: $OUT_DIR" >&2; exit 1; }

WORKSPACE_NAME="$(basename "$WORKSPACE")"
SESSION=""
MODE="advanced"
ADVISOR="shell"
if [[ -f "$META_FILE" ]]; then
  SESSION=$(grep '^session=' "$META_FILE" | head -n1 | cut -d= -f2- || true)
  MODE=$(grep '^mode=' "$META_FILE" | head -n1 | cut -d= -f2- || true)
  ADVISOR=$(grep '^advisor=' "$META_FILE" | head -n1 | cut -d= -f2- || true)
fi

shopt -s nullglob
stream_files=( "$STREAM_DIR"/stream-*.log )
shopt -u nullglob
STREAM_LIST=$(printf '%s\n' "${stream_files[@]}" | sort -r | head -n5)
LATEST_STREAM=$(printf '%s\n' "${stream_files[@]}" | sort -r | head -n1)
SOLUTIONS_LOG="$OUT_DIR/solutions.log"
TAIL_SOLUTIONS=""
if [[ -f "$SOLUTIONS_LOG" ]]; then
  TAIL_SOLUTIONS=$(tail -n20 "$SOLUTIONS_LOG")
fi

REPORT_TAIL=""
if [[ -f "$REPORT_OUT" ]]; then
  REPORT_TAIL=$(tail -n40 "$REPORT_OUT")
fi

readarray -t STREAM_ITEMS <<< "$STREAM_LIST"
STREAM_LINES=()
for path in "${STREAM_ITEMS[@]}"; do
  [[ -z "$path" ]] && continue
  size=$(du -h "$path" | awk '{print $1}')
  base=$(basename "$path")
  STREAM_LINES+=("$base ($size)")
done
STREAM_TEXT="$(printf '%s\n' "${STREAM_LINES[@]}" 2>/dev/null)"

MERMAID_FLOW=$(cat <<'MERMAID'
flowchart LR
  Operator[Operator CLI] -->|stdout| Rotator[rotate.py or rotatelogs]
  Rotator --> Streams[streams/*.log]
  Streams --> AdvisorPane[Advisor Pane]
  AdvisorPane --> Solutions[solutions.log]
  Solutions --> Debrief[Debrief Report]
MERMAID
)

MERMAID_SEQUENCE=$(cat <<'MERMAID'
sequenceDiagram
  participant Op as Operator
  participant Rot as Rotator
  participant Adv as Advisor
  participant Deb as Debrief
  Op->>Rot: emit stdout/stderr
  Rot->>Adv: update latest chunk
  Adv->>Deb: append insights
  Deb-->>Op: mission report
MERMAID
)

NOW_TS=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

cat >"$HTML_OUT" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>2eyes Debrief - $WORKSPACE_NAME</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <script>mermaid.initialize({startOnLoad:true});</script>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; }
    pre { background: #0f172a; color: #f8fafc; padding: 1rem; overflow-x: auto; }
    section { margin-bottom: 2rem; }
    code { background: #e2e8f0; padding: 0.1rem 0.3rem; }
  </style>
</head>
<body>
  <h1>Mission Debrief: $WORKSPACE_NAME</h1>
  <p><strong>Generated:</strong> $NOW_TS</p>
  <p><strong>Session:</strong> ${SESSION:-n/a} &nbsp; <strong>Mode:</strong> ${MODE:-unknown} &nbsp; <strong>Advisor:</strong> ${ADVISOR:-unknown}</p>

  <section>
    <h2>Architecture</h2>
    <pre class="mermaid">$MERMAID_FLOW</pre>
  </section>

  <section>
    <h2>Signal Flow</h2>
    <pre class="mermaid">$MERMAID_SEQUENCE</pre>
  </section>

  <section>
    <h2>Streams Snapshot</h2>
    <p>Recent chunks (max 5):</p>
    <pre>${STREAM_TEXT:-No stream files found.}</pre>
    <p><strong>Latest chunk:</strong> ${LATEST_STREAM:-n/a}</p>
  </section>

  <section>
    <h2>Advisor Notes</h2>
    <p>Tail of <code>out/solutions.log</code>:</p>
    <pre>${TAIL_SOLUTIONS:-No advisor output recorded.}</pre>
  </section>

  <section>
    <h2>Regression Artifacts</h2>
    <p>Test report: <code>${REPORT_OUT#$WORKSPACE/}</code></p>
    <pre>${REPORT_TAIL:-No regression report captured.}</pre>
  </section>

  <section>
    <h2>Scenarios & Casts</h2>
    <p>Replay these asciinema casts or feed them to Codex:</p>
    <ul>
      <li><code>casts/kubernetes_deployment.cast</code> — deployment crashloop recovery</li>
      <li><code>casts/junos_port.cast</code> — Junos port unlock (with a false start)</li>
      <li><code>casts/linux_disk.cast</code> — Linux disk cleanup</li>
    </ul>
  </section>
</body>
</html>
EOF

cat >"$TASK_OUT" <<EOF
# Mission Briefing

- Workspace: $WORKSPACE_NAME
- Generated: $NOW_TS
- Session: ${SESSION:-n/a}
- Advisor mode: ${ADVISOR:-unknown}

## Evidence Checklist

- Streams: ${STREAM_TEXT:-No stream files}
- Advisor log: out/solutions.log
- Regression report: ${REPORT_OUT#$WORKSPACE/}
- Optional casts: see repository casts/

## Suggested Codex Prompt

Use this with `codex exec -m gpt-5-codex-medium`:

> Review workspace at $WORKSPACE. Summarise operator actions, identify any remaining risks, and propose next steps. Use streams/*.log and out/solutions.log as primary evidence.

## Optional Codex Command
EOF

if [[ -n "$CODEX_CMD" ]]; then
  cat >>"$TASK_OUT" <<EOF
```
$CODEX_CMD
```
EOF
else
  cat >>"$TASK_OUT" <<'EOF'
<!-- Insert your codex exec command here once ready. -->
EOF
fi

echo "Generated $HTML_OUT"
echo "Generated $TASK_OUT"
