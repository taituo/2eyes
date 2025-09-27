# Testausohjeet pair_stream-työkalulle

Tämä ohjeistus kattaa kaikki `pair_stream.sh`-skriptin ja Python-kiertokäsittelijän (`rotate.py`) ominaisuudet. Suorita vaiheet järjestyksessä testiympäristössä ja palauta tila tarvittaessa puhtaaksi skenaarioiden välillä.

## 1. Esivaatimukset
- Asennettuna `tmux`, `python3` ja `bash`.
- Valinnaisesti `rotatelogs` (Apache), jotta myös se backend voidaan testata.
- Sijoita `pair_stream.sh` ja `rotate.py` testihakemistoon ja varmista suoritusoikeudet (`chmod +x pair_stream.sh rotate.py`).
- Tarkista, että hakemistot `$HOME/pair/streams`, `$HOME/pair/out` ja `$HOME/pair/scripts` ovat kirjoitettavissa (luo ne tarvittaessa).

## 2. Lähtötilan nollaus
1. Pysäytä mahdollinen aiempi sessio: `./pair_stream.sh stop --session pair || true`.
2. Poista vanhat artefaktit: `rm -rf ~/pair/streams ~/pair/out`.
3. Luo perushakemistot: `mkdir -p ~/pair/streams ~/pair/out ~/pair/scripts`.
4. Kopioi uusin `rotate.py` polkuun `~/pair/scripts/rotate.py`.

## 3. Peruskomentojen tarkistus
1. Käynnistä oletussessio: `./pair_stream.sh start --mode basic --demo`.
2. Uudessa terminaalissa tarkista tila: `./pair_stream.sh status` → odota viestiä "Session 'pair' is running." ja polku `SPEC.md`:hen.
3. Liity sessioon ( `./pair_stream.sh attach` ) ja varmista, että demo-silmukka tuottaa rivejä (`Ctrl+b d` irrottaa).
4. Pysäytä sessio: `./pair_stream.sh stop` ja varmista, että `status` ilmoittaa sen päättyneeksi.

## 4. Tilojen testaus
### 4.1 Basic-tila
- Suorita `./pair_stream.sh start --mode basic --demo`.
- Varmista, että tmuxissa on vain `CLI`-ikkuna (`tmux list-windows -t pair`).
- Tarkista, että `~/pair/streams` sisältää logipaloja ja `latest.log` osoittaa käynnissä olevaan tiedostoon.
- Pysäytä sessio.

### 4.2 Split-tila
- Suorita `./pair_stream.sh start --mode split --demo`.
- Liity tmuxiin ja varmista `VIEW`-ikkunan kaksi paneelia: ylhäällä `watch`, alhaalla `tail` `latest.log`:sta.
- Pysäytä sessio.

### 4.3 Advanced-tila
- Suorita `./pair_stream.sh start --mode advanced --demo`.
- Varmista `VIEW`-paneelien toiminta kuten split-tilassa.
- Varmista uuden `CODEX`-ikkunan kaksi paneelia:
  - Yläpaneeli suorittaa `codex_reader.py`, joka kirjoittaa viestin `~/pair/out/solutions.log`-tiedostoon.
  - Alapaneeli tailaa `solutions.log`-tiedostoa jatkuvasti.
- Pysäytä sessio.

## 5. Backendien valinta ja yhtenäisyys
### 5.1 rotatelogs-pakotettu
1. Varmista `rotatelogs` komennolla `command -v rotatelogs`.
2. Käynnistä: `./pair_stream.sh start --mode basic --demo -b rotatelogs`.
3. Tarkista `~/pair/streams` → tiedostonimet muodossa `stream-YYYYMMDD-HHMM.log` ilman suffikseja.
4. Pysäytä sessio.

### 5.2 Python-backend pakotettuna
1. Käynnistä: `./pair_stream.sh start --mode basic --demo -b python`.
2. Odota minuutti ja varmista, että uusi pala syntyy ilman `_1`-tyylisiä suffikseja.
3. Käynnistä sessio uudelleen heti pysäytyksen jälkeen ja varmista, että sama tiedosto jatkaa täyttymistään (ei uusia suffikseja).
4. Pysäytä sessio.

### 5.3 Auto-backend ja fallback
1. Peitä `rotatelogs` tilapäisesti: `PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo -b auto`.
2. Tarkista käynnistysviestistä, että backendiksi valikoituu `python`.
3. Palaa normaaliin PATH:iin ja pysäytä sessio.

## 6. Rotaation toiminta
1. Käynnistä lyhyellä intervallilla: `./pair_stream.sh start --mode basic --demo --interval 10 --keep 3`.
2. Odota noin 35 sekuntia.
3. Tarkista `~/pair/streams`:
   - Vain kolme tuoreinta `stream-*.log` -tiedostoa + `latest.log`.
   - Aikaleimat kasvavat 10 sekunnin välein.
4. Varmista, että `latest.log`-symlinkki päivittyy (`readlink ~/pair/streams/latest.log`).
5. Pysäytä sessio.

## 7. Demonstraatiotila ilman komentoa
1. Suorita: `./pair_stream.sh start --mode basic --session demo --cmd '' --demo`.
2. Liity session ja varmista, että demo-silmukka täyttää logit ilman erillistä komentoa.
3. Pysäytä `demo`-sessio.

## 8. Virhetilanteiden testaus
1. Poista `~/pair/scripts/rotate.py` ja kokeile `./pair_stream.sh start -b python` → odota virheilmoitusta puuttuvasta tiedostosta.
2. Palauta skripti ja jatka testejä.
3. Käynnistä sessio kahdesti peräkkäin varmistaaksesi, että skripti ilmoittaa jo käynnissä olevasta sessiosta ja poistuu asiallisesti.

## 9. Loppusiivous
- Suorita `./pair_stream.sh stop --session pair` ja muut mahdolliset sessiot.
- Poista testihakemistot tarvittaessa: `rm -rf ~/pair/streams ~/pair/out ~/pair/scripts/codex_reader.py`.

Näiden ohjeiden avulla varmistat tmux-orkestroinnin, tilojen näkymät, backendien yhdenmukaisuuden, rotaation, Codex-integraation sekä virhepolut spesifikaation mukaisesti.
