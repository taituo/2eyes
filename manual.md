# Testing Manual for pair_stream Toolkit

All preparatory notes appear below; copy and run the single code block to exercise every feature.

```bash
# 1. Workspace setup
export PS_WORKDIR="$(pwd)/pair_test"
export STREAM_DIR="$PS_WORKDIR/streams"
export OUT_DIR="$PS_WORKDIR/out"
export SCRIPTS_DIR="$PS_WORKDIR/scripts"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
chmod +x pair_stream.sh "$SCRIPTS_DIR/rotate.py"

# 2. Reset between scenarios
./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"

# 3. Core lifecycle
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"

# 4. Mode layouts
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
# expect tmux to show "CLI Panel"
tmux list-windows -t pair
./pair_stream.sh stop
./pair_stream.sh start --mode split --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
# expect "CLI Panel" and "Streams Panel" windows
tmux list-windows -t pair
./pair_stream.sh stop
./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
# expect "CLI Panel", "Streams Panel", "Advisor Panel"
tmux list-windows -t pair
./pair_stream.sh stop

# optional: auto-run your Codex CLI (replace with your command)
# ./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR" \
#   --codex-cd "$PS_WORKDIR" \
#   --codex-cmd "codex exec --cd '$PS_WORKDIR' --dangerously-bypass-approvals-and-sandbox -m gpt-4.1 '<prompt>'"
# ./pair_stream.sh stop
# optional: use built-in advisor stub instead of an interactive shell
./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --codex-stub
tmux list-windows -t pair
./pair_stream.sh stop

# 5. Backend selection
command -v rotatelogs
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b rotatelogs
ls "$STREAM_DIR"
./pair_stream.sh stop
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b python
ls "$STREAM_DIR"
./pair_stream.sh stop
PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b auto
./pair_stream.sh stop

# 6. Rotation behaviour
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3
sleep 35
ls -lt "$STREAM_DIR"
readlink "$STREAM_DIR/latest.log"
./pair_stream.sh stop

# 7. Demo mode without command
./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop --session demo

# 8. Error handling
rm "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR" || true
cp rotate.py "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" || true
./pair_stream.sh stop

# 9. Cleanup
./pair_stream.sh stop --session pair || true
rm -rf "$PS_WORKDIR"
unset PS_WORKDIR STREAM_DIR OUT_DIR SCRIPTS_DIR
```
