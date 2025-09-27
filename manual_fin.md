# Testausohjeet pair_stream-työkalulle

Ohjeet kattavat `pair_stream.sh`-skriptin ja `rotate.py`-taustaprosessin testauksen ilman kotihakemisto-olettamuksia. Valitse vapaasti testiympäristö.

## 1. Esivaatimukset
- Asennettuna `tmux`, `python3`, `bash` sekä haluttaessa Apache `rotatelogs`.
- Varmista, että `pair_stream.sh` ja `rotate.py` ovat suoritettavia (`chmod +x pair_stream.sh rotate.py`).
- Valitse työtilan juuripolku ja aseta apupolut (muuta tarpeen mukaan):
  ```bash
  export PS_WORKDIR="$(pwd)/pair_test"
  export STREAM_DIR="$PS_WORKDIR/streams"
  export OUT_DIR="$PS_WORKDIR/out"
  export SCRIPTS_DIR="$PS_WORKDIR/scripts"
  mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
  ```
- Kopioi `rotate.py` käytettävään skriptihakemistoon: `cp rotate.py "$SCRIPTS_DIR/rotate.py"`.

## 2. Lähtötilan nollaus
1. Pysäytä mahdollinen aiempi sessio: `./pair_stream.sh stop --session pair || true`.
2. Poista vanhat artefaktit: `rm -rf "$STREAM_DIR" "$OUT_DIR"`.
3. Luo puhtaat hakemistot yllä olevilla komennoilla ja kopioi `rotate.py` takaisin tarvittaessa.

## 3. Peruskomentojen tarkistus
1. Käynnistä oletussessio: `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
2. Tarkista tila: `./pair_stream.sh status --dir "$STREAM_DIR" --out "$OUT_DIR"` → odota viestiä "Session 'pair' is running." ja polkua `SPEC.md`:hen.
3. Liity tmuxiin (`./pair_stream.sh attach`) ja varmista demo-silmukan tulosteet (irrota `Ctrl+b d`).
4. Pysäytä sessio: `./pair_stream.sh stop` ja varmista statuksesta, että sessio ei ole käynnissä.

## 4. Tilojen testaus
### 4.1 Basic-tila
- Suorita `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
- Listaa tmux-ikkunat (`tmux list-windows -t pair`) ja varmista, että vain `CLI` on olemassa.
- Tarkista, että `stream-*.log`-tiedostot ja `latest.log`-linkki syntyvät `$STREAM_DIR`-polkuun.
- Pysäytä sessio.

### 4.2 Split-tila
- Suorita `./pair_stream.sh start --mode split --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
- Liity tmuxiin ja varmista `VIEW`-ikkunan `watch`- (ylä) ja `tail`- (ala) paneelit.
- Pysäytä sessio.

### 4.3 Advanced-tila
- Suorita `./pair_stream.sh start --mode advanced --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
- Varmista `VIEW`-paneelit kuten split-tilassa.
- Tarkista uusi `CODEX`-ikkuna: yläpaneeli suorittaa `codex_reader.py`:n ja alapaneeli tailaa `solutions.log`-tiedostoa.
- Vahvista, että `$OUT_DIR/solutions.log` saa kirjauksia.
- Pysäytä sessio.

## 5. Backendien valinta ja yhdenmukaisuus
### 5.1 rotatelogs pakotettuna
1. Varmista saatavuus: `command -v rotatelogs`.
2. Käynnistä `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b rotatelogs`.
3. Tarkista, että `$STREAM_DIR` sisältää ainoastaan muotoa `stream-YYYYMMDD-HHMM.log` olevia tiedostoja.
4. Pysäytä sessio.

### 5.2 Python-backend pakotettuna
1. Käynnistä `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b python`.
2. Odota vähintään yhden intervallin verran ja varmista, että tiedostonimet pysyvät kanonisina ilman suffikseja.
3. Pysäytä ja käynnistä heti uudelleen varmistaaksesi, että sama tiedosto jatkuu.
4. Pysäytä sessio.

### 5.3 Auto-tila ja fallback
1. Piilota `rotatelogs` väliaikaisesti: `PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" -b auto`.
2. Varmista käynnistysviestistä, että backendiksi valitaan `python`.
3. Palauta `PATH` ja pysäytä sessio.

## 6. Rotaation toiminta
1. Suorita `./pair_stream.sh start --mode basic --demo --dir "$STREAM_DIR" --out "$OUT_DIR" --interval 10 --keep 3`.
2. Odota noin 35 sekuntia.
3. Tarkista `$STREAM_DIR`:
   - Vain kolme tuoreinta `stream-*.log`-tiedostoa sekä `latest.log`.
   - Aikaleimat kasvavat 10 sekunnin välein.
4. Varmista, että `latest.log` osoittaa uusimpaan palaan: `readlink "$STREAM_DIR/latest.log"`.
5. Pysäytä sessio.

## 7. Demonstraatiotila ilman komentoa
1. Käynnistä `./pair_stream.sh start --mode basic --session demo --cmd '' --demo --dir "$STREAM_DIR" --out "$OUT_DIR"`.
2. Liity ja varmista, että demo-skripti tuottaa tulostetta.
3. Pysäytä `demo`-sessio: `./pair_stream.sh stop --session demo`.

## 8. Virhetilanteiden testaus
1. Poista backend-skripti: `rm "$SCRIPTS_DIR/rotate.py"` ja suorita `./pair_stream.sh start -b python --dir "$STREAM_DIR" --out "$OUT_DIR"` → odota virheilmoitusta puuttuvasta tiedostosta.
2. Palauta tiedosto: `cp rotate.py "$SCRIPTS_DIR/rotate.py"`.
3. Käynnistä sessio kahdesti peräkkäin ja varmista, että toinen yritys ilmoittaa session olevan jo käynnissä ja poistuu asiallisesti.

## 9. Loppusiivous
- Pysäytä kaikki auki olevat sessiot (`./pair_stream.sh stop --session pair`, jne.).
- Poista tilapäinen työtila tarpeen mukaan: `rm -rf "$PS_WORKDIR"`.

Näillä ohjeilla varmistat tmux-orkestraation, näyttötilat, backendien yhdenmukaisuuden, rotaation, Codex-integraation ja virhepolut riippumatta testipaikasta.
