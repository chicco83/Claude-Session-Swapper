# Changelog — Sposta-SessioniClaude

**Versione corrente:** 1.4 — 2026-10-26 19:58 (Europe/Rome)

## v1.4 — 2026-10-26 19:58
- **Tasto destro → "Esegui con PowerShell":** lo script si rilancia da solo in modalità STA (necessaria a WPF; PowerShell 7 non lo è di default) con `-ExecutionPolicy Bypass` solo per il proprio processo; un `trap` mostra gli errori e aspetta Invio invece di chiudere la finestra di colpo.
- **Verificato:** parser PowerShell 0 errori. **Non provato:** l'avvio da tasto destro (non lanciabile da una sessione Claude). Se Windows blocca il file scaricato da internet: tasto destro → Proprietà → Sblocca.
- **Rollback:** `Sposta-SessioniClaude_v1.3_2026-10-26_1943.ps1` (nel repo ignorata da git dopo questa versione).

## v1.3 — 2026-10-26 19:43
- **Colori per progetto:** le righe con la stessa cartella di lavoro hanno lo stesso colore (palette di 12, assegnata in ordine alfabetico sull'unione delle due liste) in entrambi i pannelli.
- **Allineamento:** una sessione presente in entrambi gli account sta sulla stessa riga nei due pannelli; dove manca c'è una riga vuota grigia non selezionabile; i pannelli scorrono insieme. Ordine: per progetto (più recente prima), poi per ultima attività; ordinamento dalle intestazioni disattivato.
- **Portabile:** tolti gli UUID dal codice; gli account si rilevano da soli, le etichette stanno in `sposta-config.json` (pulsante **Rinomina account...**; esempio in `sposta-config.example.json`), senza etichetta `account-<uuid8>`. `-Da`/`-A` accettano anche l'inizio dell'UUID (≥ 4 caratteri).
- Aggiunti `README.md` (italiano e inglese), `sposta-config.example.json`, `.gitignore` (esclude config personale e registri).
- Update-Lato/Apply-Filtro della v1.2 e le etichette fisse restano commentati nel file.
- **Verificato:** il file passa il parser PowerShell (0 errori). **Non provato:** finestra, colori, allineamento e scorrimento sincronizzato (non lanciato da una sessione Claude, vedi CLAUDE.md).
- **Rollback:** usare `Sposta-SessioniClaude_v1.2_2026-10-26_1635.ps1` (non toccata); per le etichette serve allora `$Etichette` nel codice.

## v1.2 — 2026-10-26 16:35
- Finestra a **due pannelli** (un account per lato, come FileZilla) con frecce → e ← al centro; ricerca per pannello; colonna "Anche nell'altro"; casella "Solo anteprima" (le frecce scrivono nel registro cosa farebbero, senza modificare nulla).
- Write-Host sostituito da Write-Log (messaggi anche nella finestra). Finestra v1.1 conservata commentata in fondo al file.
- **Non provata su Windows**: controllati solo XAML e bilanciamento delle parentesi.

## v1.1 — 2026-10-26 16:25
- Prima interfaccia grafica (WPF, pannello unico) quando si lancia senza parametri; `-NoGui` forza la riga di comando.
- Operazioni estratte in funzioni (`Invoke-Operazione`, `Invoke-Ripristino`) usate da finestra e riga di comando.
- Provata dall'utente: la finestra si apre e l'Anteprima scrive `[prova] Sposta '<titolo>'` senza modificare nulla (16:17).

## v1.0 — 2026-10-26 16:15
- Prima versione, solo riga di comando (selezione con Out-GridView): `-Da`, `-A`, `-Modalita Sposta|Copia`, `-Sessioni`, `-Riavvia`, `-Prova`, `-Ripristina`.
- Chiude da solo l'app desktop (pulito, poi forzato dopo 15 s) e la riapre; avviso sui processi Claude da terminale; backup delle schede tolte; registro CSV (`;`) in `tools\registri\`.

## Precedente alla v1.0 — 2026-10-26 16:05
- `tools\prova_condivisione_sessione_v0.1_2026-10-26_1605.py`: copia manuale di una scheda ("Script automazione proroga utenti") dall'account personale a quello di lavoro. Riuscita: la sessione compare e riprende, con l'avviso sul thinking di un'altra organizzazione.
