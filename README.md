# Under Falling Skies – versione digitale

Versione digitale per uso personale del solitario **Under Falling Skies** (Tomáš Uhlíř, Czech Games Edition;
edizione italiana Cranio Creations), con il gioco base e la **campagna in quattro capitoli**.

Si gioca qui: https://tannoiser2.github.io/Under-Falling-Skyes/

## Cosa c'è

- **Gioco base** con le città, i lati danneggiati, le tessere cielo sui due lati e il livello di minaccia.
- **Partita singola** a scelta libera: città, scenario, fino a tre personaggi (normali o promossi), tessere cielo
  (anche quelle avanzate dei capitoli 2, 3 e 4) con il calcolo del livello di difficoltà come nel regolamento.
- **Campagna**: pile casuali di città, scenario e personaggio, seconda partita sul lato danneggiato, personaggi promossi,
  quinta città del Capitolo 2 che esce di scena, tessere cielo avanzate, stanze comando e verticali, teletrasporti,
  esplosioni rosse, satellite della Battaglia Finale, diario e punteggio finale.
- Tutte le 17 città, i 13 scenari e i 12 personaggi della campagna, con le abilità di città e personaggi.
- **Tabellone 3D** con le tessere originali italiane (scansioni) e le immagini del modulo TTS; navi aliene (viola,
  bianche, arancione) ed escavatore modellati in Blender; dadi lavoratore grigi e bianchi, robot blu.
  Due inquadrature affiancate (cielo e base) più una **vista 3D** libera da far ruotare con il mouse.
- **Salvataggi**: in locale a ogni mossa e online su Firebase alla fine di ogni turno, con un codice di 6 caratteri
  per riprendere la partita o la campagna da un altro dispositivo.

## Struttura

- `scripts/motore.gd` – regole (stato in un dizionario serializzabile).
- `scripts/campagna.gd` – svolgimento della campagna.
- `scripts/tavolo.gd` – tabellone 3D.
- `scripts/main.gd` – interfaccia.
- `scripts/ia.gd` – giocatore automatico usato dalle prove.
- `scripts/net.gd` – salvataggi su Firebase (radice `underfallingskies`, rami `campagne` e `partite`, coperti dalla
  regola comune della ludoteca).
- `data/ufs.json` – basi A–G, tessere cielo, città, scenari e personaggi trascritti dal materiale italiano.
- `assets/` – tessere, città e personaggi ritagliati dalle scansioni, modelli 3D, font (Chakra Petch e Saira Condensed,
  licenza OFL).

## Prove

```
godot --headless --path . -s tests/partite_auto.gd      # partite automatiche con salvataggio e ricarica
godot --headless --path . -s tests/campagna_auto.gd     # campagne complete
xvfb-run godot --path . --script res://tests/screenshot.gd
python3 tools/controlla_glifi.py                         # ogni carattere esiste nei font
```

## Pubblicazione

Il workflow *Pubblica* non parte a ogni modifica: si avvia a mano (Actions → Pubblica → Run workflow) oppure con un
commit che nel messaggio contiene `[pubblica]`. Pubblica su GitHub Pages e, se ci sono i segreti di Cloudflare,
anche sulla ludoteca privata.
