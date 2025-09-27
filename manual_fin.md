# Testausohjeet pair_stream-työkalulle

Kaikki valmistelut ovat alla; kopioi ja aja yksi komentolista.

```bash
# 1. Työtilan valmistelu
export PS_WORKDIR="$(pwd)/pair_test"
export STREAM_DIR="$PS_WORKDIR/streams"
export OUT_DIR="$PS_WORKDIR/out"
export SCRIPTS_DIR="$PS_WORKDIR/scripts"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
chmod +x pair_stream.sh "$SCRIPTS_DIR/rotate.py"

# 2. Tilanteen nollaus
./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"

# 3. Peruskomennot
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"

# 4. Näkymätilat
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
# odota tmux-listauksessa vain "CLI Panel"
tmux list-windows -t pair
./pair_stream.sh stop
./pair_stream.sh start --mode split --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
# odota ikkunat "CLI Panel" ja "Streams Panel"
tmux list-windows -t pair
./pair_stream.sh stop
./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
# odota ikkunat "CLI Panel", "Streams Panel", "Advisor Panel"
tmux list-windows -t pair
./pair_stream.sh stop

# 5. Backendien valinta
command -v rotatelogs
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b rotatelogs
ls "$STREAM_DIR"
./pair_stream.sh stop
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b python
ls "$STREAM_DIR"
./pair_stream.sh stop
PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b auto
./pair_stream.sh stop

# 6. Rotaation tarkistus
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3
sleep 35
ls -lt "$STREAM_DIR"
readlink "$STREAM_DIR/latest.log"
./pair_stream.sh stop

# 7. Demo ilman komentoa
./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop --session demo

# 8. Virhetestit
rm "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR" || true
cp rotate.py "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" || true
./pair_stream.sh stop

# 9. Siivous
./pair_stream.sh stop --session pair || true
rm -rf "$PS_WORKDIR"
unset PS_WORKDIR STREAM_DIR OUT_DIR SCRIPTS_DIR
```
