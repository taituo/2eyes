# Testing Manual for pair_stream Toolkit

These instructions validate every feature of `pair_stream.sh` and `rotate.py` without relying on home-directory shortcuts. Pick any workspace that suits your environment.

## 1. Prerequisites
- Install `tmux`, `python3`, `bash`, and optionally Apache `rotatelogs`.
- Ensure `pair_stream.sh` and `rotate.py` are executable (`chmod +x pair_stream.sh rotate.py`).
- Choose a scratch directory and export helper paths (adjust to taste):
  ```bash
  export PS_WORKDIR="$(pwd)/pair_test"
  export STREAM_DIR="$PS_WORKDIR/streams"
  export OUT_DIR="$PS_WORKDIR/out"
  export SCRIPTS_DIR="$PS_WORKDIR/scripts"
  mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  ```
- Copy `rotate.py` into the scripts directory used by the runner: `cp rotate.py "$SCRIPTS_DIR/rotate.py"`.

## 2. Baseline Reset
1. Stop any old tmux session: `./pair_stream.sh stop --session pair || true`.
2. Remove prior artefacts: `rm -rf "$STREAM_DIR" "$OUT_DIR"`.
3. Recreate clean directories as above and re-copy `rotate.py` if needed.

## 3. Core Lifecycle Commands
1. Start the default session: `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
2. Check status: `./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"` → expect “Session 'pair' is running.” and a spec path under `$STREAM_DIR`.
3. Attach to tmux (`./pair_stream.sh attach`) and confirm the demo loop prints timestamps (detach with `Ctrl+b d`).
4. Stop the session: `./pair_stream.sh stop` and re-run status to confirm it is not running.

## 4. Mode Behaviour
### 4.1 Basic Mode
- Launch: `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
- List tmux windows (`tmux list-windows -t pair`) and confirm only `CLI` exists.
- Inspect the stream directory to verify `stream-*.log` chunks and the `latest.log` link.
- Stop the session.

### 4.2 Split Mode
- Launch: `./pair_stream.sh start --mode split --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
- Attach and verify the `VIEW` window has `watch` (top) and `tail` (bottom) panes.
- Stop the session.

### 4.3 Advanced Mode
- Launch: `./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
- Confirm the `VIEW` window as above.
- Ensure the `CODEX` window starts `codex_reader.py` (top) and tails `solutions.log` (bottom).
- Verify `$OUT_DIR/solutions.log` fills with messages.
- Stop the session.

## 5. Backend Selection and Parity
### 5.1 Force rotatelogs
1. Confirm availability: `command -v rotatelogs`.
2. Start with `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b rotatelogs`.
3. Check `$STREAM_DIR` for canonical filenames (`stream-YYYYMMDD-HHMM.log`).
4. Stop the session.

### 5.2 Force Python backend
1. Start with `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b python`.
2. After at least one interval, confirm chunk naming remains canonical with no suffixes.
3. Stop and immediately start again to verify the same current chunk is reused.
4. Stop the session.

### 5.3 Auto mode fallback
1. Hide `rotatelogs` temporarily: `PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b auto`.
2. Observe startup output indicating `backend: python`.
3. Restore `PATH` and stop the session.

## 6. Rotation Behaviour
1. Run `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3`.
2. Wait ~35 seconds.
3. Inspect `$STREAM_DIR`:
   - Expect only three `stream-*.log` files plus `latest.log`.
   - Timestamps should increment every 10 seconds.
4. Confirm `latest.log` points to the newest chunk: `readlink "$STREAM_DIR/latest.log"`.
5. Stop the session.

## 7. Demo Mode Without Custom Command
1. Start: `./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
2. Attach to ensure the demo loop produces output.
3. Stop the `demo` session: `./pair_stream.sh stop --session demo`.

## 8. Error Handling
1. Remove the backend script: `rm "$SCRIPTS_DIR/rotate.py"` and run `./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR"` → expect an error about the missing script.
2. Restore the file and continue: `cp rotate.py "$SCRIPTS_DIR/rotate.py"`.
3. Start a session twice in a row to confirm the second attempt reports the session already exists and exits cleanly.

## 9. Cleanup
- Stop any remaining sessions (`./pair_stream.sh stop --session pair`, etc.).
- Remove the temporary workspace when finished: `rm -rf "$PS_WORKDIR"`.

Following this manual validates tmux orchestration, mode layouts, backend parity, rotation guarantees, Codex integration, and error handling across arbitrary directories.
