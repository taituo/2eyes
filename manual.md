# Testing Manual for pair_stream Toolkit

All commands below are ready to paste into a shell running from the repository root. Adjust session names or paths if they collide with existing resources.

## 1. Workspace Setup
Run these commands once to prepare an isolated workspace:
```bash
export PS_WORKDIR="$(pwd)/pair_test"
export STREAM_DIR="$PS_WORKDIR/streams"
export OUT_DIR="$PS_WORKDIR/out"
export SCRIPTS_DIR="$PS_WORKDIR/scripts"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
chmod +x pair_stream.sh "$SCRIPTS_DIR/rotate.py"
```

## 2. Reset Between Scenarios
Use this to return to a clean state:
```bash
./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
```
Expect the `stop` command to report success even if the session was absent.

## 3. Core Lifecycle
Start, inspect, attach, and stop the default session:
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
```
While attached, you should see the demo loop printing timestamps; detach with `Ctrl+b d`.

## 4. Mode Layouts
Run each mode in turn and inspect panes via `tmux list-windows -t pair` before stopping.
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
tmux list-windows -t pair
./pair_stream.sh stop

./pair_stream.sh start --mode split --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
tmux list-windows -t pair
./pair_stream.sh stop

./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
tmux list-windows -t pair
./pair_stream.sh stop
```
Expect one window in basic mode, two in split mode (`CLI`, `VIEW`), and three in advanced mode (`CLI`, `VIEW`, `CODEX`).

## 5. Backend Selection
Exercise each backend explicitly, then trigger the auto fallback.
```bash
command -v rotatelogs
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b rotatelogs
ls "$STREAM_DIR"
./pair_stream.sh stop

./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b python
ls "$STREAM_DIR"
./pair_stream.sh stop

PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b auto
./pair_stream.sh stop
```
For each run, confirm that filenames follow `stream-YYYYMMDD-HHMM.log` and that the startup message reports the expected backend.

## 6. Rotation Behaviour
Shorten the interval and confirm file retention and symlink updates.
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3
sleep 35
ls -lt "$STREAM_DIR"
readlink "$STREAM_DIR/latest.log"
./pair_stream.sh stop
```
Only three chunk files plus `latest.log` should remain after the sleep.

## 7. Demo Mode Without Command
Verify the demo loop runs even when `--cmd` is empty.
```bash
./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop --session demo
```
Detach from tmux after confirming output.

## 8. Error Handling
Check missing-backend and duplicate-session safeguards.
```bash
rm "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR" || true
cp rotate.py "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" || true
./pair_stream.sh stop
```
Expect the first start to fail with `rotate.py` missing and the second repeated start to report that the session already exists.

## 9. Cleanup
Tear down sessions and remove the workspace when finished:
```bash
./pair_stream.sh stop --session pair || true
rm -rf "$PS_WORKDIR"
unset PS_WORKDIR STREAM_DIR OUT_DIR SCRIPTS_DIR
```
