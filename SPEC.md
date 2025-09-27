3) Käyttö
Perus (single panel):
./pair_stream.sh start --mode basic --cmd 'ssh user@router'
Jaettu näkymä (watch + tail):
./pair_stream.sh start --mode split --cmd 'ssh user@router'
Advanced (jaettu + Codex + SPEC.md):
# Rotatelogs löytyy → käytetään sitä; muuten: -b python tai auto fallback
./pair_stream.sh start --mode advanced -b auto --cmd 'ssh user@router'
Tässä advanced-tilassa:
Ikkuna CLI: työskentelet normaalisti.
Ikkuna VIEW: yläpaneeli näyttää tiedostolistauksen, alapaneeli tailaa latest.log:ia.
Ikkuna CODEX: yläpanee­li käynnistää codex_reader.py (lukee streamia, tuottaa ohjeet), alapaneeli tail -F out/solutions.log.
SPEC.md löytyy suoraan streams/-kansiosta ja kertoo logiformaatin.
