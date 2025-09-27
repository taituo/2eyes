# Testausohjeet pair_stream-työkalulle

Kaikki alla olevat komennot ovat suoraan ajettavissa projektin juuresta. Mukauta sessiomuuttujia tai polkuja tarvittaessa.

## 1. Työtilan valmistelu
Suorita työtilan luonti kerran:
```bash
export PS_WORKDIR="$(pwd)/pair_test"
export STREAM_DIR="$PS_WORKDIR/streams"
export OUT_DIR="$PS_WORKDIR/out"
export SCRIPTS_DIR="$PS_WORKDIR/scripts"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
chmod +x pair_stream.sh "$SCRIPTS_DIR/rotate.py"
```

## 2. Tilanteen nollaus
Palaa puhtaaseen tilaan näillä komennoilla:
```bash
./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
```
`stop` saa raportoida onnistuneen vaikka sessiota ei olisi.

## 3. Peruskomennot
Käynnistä, tarkista, liity ja pysäytä oletussessio:
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop
./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"
```
Tmuxiin liityttyäsi näet demo-silmukan ajon; irrota `Ctrl+b d`.

## 4. Näkymätilat
Aja jokainen tila vuorollaan ja tarkista ikkunat komennolla `tmux list-windows -t pair` ennen pysäytystä.
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
Basic-tilassa näkyy vain `CLI`, split-tilassa `CLI` ja `VIEW`, advanced-tilassa lisäksi `CODEX`.

## 5. Backendien valinta
Testaa kaikki backendit ja auto-fallback.
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
Varmista jokaisella ajolla, että tiedostonimet ovat muotoa `stream-YYYYMMDD-HHMM.log` ja aloitusviesti kertoo valitun backendin.

## 6. Rotaation tarkistus
Lyhennä intervallia ja varmista säilytys ja symlinkki.
```bash
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3
sleep 35
ls -lt "$STREAM_DIR"
readlink "$STREAM_DIR/latest.log"
./pair_stream.sh stop
```
Kolmen tiedoston lisäksi pitäisi löytyä vain `latest.log`.

## 7. Demo ilman komentoa
Varmista, että demo toimii tyhjällä `--cmd`-arvolla.
```bash
./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh attach
./pair_stream.sh stop --session demo
```
Irrota tmuxista `Ctrl+b d` tarkastelun jälkeen.

## 8. Virhetestit
Tarkista puuttuvan backendin ja päällekkäisen session käsittely.
```bash
rm "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR" || true
cp rotate.py "$SCRIPTS_DIR/rotate.py"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"
./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" || true
./pair_stream.sh stop
```
Ensimmäisen aloituksen pitää epäonnistua puuttuvan `rotate.py`:n vuoksi ja toisen kertoa session olevan jo käynnissä.

## 9. Siivous
Sulje sessiot ja poista työtila tarvittaessa:
```bash
./pair_stream.sh stop --session pair || true
rm -rf "$PS_WORKDIR"
unset PS_WORKDIR STREAM_DIR OUT_DIR SCRIPTS_DIR
```
