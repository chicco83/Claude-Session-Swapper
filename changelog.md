# Changelog — Sposta-SessioniClaude

**Versione corrente:** 1.9 — 2026-11-26 09:40 (Europe/Rome)

## v1.9 — 2026-11-26 09:26
- **Sincronizzazione sulla scheda più recente.** Prima: una sessione presente in due account ha due schede; usandola con un solo account si aggiorna solo la sua (data, titolo, turni completati, ultima risposta), l'altra resta indietro (sul PC dell'utente: 12 sessioni su 30 con data diversa, fino a 25 giorni di scarto, es. «APK nativa Tab2Monitor per GT-P5100» 30/10 → 25/11). Ora: pulsante **Sincronizza alla più recente** (e `-SincRecenti` da riga di comando con `-Da`/`-A`): per ogni sessione presente in entrambi gli account la scheda con ultima attività più vecchia riceve i campi di avanzamento di quella più recente.
- **Campi copiati:** `title`, `titleSource`, `titleTurn`, `previousTitles`, `lastActivityAt`, `completedTurns`, `postTurnSummary`, `postTurnSummaryFor`, `lastAssistantUuid`, `lastAssistantCliSessionId`, `lastTurnEdgeAt`, `latestUserFrameAt`, `lastTurnReport`, `turnWrapUp`, `model`, `effort`, `permissionMode`. **Non copiati** (propri di ogni account): `enabledMcpTools`, `remoteMcpServersConfig` (connettori), `adoptedFromOtherSurface`, `lastFocusedAt`, `bridgeSessionIds` e i campi `remoteControl*`/`steeredByRemoteClient` (controllo remoto), `promptAppendSnapshot`, `toolSurfaceSnapshot` (strumenti), `isArchived` (lo gestisce Sincronizza archiviate).
- **Sicurezza:** chiude l'app solo se c'è qualcosa da fare; copia la scheda in `claude-code-sessions-backup\<data-ora>\` prima di modificarla; registro CSV con `Azione = Aggiorna`; **Ripristina...** rimette la scheda com'era; **Solo anteprima** elenca senza modificare. Il transcript (conversazione) è già comune e non si tocca.
- **Verificato (2026-11-26):** parser PowerShell 0 errori; in sola lettura individua le 12 schede da aggiornare con la direzione giusta; su **copie** di due schede: il campo `lastActivityAt` e il titolo diventano uguali alla sorgente, `completedTurns` 29 → 33, cambiano solo i campi di avanzamento, restano intatti connettori, `adoptedFromOtherSurface`, `lastFocusedAt` e `isArchived`. **Non provato:** il pulsante e l'operazione sulle schede vere; se l'app riprende correttamente la sessione dopo l'aggiornamento della scheda; il Ripristina di un'operazione Aggiorna.
- **Rollback:** tornare alla versione precedente dello script (`Sposta-SessioniClaude_v1.8_2026-11-26_0921.ps1`, in locale); per annullare un aggiornamento già fatto: **Ripristina...** col suo registro.

## v1.8 — 2026-11-26 09:21
- **Sincronizzazione dell'archiviazione.** Prima: lo stato "archiviata" sta nella scheda di ogni account (campo `isArchived`), quindi archiviare una sessione conclusa in un account la lasciava attiva nell'altro (sul PC dell'utente: 30 sessioni presenti in entrambi, 6 con stato diverso). Ora: pulsante **Sincronizza archiviate** (e `-SincArchiviate` da riga di comando con `-Da`/`-A`) archivia nell'altro account le sessioni archiviate in uno solo.
- **Regola:** archiviata in uno = archiviata in entrambi. Il ripristino dall'archivio non si propaga (altrimenti una sessione riaperta in un account verrebbe riarchiviata dall'altro).
- **Sicurezza:** chiude l'app come le altre operazioni (solo se c'è qualcosa da fare); prima di modificare copia la scheda in `claude-code-sessions-backup\<data-ora>\`; modifica solo il campo (`"isArchived":false` → `true`), il resto del file resta identico; scrive il registro CSV con `Azione = Archivia`; **Ripristina...** rimette la scheda com'era. Con **Solo anteprima** elenca le schede senza modificare nulla.
- **Verificato (2026-11-26):** parser PowerShell 0 errori; prova in sola lettura sui due account dell'utente: individua le 6 schede con stato diverso (5 da archiviare nell'account di lavoro, 1 in quello personale); prova di scrittura su una **copia** di scheda: cambia solo `isArchived` (testo identico per il resto). **Non provato:** il pulsante e l'operazione reale sulle schede vere, il Ripristina di un'archiviazione.
- **Rollback:** tornare alla versione precedente dello script (`Sposta-SessioniClaude_v1.7_2026-10-26_2004.ps1`, in locale); per annullare un'archiviazione già fatta: **Ripristina...** col suo registro.

## Documentazione — 2026-10-26 20:20
- README: aggiunta la sezione "Problemi comuni" (italiano e inglese). Confermato dall'utente: Sposta/Copia funziona e l'app Claude si riapre correttamente dopo l'operazione (nello stesso PC).

## v1.7 — 2026-10-26 20:04
- **Console nascosta:** lanciando senza parametri lo script si rilancia in un processo PowerShell nascosto (`-WindowStyle Hidden`, STA, Bypass solo per quel processo) e chiude subito la console visibile (può restare un lampo all'avvio). Gli errori escono in una finestra di messaggio. `-MostraConsole` la lascia visibile per la diagnosi. La riga di comando non cambia.
- Provato dall'utente sulla v1.6: scorrimento sincronizzato e allineamento funzionano anche con righe di altezza diversa.
- **Verificato:** parser 0 errori. **Provato dall'utente (2026-10-26):** funziona e la finestra di PowerShell scompare.
- **Rollback:** `Sposta-SessioniClaude_v1.6_2026-10-26_2001.ps1`.

## v1.6 — 2026-10-26 20:01
- **Stile cartella:** sopra le sessioni di ogni progetto una riga di intestazione (icona cartella + nome della cartella di lavoro, grassetto, colore del progetto più scuro, percorso completo nella colonna Cartella) e una riga di spazio tra un progetto e il successivo. Identiche nei due pannelli, quindi l'allineamento resta; non selezionabili; compaiono solo se il progetto ha sessioni visibili col filtro.
- **Verificato:** parser 0 errori. **Non provato:** l'aspetto a video (colore delle intestazioni, altezza dello spazio, scorrimento con le righe di altezza diversa).
- **Rollback:** `Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1`.

## v1.5 — 2026-10-26 20:00
- **Corretto il colore per progetto**, che con la v1.4 non compariva (allineamento invece funzionante, provato dall'utente). Ipotesi sulla causa: il Binding XAML `Background="{Binding Colore}"` su oggetti PowerShell non convertiva il testo in pennello. Ora il colore è assegnato in codice a ogni riga (evento `LoadingRow`, funzione `Set-StileRiga`), come l'esclusione delle righe vuote dal clic.
- **Verificato:** parser 0 errori. **Non provato:** il colore a video (causa non confermata). Se ancora assente: controllare se le sessioni "dello stesso progetto" hanno davvero la stessa `cwd` (il colore segue la cartella di lavoro esatta).
- **Rollback:** `Sposta-SessioniClaude_v1.4_2026-10-26_1958.ps1`.

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
