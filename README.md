# Claude Session Swapper

**Italiano** · [English](#english)

Strumento PowerShell con finestra a due pannelli (stile FileZilla) che **sposta o copia le sessioni di Claude Code dell'app desktop tra due account** sullo stesso PC Windows, ad esempio personale e lavoro.

> Usa un formato di file **non documentato** da Anthropic: dopo un aggiornamento dell'app fai una prova su una sola sessione. Nessuna garanzia: usalo a tuo rischio. Non tocca mai i transcript e non cancella nulla (le schede tolte vanno in backup).

## Come funziona

Una sessione compare nell'app solo nell'account che ha la sua "scheda" (`local_<id>.json` in `%LOCALAPPDATA%\Claude-Data\claude_*\claude-code-sessions\<account>\<organizzazione>\`). La conversazione vera (`~\.claude\projects\...\<id>.jsonl`) è del PC e comune a tutti gli account: lo script lavora **solo sulle schede**.

- **Sposta**: copia la scheda nell'altro account e mette quella di origine in `claude-code-sessions-backup\<data-ora>\`.
- **Copia (in entrambi)**: la sessione compare in tutti e due gli account; il lavoro si somma nello stesso transcript.
- Ogni esecuzione scrive un registro CSV in `registri\`; **Ripristina...** la annulla.

## Requisiti

- Windows 10/11, app desktop di Claude, PowerShell 5.1 (quello di Windows, senza admin).
- I due account devono essere stati aperti almeno una volta nell'app.

## Uso

1. Scarica `Sposta-SessioniClaude_v*.ps1` e salvalo in una cartella tua.
2. Tasto destro sul file → **Esegui con PowerShell** (oppure da una finestra PowerShell normale; **non** da una sessione Claude: lo script chiude l'app desktop). Se il file arriva da internet: tasto destro → Proprietà → **Sblocca**. Da PowerShell:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Sposta-SessioniClaude_v1.7_2026-10-26_2004.ps1
   ```

3. A sinistra e a destra scegli i due account (qualsiasi coppia: sono rilevati da soli). Con **Rinomina account...** dai loro un nome (es. `personale`, `lavoro`): viene salvato in `sposta-config.json` accanto allo script (vedi `sposta-config.example.json`). Senza nome compaiono come `account-<8 caratteri>`.
4. La finestra di PowerShell resta nascosta dietro alla finestra grafica (per vederla: parametro `-MostraConsole`).
5. Seleziona le sessioni e premi **→** o **←**. Consiglio: la prima volta spunta **Solo anteprima**.

### Colori e allineamento

- Le righe dello **stesso progetto** (stessa cartella di lavoro) hanno lo **stesso colore** in entrambi i pannelli, con una riga di intestazione "cartella" sopra e uno spazio tra un progetto e l'altro.
- Le sessioni presenti in **tutti e due** gli account stanno sulla **stessa riga**; dove manca c'è una riga grigia vuota. I pannelli scorrono insieme.
- Ordine: per progetto (il più recente prima), poi per ultima attività. Le intestazioni non ordinano (romperebbe l'allineamento).

### Sincronizzazione automatica all'avvio

All'apertura della finestra lo script controlla da solo tutte le coppie di account e allinea le sessioni presenti in più account: **archiviata in uno = archiviata in tutti** e **scheda più vecchia aggiornata con la più recente** (così, passando da un account all'altro, trovi sempre la versione aggiornata). Se l'app Claude è aperta chiede una sola conferma, perché va chiusa e riaperta; se è chiusa non chiede nulla. Il pulsante **Sincronizza ora** ripete il controllo durante l'uso. Nella riga di stato un **contatore** mostra quante schede sono state archiviate e aggiornate in questo avvio e in totale (`sposta-statistiche.json`, accanto allo script). Per disattivarla: `-NoSincAvvio` oppure `"sincAvvio": false` in `sposta-config.json`.

### Archiviazione sincronizzata

Lo stato "archiviata" sta nella scheda di ciascun account: archiviando una sessione conclusa in un account, nell'altro resta attiva. All'avvio (o con `-SincArchiviate`, `-Da` e `-A`) lo script archivia nell'altro account le sessioni presenti in entrambi che sono archiviate in uno solo. Regola: archiviata in uno = archiviata in entrambi; il ripristino dall'archivio non si propaga. Prima di modificare la scheda ne tiene una copia di backup e scrive il registro, quindi **Ripristina...** la annulla.

### Schede aggiornate alla più recente

Una sessione presente in due account ha due schede: se la usi con un solo account, solo la sua scheda si aggiorna (data, titolo, turni), l'altra resta indietro. All'avvio (o con `-SincRecenti`, `-Da` e `-A`) lo script aggiorna, per ogni sessione presente in entrambi, la scheda più vecchia con i dati di quella più recente (titolo, data di ultima attività, turni completati, ultima risposta, modello). Non copia ciò che è proprio dell'account (connettori, controllo remoto, archiviazione). La conversazione è già comune e non viene toccata. Backup e registro come per le altre operazioni.

### Riga di comando

```powershell
$t = ".\Sposta-SessioniClaude_v1.7_2026-10-26_2004.ps1"
powershell -ExecutionPolicy Bypass -File $t -Da personale -A lavoro -Prova
powershell -ExecutionPolicy Bypass -File $t -Da lavoro -A personale -Modalita Copia -Riavvia
powershell -ExecutionPolicy Bypass -File $t -Da personale -A lavoro -SincArchiviate
powershell -ExecutionPolicy Bypass -File $t -Da personale -A lavoro -SincRecenti
powershell -ExecutionPolicy Bypass -File $t -Ripristina ".\registri\sposta_<data-ora>.csv"
```

`-Da` e `-A` accettano l'etichetta, l'UUID dell'account o i suoi primi caratteri (almeno 4).

## Avvertenze

- Riprendendo una sessione con l'altro account l'app mostra "can't use thinking from another organization": è normale, la prima risposta costa più token.
- Non tenere la stessa sessione aperta con due account insieme (app e terminale).
- La modalità Sposta/Copia chiude l'app desktop (prima in modo pulito, poi forzato) e la riapre se vuoi.

## Problemi comuni

| Messaggio o sintomo | Causa | Cosa fare |
|---|---|---|
| "Cartella claude-code-sessions dell'app desktop non trovata" | app non installata o percorso diverso | verifica `%LOCALAPPDATA%\Claude-Data` e `%APPDATA%\Claude` |
| "I due lati mostrano lo stesso account" / un solo account | il secondo account non è mai stato aperto nell'app su questo PC | apri l'app una volta con l'altro account, poi **Aggiorna** |
| "non ha ancora una cartella organizzazione" | account mai aperto fino in fondo | apri l'app con quell'account |
| gli account si chiamano `account-541e1365` | nessun nome salvato | **Rinomina account...** |
| la sessione non compare nell'altro account | formato delle schede cambiato dopo un aggiornamento dell'app | **Ripristina...** e rifai la prova con una sessione |
| l'app non si chiude o non si riapre | nome del processo o del menu Start diverso | chiudila/riaprila a mano |
| la finestra non si apre | errore all'avvio, la console è nascosta | lancia con `-MostraConsole` |

Limiti: solo Windows; vede solo gli account dell'utente Windows corrente; con più organizzazioni nello stesso account la sessione va in quella con più schede.

## File

| File | Contenuto |
|---|---|
| `Sposta-SessioniClaude_v*.ps1` | lo script |
| `sposta-config.example.json` | esempio di etichette per gli account (copialo in `sposta-config.json`) |
| `changelog.md` | cronologia delle versioni |

---

## English

[Italiano](#claude-session-swapper)

A PowerShell tool with a two-pane window (FileZilla style) that **moves or copies Claude Code desktop-app sessions between two accounts** on the same Windows PC, e.g. personal and work.

> It relies on a file format that Anthropic has **not documented**: after an app update, test it on a single session first. No warranty, use at your own risk. It never touches transcripts and never deletes anything (removed cards go to a backup folder).

### How it works

A session shows up in the app only under the account that owns its "card" (`local_<id>.json` in `%LOCALAPPDATA%\Claude-Data\claude_*\claude-code-sessions\<account>\<organization>\`). The actual conversation (`~\.claude\projects\...\<id>.jsonl`) belongs to the PC and is shared by all accounts: the script works **only on the cards**.

- **Move**: copies the card to the other account and puts the original in `claude-code-sessions-backup\<date-time>\`.
- **Copy (in both)**: the session appears in both accounts; work accumulates in the same transcript.
- Every run writes a CSV log to `registri\`; **Ripristina...** (Restore) undoes it.

### Requirements

- Windows 10/11, the Claude desktop app, PowerShell 5.1 (the built-in one, no admin rights).
- Both accounts must have been opened in the app at least once.

### Usage

1. Download `Sposta-SessioniClaude_v*.ps1` and save it in a folder of your own.
2. Right-click the file → **Run with PowerShell** (or use a regular PowerShell window; **not** from a Claude session: the script closes the desktop app). If the file was downloaded, right-click → Properties → **Unblock**. From PowerShell:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Sposta-SessioniClaude_v1.7_2026-10-26_2004.ps1
   ```

3. Pick the two accounts in the left and right panes (any pair: they are detected automatically). Use **Rinomina account...** (Rename account) to give them names (e.g. `personal`, `work`): they are saved in `sposta-config.json` next to the script (see `sposta-config.example.json`). Without a name they show as `account-<8 chars>`.
4. The PowerShell window stays hidden behind the GUI (to see it: `-MostraConsole`).
5. Select sessions and press **→** or **←**. Tip: tick **Solo anteprima** (preview only) the first time.

The UI labels are in Italian.

#### Colors and alignment

- Rows of the **same project** (same working folder) get the **same color** in both panes, with a "folder" header row above and a gap between projects.
- Sessions present in **both** accounts sit on the **same row**; a grey blank row fills the gap on the other side. The panes scroll together.
- Order: by project (most recent first), then by last activity. Column headers do not sort (it would break the alignment).

#### Automatic sync at startup

When the window opens the script checks every pair of accounts by itself and aligns the sessions present in more than one account: **archived in one = archived in all** and **older card updated with the most recent one** (so when you switch accounts you always find the up-to-date version). If the Claude app is open it asks for a single confirmation, because the app must be closed and reopened; if it is closed it asks nothing. The **Sincronizza ora** button repeats the check while you work. A **counter** in the status line shows how many cards were archived and updated in this run and in total (`sposta-statistiche.json`, next to the script). To turn it off: `-NoSincAvvio` or `"sincAvvio": false` in `sposta-config.json`.

#### Synchronized archiving

The "archived" state lives in each account's card: archiving a finished session in one account leaves it active in the other. At startup (or with `-SincArchiviate`, `-Da` and `-A`) the script archives, in the other account, the sessions present in both that are archived in only one. Rule: archived in one = archived in both; un-archiving does not propagate. The card is backed up before it is changed and the action is logged, so **Ripristina...** undoes it.

#### Cards updated to the most recent

A session present in two accounts has two cards: if you use it with one account only, only that card is updated (date, title, turns) and the other falls behind. At startup (or with `-SincRecenti`, `-Da` and `-A`) the script updates, for every session present in both, the older card with the data of the more recent one (title, last-activity date, completed turns, last reply, model). It does not copy what belongs to the account (connectors, remote control, archiving). The conversation is already shared and is not touched. Backup and log work as for the other operations.

#### Command line

```powershell
$t = ".\Sposta-SessioniClaude_v1.7_2026-10-26_2004.ps1"
powershell -ExecutionPolicy Bypass -File $t -Da personal -A work -Prova          # -Prova = dry run
powershell -ExecutionPolicy Bypass -File $t -Da work -A personal -Modalita Copia -Riavvia
powershell -ExecutionPolicy Bypass -File $t -Da personal -A work -SincArchiviate
powershell -ExecutionPolicy Bypass -File $t -Da personal -A work -SincRecenti
powershell -ExecutionPolicy Bypass -File $t -Ripristina ".\registri\sposta_<date-time>.csv"
```

`-Da` / `-A` accept the label, the account UUID, or its first characters (at least 4).

### Caveats

- When you resume a session with the other account the app shows "can't use thinking from another organization": that is normal, the first reply costs more tokens.
- Do not keep the same session open with two accounts at once (app and terminal).
- Move/Copy closes the desktop app (gracefully first, forced after 15 s) and can reopen it afterwards.

### Common problems

| Message or symptom | Cause | What to do |
|---|---|---|
| "Cartella claude-code-sessions dell'app desktop non trovata" (sessions folder not found) | app not installed or different path | check `%LOCALAPPDATA%\Claude-Data` and `%APPDATA%\Claude` |
| "I due lati mostrano lo stesso account" / only one account | the second account was never opened in the app on this PC | open the app once with the other account, then **Aggiorna** (Refresh) |
| "non ha ancora una cartella organizzazione" (no organization folder yet) | account never fully opened | open the app with that account |
| accounts are named `account-541e1365` | no saved name | **Rinomina account...** |
| the session does not show up in the other account | card format changed after an app update | **Ripristina...** and retry with one session |
| the app does not close or reopen | different process or Start menu name | close/reopen it by hand |
| the window does not open | startup error, the console is hidden | run with `-MostraConsole` |

Limits: Windows only; sees only the accounts of the current Windows user; with several organizations in one account the session goes to the one with the most cards.

### Files

| File | Content |
|---|---|
| `Sposta-SessioniClaude_v*.ps1` | the script |
| `sposta-config.example.json` | example account labels (copy it to `sposta-config.json`) |
| `changelog.md` | version history |

## Storico modifiche

| Data | Prima | Dopo | Perché |
|---|---|---|---|
| 2026-11-26 | archiviazione e ultima versione si allineavano premendo due pulsanti | sincronizzazione automatica all'avvio, un solo pulsante **Sincronizza ora**, contatore delle sincronizzazioni, `-NoSincAvvio` | farla a mano non aveva senso; backup/registri con i millisecondi |
| 2026-11-26 | usando una sessione con un solo account, la scheda dell'altro restava indietro (data, titolo, turni) | pulsante **Sincronizza alla più recente** e `-SincRecenti` | tornando sull'altro account la sessione appariva non aggiornata |
| 2026-11-26 | l'archiviazione valeva solo nell'account in cui si archiviava | pulsante **Sincronizza archiviate** e `-SincArchiviate` | una sessione conclusa restava visibile nell'altro account |
| 2026-10-26 | solo script base | aggiunti colori per progetto, righe allineate, intestazioni "cartella", account portabili, console nascosta, tabella problemi comuni | uso su altri PC e comodità di lettura |
