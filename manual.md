# Testing Manual for pair_stream Toolkit

Follow the sections in order. Every command block can be pasted directly into a shell running in the repository root.

## 1. Workspace Setup
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
```bash
./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
```

## 3. Core Lifecycle
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
```

## 4. Mode Layouts
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

## 5. Backend Selection
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

## 6. Rotation Behaviour
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3
sleep 35
ls -lt "$STREAM_DIR"
readlink "$STREAM_DIR/latest.log"
./pair_stream.sh stop
```

## 7. Demo Mode Without Command
```bash
./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop --session demo
```

## 8. Error Handling
```bash
rm "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR" || true
cp rotate.py "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" || true
./pair_stream.sh stop
```

## 9. Cleanup
```bash
./pair_stream.sh stop --session pair || true
rm -rf "$PS_WORKDIR"
unset PS_WORKDIR STREAM_DIR OUT_DIR SCRIPTS_DIR
```
