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
   powershell -ExecutionPolicy Bypass -File .\Sposta-SessioniClaude_v1.6_2026-10-26_2001.ps1
   ```

3. A sinistra e a destra scegli i due account (qualsiasi coppia: sono rilevati da soli). Con **Rinomina account...** dai loro un nome (es. `personale`, `lavoro`): viene salvato in `sposta-config.json` accanto allo script (vedi `sposta-config.example.json`). Senza nome compaiono come `account-<8 caratteri>`.
4. Seleziona le sessioni e premi **→** o **←**. Consiglio: la prima volta spunta **Solo anteprima**.

### Colori e allineamento

- Le righe dello **stesso progetto** (stessa cartella di lavoro) hanno lo **stesso colore** in entrambi i pannelli, con una riga di intestazione "cartella" sopra e uno spazio tra un progetto e l'altro.
- Le sessioni presenti in **tutti e due** gli account stanno sulla **stessa riga**; dove manca c'è una riga grigia vuota. I pannelli scorrono insieme.
- Ordine: per progetto (il più recente prima), poi per ultima attività. Le intestazioni non ordinano (romperebbe l'allineamento).

### Riga di comando

```powershell
$t = ".\Sposta-SessioniClaude_v1.6_2026-10-26_2001.ps1"
powershell -ExecutionPolicy Bypass -File $t -Da personale -A lavoro -Prova
powershell -ExecutionPolicy Bypass -File $t -Da lavoro -A personale -Modalita Copia -Riavvia
powershell -ExecutionPolicy Bypass -File $t -Ripristina ".\registri\sposta_<data-ora>.csv"
```

`-Da` e `-A` accettano l'etichetta, l'UUID dell'account o i suoi primi caratteri (almeno 4).

## Avvertenze

- Riprendendo una sessione con l'altro account l'app mostra "can't use thinking from another organization": è normale, la prima risposta costa più token.
- Non tenere la stessa sessione aperta con due account insieme (app e terminale).
- La modalità Sposta/Copia chiude l'app desktop (prima in modo pulito, poi forzato) e la riapre se vuoi.

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
   powershell -ExecutionPolicy Bypass -File .\Sposta-SessioniClaude_v1.6_2026-10-26_2001.ps1
   ```

3. Pick the two accounts in the left and right panes (any pair: they are detected automatically). Use **Rinomina account...** (Rename account) to give them names (e.g. `personal`, `work`): they are saved in `sposta-config.json` next to the script (see `sposta-config.example.json`). Without a name they show as `account-<8 chars>`.
4. Select sessions and press **→** or **←**. Tip: tick **Solo anteprima** (preview only) the first time.

The UI labels are in Italian.

#### Colors and alignment

- Rows of the **same project** (same working folder) get the **same color** in both panes, with a "folder" header row above and a gap between projects.
- Sessions present in **both** accounts sit on the **same row**; a grey blank row fills the gap on the other side. The panes scroll together.
- Order: by project (most recent first), then by last activity. Column headers do not sort (it would break the alignment).

#### Command line

```powershell
$t = ".\Sposta-SessioniClaude_v1.6_2026-10-26_2001.ps1"
powershell -ExecutionPolicy Bypass -File $t -Da personal -A work -Prova          # -Prova = dry run
powershell -ExecutionPolicy Bypass -File $t -Da work -A personal -Modalita Copia -Riavvia
powershell -ExecutionPolicy Bypass -File $t -Ripristina ".\registri\sposta_<date-time>.csv"
```

`-Da` / `-A` accept the label, the account UUID, or its first characters (at least 4).

### Caveats

- When you resume a session with the other account the app shows "can't use thinking from another organization": that is normal, the first reply costs more tokens.
- Do not keep the same session open with two accounts at once (app and terminal).
- Move/Copy closes the desktop app (gracefully first, forced after 15 s) and can reopen it afterwards.

### Files

| File | Content |
|---|---|
| `Sposta-SessioniClaude_v*.ps1` | the script |
| `sposta-config.example.json` | example account labels (copy it to `sposta-config.json`) |
| `changelog.md` | version history |
