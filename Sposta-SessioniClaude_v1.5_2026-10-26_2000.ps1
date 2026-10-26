# =============================================================================
# Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1
# Versione: 1.5 - 2026-10-26 20:00 (Europe/Rome)
# v1.5: corretto il colore delle righe per progetto (con la v1.4 non compariva): il colore non passa piu' da un
#       Binding XAML (con gli oggetti PowerShell la conversione testo -> pennello falliva in silenzio) ma e' assegnato in
#       codice a ogni riga quando la griglia la crea (evento LoadingRow). Stessa cosa per le righe vuote non cliccabili.
# (v1.4 2026-10-26 19:58: avvio da tasto destro Esegui con PowerShell)
# v1.4: funziona con tasto destro -> "Esegui con PowerShell": si rilancia da solo in modalita' STA (serve a WPF) e con
#       criteri di esecuzione Bypass solo per il proprio processo; gli errori non fanno piu' chiudere la finestra di
#       PowerShell di colpo (messaggio + attesa di Invio). Funziona anche con PowerShell 7 su Windows.
# (v1.3 2026-10-26 19:43: colori per progetto, righe allineate, account portabili)
# v1.3: (a) righe colorate per progetto (stessa cartella = stesso colore in entrambi i pannelli); le sessioni presenti
#       in tutti e due gli account stanno sulla stessa riga nei due pannelli (riga vuota grigia dove manca), i pannelli
#       scorrono insieme; ordine: per progetto, poi per ultima attivita'; clic sulle intestazioni disattivato.
#       (b) PORTABILE: nessun UUID nel codice. Gli account si rilevano da soli; le etichette (es. personale/lavoro)
#       stanno in sposta-config.json accanto allo script, scrivibile dal pulsante "Rinomina account...".
#       Update-Lato/Apply-Filtro della v1.2 commentati in fondo.
# (v1.2 2026-10-26 16:35: due pannelli affiancati)
# v1.2: finestra a due pannelli affiancati (un account per lato, come FileZilla) con le frecce al centro;
#       colonna "Anche nell'altro"; anteprima con la casella "Solo anteprima". Finestra v1.1 commentata in fondo.
# (v1.1 2026-10-26 16:25: finestra a pannello unico)
# v1.1: interfaccia grafica (WPF) quando si lancia senza parametri; la riga di comando resta invariata (-NoGui per
#       forzarla). Il corpo principale della v1.0 e' in fondo al file, commentato.
# (v1.0 2026-10-26 16:15: prima versione, solo riga di comando + Out-GridView)
#
# Sposta (o copia) le sessioni Claude Code dell'app desktop da un account all'altro.
#
# Come funziona (osservato sui file, formato non documentato da Anthropic):
#   - il transcript di una sessione (~\.claude\projects\<cartella>\<id>.jsonl) e' del PC, comune a tutti gli
#     account: questo tool NON lo tocca mai;
#   - l'app desktop tiene per ogni account un elenco di "schede" in
#     %LOCALAPPDATA%\Claude-Data\claude_*\claude-code-sessions\<accountUuid>\<orgUuid>\local_<id>.json:
#     e' la scheda che decide in quale account la sessione compare nell'app;
#   - SPOSTA = copia la scheda nell'account di destinazione e toglie quella di origine (messa in backup, mai cancellata);
#     COPIA  = la sessione compare in entrambi gli account (prova del 2026-10-26: funziona).
#   - Nella scheda copiata: adoptedFromOtherSurface = true; tolti enabledMcpTools e remoteMcpServersConfig
#     (connettori legati all'account di origine).
#   - Riprendendo la sessione con l'altro account l'app avvisa "Claude can't use thinking from another
#     organization": e' normale, la prima risposta rilegge la sessione e consuma piu' token.
#
# Sicurezza:
#   - l'app desktop deve essere chiusa (altrimenti puo' riscrivere le schede): il tool la chiude da solo
#     (prima in modo pulito, poi forzato dopo 15 s) e, con -Riavvia, la riapre alla fine;
#   - avvisa se ci sono sessioni Claude Code aperte da terminale (stesso transcript scritto da due parti);
#   - ogni operazione e' scritta in un registro CSV (delimitatore ';'); -Ripristina <registro> la annulla.
#
# Uso (PowerShell, utente corrente, senza admin):
#   .\Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1                       # FINESTRA: due pannelli (account per lato), frecce per spostare/copiare
#   (oppure tasto destro sul file -> Esegui con PowerShell)
#   .\Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1 -Da personale -A lavoro
#   .\Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1 -Da lavoro -A personale -Modalita Copia -Riavvia
#   .\Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1 -Da personale -A lavoro -Sessioni 0c7c0e04-bcde-4f39-acc0-bc4cf6eea68a
#   .\Sposta-SessioniClaude_v1.5_2026-10-26_2000.ps1 -Ripristina "<cartella tool>\registri\sposta_20261026_1620.csv"
#   -Prova  : mostra cosa farebbe senza modificare nulla
# =============================================================================
[CmdletBinding()]
param(
    [string]$Da = "",                                  # account di origine: etichetta (personale/lavoro) o UUID
    [string]$A = "",                                   # account di destinazione: etichetta o UUID
    [ValidateSet("Sposta", "Copia")][string]$Modalita = "Sposta",
    [string[]]$Sessioni = @(),                         # cliSessionId da trattare (vuoto = scelta in finestra)
    [switch]$Riavvia,                                  # riapre l'app desktop alla fine
    [switch]$Prova,                                    # nessuna modifica, solo elenco delle azioni
    [string]$Ripristina = "",                          # registro CSV di un'esecuzione da annullare
    [switch]$NoGui                                     # v1.1: riga di comando anche senza altri parametri
)

$ErrorActionPreference = 'Stop'

# --- v1.4: avvio da tasto destro "Esegui con PowerShell" ----------------------------------------------------
# 1) Errori: senza questo la finestra di PowerShell si chiude subito e non si legge nulla. Tutto il resto dello script
#    e' al livello principale: un errore bloccante arriva qui, lo mostra e aspetta Invio.
trap {
    Write-Host ""
    Write-Host "ERRORE: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Read-Host "Premere Invio per chiudere"
    exit 1
}
# 2) La finestra WPF richiede un thread STA (PowerShell 5.1 e' STA di default, PowerShell 7 no): se serve, lo script si
#    rilancia da solo con -STA e criteri Bypass limitati a quel processo (nessuna modifica permanente al PC).
if (-not ($Da -or $A -or $Sessioni.Count -or $Ripristina -or $NoGui) -and
    [Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $exe = (Get-Process -Id $PID).Path
    & $exe -STA -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}
# 2026-10-26 v1.0: $Version = "1.0"
# 2026-10-26 v1.1: $Version = "1.1"
# 2026-10-26 v1.2: $Version = "1.2"
# 2026-10-26 v1.3: $Version = "1.3"
# 2026-10-26 v1.4: $Version = "1.4"
$Version = "1.5"

# --- Configurazione (v1.3): UUID account -> etichetta, letta da sposta-config.json accanto allo script ---
# 2026-10-26 v1.2: etichette scritte nel codice ($Etichette = @{ '<uuid>' = 'personale'; '<uuid>' = 'lavoro' }); sostituite
#                  dal file di configurazione per poter passare lo script ad altre persone.
# Formato: { "etichette": { "<uuid account>": "personale", "<uuid account>": "lavoro" } }
# Senza file (o per un account non elencato) l'etichetta e' "account-<primi 8 caratteri dell'UUID>".
$ConfigFile = Join-Path $PSScriptRoot 'sposta-config.json'
$Etichette = @{}
if (Test-Path $ConfigFile) {
    try {
        $cfg = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $cfg.etichette.PSObject.Properties) { $Etichette[$p.Name.ToLower()] = [string]$p.Value }
    } catch { Write-Warning "sposta-config.json non leggibile, etichette ignorate: $($_.Exception.Message)" }
}
function Save-Etichette {
    $o = [ordered]@{ etichette = [ordered]@{} }
    foreach ($k in ($Etichette.Keys | Sort-Object)) { $o.etichette[$k] = $Etichette[$k] }
    ($o | ConvertTo-Json -Depth 4) | Set-Content $ConfigFile -Encoding UTF8
}
$Registri = Join-Path $PSScriptRoot 'registri'

# --- Cartella delle schede dell'app (MSIX: %LOCALAPPDATA%\Claude-Data\claude_*; installazione classica: %APPDATA%\Claude) ---
function Get-RadiceSchede {
    $c = @(Get-ChildItem "$env:LOCALAPPDATA\Claude-Data" -Directory -Filter 'claude_*' -ErrorAction SilentlyContinue |
           ForEach-Object { Join-Path $_.FullName 'claude-code-sessions' } | Where-Object { Test-Path $_ })
    $c += @("$env:APPDATA\Claude\claude-code-sessions" | Where-Object { Test-Path $_ })
    if ($c.Count -eq 0) { throw "Cartella claude-code-sessions dell'app desktop non trovata." }
    return $c[0]
}

function Get-NomeAccount([string]$uuid) {
    if ($Etichette.ContainsKey($uuid.ToLower())) { return $Etichette[$uuid.ToLower()] }
    return "account-$($uuid.Substring(0,8))"
}

# Etichetta o UUID -> cartella dell'account
function Resolve-Account([string]$radice, [string]$nome) {
    $acc = @(Get-ChildItem $radice -Directory | Where-Object { $_.Name -match '^[0-9a-f-]{36}$' })
    $n = $nome.ToLower()
    $hit = @($acc | Where-Object { $_.Name -eq $n -or (Get-NomeAccount $_.Name) -eq $nome -or ($n.Length -ge 4 -and $_.Name.StartsWith($n)) })
    if ($hit.Count -ne 1) { throw "Account '$nome' non trovato (presenti: $(($acc | ForEach-Object { "$(Get-NomeAccount $_.Name)=$($_.Name)" }) -join ' | '))" }
    return $hit[0]
}

# Organizzazione di destinazione: la cartella <orgUuid> dell'account che contiene gia' schede (la piu' piena)
function Get-OrgDestinazione($accDir) {
    $org = @(Get-ChildItem $accDir.FullName -Directory | Where-Object { $_.Name -match '^[0-9a-f-]{36}$' } |
             Sort-Object { @(Get-ChildItem $_.FullName -Filter 'local_*.json' -File).Count } -Descending)
    if ($org.Count -eq 0) { throw "L'account $($accDir.Name) non ha ancora una cartella organizzazione: aprire una volta l'app con quell'account." }
    return $org[0]
}

function Get-Schede($accDir) {
    foreach ($f in @(Get-ChildItem $accDir.FullName -Recurse -Filter 'local_*.json' -File)) {
        try { $j = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
        $ult = $null
        if ($j.lastActivityAt) { $ult = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$j.lastActivityAt).LocalDateTime }
        [pscustomobject]@{
            Titolo        = $j.title
            UltimaAttivita = $ult
            Cartella      = $j.cwd
            Archiviata    = [bool]$j.isArchived
            Id            = $j.cliSessionId
            File          = $f.FullName
        }
    }
}

# --- Chiusura / riapertura dell'app desktop -----------------------------------------------------------------
# Processo dell'app: "Claude" con eseguibile nel pacchetto MSIX (WindowsApps) o in AnthropicClaude (installazione classica).
function Get-ProcessiApp {
    @(Get-Process -Name 'Claude' -ErrorAction SilentlyContinue | Where-Object {
        $p = $null; try { $p = $_.Path } catch {}
        (-not $p) -or $p -match '\\WindowsApps\\|\\AnthropicClaude\\|\\Programs\\Claude\\'
    })
}
# Sessioni da terminale: claude.exe fuori dalla cartella dell'app, o node con claude-code nella riga di comando
function Get-ProcessiCli {
    @(Get-CimInstance Win32_Process -Filter "Name='claude.exe' OR Name='node.exe'" -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -eq 'claude.exe' -and $_.ExecutablePath -notmatch '\\WindowsApps\\|\\AnthropicClaude\\|Claude-Data|\\Programs\\Claude\\') -or
        ($_.Name -eq 'node.exe' -and $_.CommandLine -match 'claude-code')
    })
}
# v1.1: Write-Host -> Write-Log (messaggi anche nella finestra)
function Close-App {
    $pr = Get-ProcessiApp
    if ($pr.Count -eq 0) { Write-Log "App desktop gia' chiusa."; return $false }
    Write-Log "Chiudo l'app desktop ($($pr.Count) processi)..."
    foreach ($p in $pr) { if ($p.MainWindowHandle -ne 0) { [void]$p.CloseMainWindow() } }
    $t = 0
    while ((Get-ProcessiApp).Count -gt 0 -and $t -lt 15) { Start-Sleep -Seconds 1; $t++ }
    $rest = Get-ProcessiApp
    if ($rest.Count -gt 0) { Write-Log "Chiusura forzata di $($rest.Count) processi."; $rest | Stop-Process -Force; Start-Sleep -Seconds 2 }
    if ((Get-ProcessiApp).Count -gt 0) { throw "Impossibile chiudere l'app desktop." }
    return $true
}
function Start-App {
    $app = Get-StartApps | Where-Object { $_.Name -eq 'Claude' } | Select-Object -First 1
    if ($app) { Start-Process "shell:AppsFolder\$($app.AppID)"; Write-Log "App desktop riaperta." }
    else { Write-Log "App desktop non trovata nel menu Start: riaprirla a mano." }
}

# --- Scrittura della scheda nell'account di destinazione ----------------------------------------------------
function Write-Scheda([string]$sorgente, [string]$dest) {
    $j = Get-Content $sorgente -Raw -Encoding UTF8 | ConvertFrom-Json
    $j | Add-Member -NotePropertyName 'adoptedFromOtherSurface' -NotePropertyValue $true -Force
    foreach ($k in 'enabledMcpTools', 'remoteMcpServersConfig') { if ($j.PSObject.Properties[$k]) { $j.PSObject.Properties.Remove($k) } }
    $txt = $j | ConvertTo-Json -Depth 100 -Compress
    [void]($txt | ConvertFrom-Json)                                              # controllo: JSON valido
    [IO.File]::WriteAllText($dest, $txt, (New-Object Text.UTF8Encoding $false))  # UTF-8 senza BOM, come l'app
}

# =============================================================================================================
# Operazioni comuni a interfaccia grafica e riga di comando (v1.1: estratte dal corpo principale della v1.0)
# =============================================================================================================
$script:LogBox = $null
# Messaggi: nella casella della finestra se c'e', altrimenti in console
function Write-Log([string]$m) {
    if ($script:LogBox) {
        $script:LogBox.AppendText("$(Get-Date -Format 'HH:mm:ss')  $m`r`n"); $script:LogBox.ScrollToEnd()
        # aggiorna subito la finestra (le operazioni lunghe, es. chiusura dell'app, altrimenti la bloccano senza messaggi)
        [void]$script:LogBox.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)
    } else { Write-Host $m }
}

# Annulla un'esecuzione dal suo registro CSV
function Invoke-Ripristino([string]$registro, [bool]$prova, [bool]$riavvia) {
    $righe = @(Import-Csv $registro -Delimiter ';')
    $chiusa = $false
    if (-not $prova) { $chiusa = Close-App }
    foreach ($r in $righe) {
        if ($prova) { Write-Log "[prova] annullerei: $($r.Azione) $($r.Titolo)"; continue }
        if ($r.Destinazione -and (Test-Path $r.Destinazione)) { Remove-Item $r.Destinazione -Force }   # scheda creata dal tool
        if ($r.Azione -eq 'Sposta' -and $r.Backup -and (Test-Path $r.Backup) -and -not (Test-Path $r.Origine)) {
            Move-Item $r.Backup $r.Origine                                                             # rimette la scheda originale
        }
        Write-Log "Annullato: $($r.Titolo)"
    }
    if (($riavvia -or $chiusa) -and -not $prova) { Start-App }
}

# Sposta/copia le schede scelte (l'app deve gia' essere chiusa); restituisce il percorso del registro
function Invoke-Operazione($accDa, $accA, $scelte, [string]$modalita, [bool]$prova) {
    $orgA = Get-OrgDestinazione $accA
    Write-Log "$modalita da $(Get-NomeAccount $accDa.Name) a $(Get-NomeAccount $accA.Name) (organizzazione $($orgA.Name)), $(@($scelte).Count) sessioni"
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $log = @()
    foreach ($s in $scelte) {
        $nome = [IO.Path]::GetFileName($s.File)
        $dest = Join-Path $orgA.FullName $nome
        $esiste = @(Get-ChildItem $accA.FullName -Recurse -Filter $nome).Count -gt 0
        $bk = Join-Path $backup ("$stamp\" + $s.File.Substring($radice.Length).TrimStart('\'))
        if ($prova) { Write-Log "[prova] $modalita '$($s.Titolo)'$(if ($esiste) { ' (gia'' presente nella destinazione)' })"; continue }
        $creata = ""
        if (-not $esiste) { Write-Scheda $s.File $dest; $creata = $dest }
        $bkFatto = ""
        if ($modalita -eq 'Sposta') {
            New-Item -ItemType Directory -Force (Split-Path $bk -Parent) | Out-Null
            Move-Item $s.File $bk                                                      # mai cancellata: va in backup
            $bkFatto = $bk
        }
        $log += [pscustomobject]@{ Data = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); Azione = $modalita; Titolo = $s.Titolo; Id = $s.Id
                                   Da = (Get-NomeAccount $accDa.Name); A = (Get-NomeAccount $accA.Name)
                                   Origine = $s.File; Destinazione = $creata; Backup = $bkFatto }
        Write-Log "$modalita fatto: $($s.Titolo)$(if ($esiste) { ' (scheda gia'' presente nella destinazione, non riscritta)' })"
    }
    if ($log.Count) {
        New-Item -ItemType Directory -Force $Registri | Out-Null
        $f = Join-Path $Registri "sposta_$stamp.csv"
        $log | Export-Csv $f -Delimiter ';' -NoTypeInformation -Encoding UTF8
        Write-Log "Registro: $f"
        return $f
    }
    return $null
}

# =============================================================================================================
$radice = Get-RadiceSchede
$backup = Join-Path (Split-Path $radice -Parent) 'claude-code-sessions-backup'
$accounts = @(Get-ChildItem $radice -Directory | Where-Object { $_.Name -match '^[0-9a-f-]{36}$' })

# Riga di comando: si usa se e' indicato almeno un parametro operativo; altrimenti si apre la finestra
$daRigaDiComando = [bool]($Ripristina -or $Da -or $A -or $Sessioni.Count -or $NoGui)

# --- RIGA DI COMANDO ----------------------------------------------------------------------------------------
if ($daRigaDiComando) {
    Write-Log "Sposta-SessioniClaude v$Version  |  schede: $radice"
    if ($Ripristina) { Invoke-Ripristino $Ripristina ([bool]$Prova) ([bool]$Riavvia); return }
    if ($accounts.Count -lt 2) { throw "Sul PC c'e' un solo account nell'app desktop: niente da spostare." }
    if (-not $Da -or -not $A) { throw "Da riga di comando servono -Da e -A (oppure lanciare senza parametri per la finestra)." }
    $accDa = Resolve-Account $radice $Da
    $accA  = Resolve-Account $radice $A
    if ($accDa.Name -eq $accA.Name) { throw "Origine e destinazione coincidono." }
    $schede = @(Get-Schede $accDa | Sort-Object UltimaAttivita -Descending)
    if ($Sessioni.Count) { $scelte = @($schede | Where-Object { $Sessioni -contains $_.Id }) }
    else { $scelte = @($schede | Out-GridView -Title "Sessioni da $($Modalita.ToLower()) (Ctrl/Maiusc per sceglierne piu' di una)" -PassThru) }
    if ($scelte.Count -eq 0) { Write-Log "Nessuna sessione scelta."; return }
    $chiusa = $false
    if (-not $Prova) {
        $ok = Read-Host "$Modalita $($scelte.Count) sessioni: l'app desktop verra' chiusa. Procedere? [S/N]"
        if ($ok -notmatch '^[sS]') { Write-Log "Annullato."; return }
        $chiusa = Close-App
        $cli = Get-ProcessiCli
        if ($cli.Count -gt 0) {
            Write-Warning "Ci sono $($cli.Count) processi Claude Code da terminale aperti: se uno lavora su una sessione scelta, va chiuso prima di riprenderla con l'altro account."
            $ok = Read-Host "Continuare comunque? [S/N]"
            if ($ok -notmatch '^[sS]') { Write-Log "Annullato (app non riaperta)."; return }
        }
    }
    $f = Invoke-Operazione $accDa $accA $scelte $Modalita ([bool]$Prova)
    if ($f) { Write-Log "Annullare con: -Ripristina `"$f`"" }
    if (($Riavvia -or $chiusa) -and -not $Prova) { Start-App }
    return
}

# --- INTERFACCIA GRAFICA (v1.2: due pannelli affiancati, come il trasferimento file di FileZilla) --------------
# Sinistra e destra = due account; le frecce al centro spostano (o copiano) le sessioni selezionate da un lato all'altro.
# Costruita al livello principale dello script (non dentro una funzione): i gestori degli eventi leggono le
# variabili dello script senza .GetNewClosure(); lo stato dei pannelli sta nella tabella $Lati (oggetto condiviso).
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Pannello di un lato (stesso XAML per sinistra e destra, nomi con suffisso L / R)
function Get-XamlPannello([string]$k, [string]$titolo) {
@"
    <DockPanel Grid.Column="$(if ($k -eq 'L') { 0 } else { 2 })" Margin="0">
      <TextBlock DockPanel.Dock="Top" Text="$titolo" FontWeight="Bold" Margin="0,0,0,4"/>
      <ComboBox x:Name="cb$k" DockPanel.Dock="Top" Margin="0,0,0,6"/>
      <DockPanel DockPanel.Dock="Top" Margin="0,0,0,6">
        <TextBlock Text="Cerca" VerticalAlignment="Center" Margin="0,0,6,0"/>
        <TextBox x:Name="tb$k" ToolTip="Filtra per titolo o cartella"/>
      </DockPanel>
      <TextBlock x:Name="tx$k" DockPanel.Dock="Bottom" Margin="0,4,0,0" Foreground="#555"/>
      <DataGrid x:Name="dg$k" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended"
                CanUserAddRows="False" HeadersVisibility="Column" GridLinesVisibility="Horizontal"
                CanUserSortColumns="False" RowHeight="22">
        <!-- 2026-10-26 v1.4: RowStyle con Background="{Binding Colore}" e DataTrigger su Vuota: il colore non compariva.
             Dalla v1.5 colore e righe vuote sono impostati in codice (Set-StileRiga, evento LoadingRow). -->
        <DataGrid.Columns>
          <DataGridTextColumn Header="Titolo" Binding="{Binding Titolo}" Width="2*"/>
          <DataGridTextColumn Header="Ultima attivita'" Binding="{Binding UltimaTesto}" Width="115"/>
          <DataGridTextColumn Header="Anche nell'altro" Binding="{Binding Altro}" Width="60"/>
          <DataGridTextColumn Header="Cartella" Binding="{Binding Cartella}" Width="2*"/>
        </DataGrid.Columns>
      </DataGrid>
    </DockPanel>
"@
}
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Sposta sessioni Claude v$Version" Width="1300" Height="760" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="13">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="130"/>
    </Grid.RowDefinitions>
    <Grid Grid.Row="0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/><ColumnDefinition Width="150"/><ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
$(Get-XamlPannello 'L' 'Account di sinistra')
      <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,0">
        <Button x:Name="btDestra" Content="&#x2192;" FontSize="26" Height="48" Margin="0,0,0,10"
                ToolTip="Sessioni selezionate a sinistra -&gt; account di destra"/>
        <Button x:Name="btSinistra" Content="&#x2190;" FontSize="26" Height="48" Margin="0,0,0,18"
                ToolTip="Sessioni selezionate a destra -&gt; account di sinistra"/>
        <RadioButton x:Name="rbSposta" Content="Sposta" IsChecked="True" Margin="0,0,0,4"
                     ToolTip="La sessione passa nell'altro account e sparisce da questo (scheda in backup)"/>
        <RadioButton x:Name="rbCopia" Content="Copia (in entrambi)" Margin="0,0,0,12"
                     ToolTip="La sessione compare in tutti e due gli account"/>
        <CheckBox x:Name="chProva" Content="Solo anteprima" Margin="0,0,0,4"
                  ToolTip="Le frecce scrivono nel registro cosa farebbero, senza modificare nulla e senza chiudere l'app"/>
        <CheckBox x:Name="chRiapri" Content="Riapri l'app alla fine" IsChecked="True" Margin="0,0,0,4"/>
        <CheckBox x:Name="chArchiviate" Content="Mostra archiviate" Margin="0,0,0,12"/>
        <Button x:Name="btAggiorna" Content="Aggiorna" Padding="6,3" Margin="0,0,0,6"/>
        <Button x:Name="btRinomina" Content="Rinomina account..." Padding="6,3" Margin="0,0,0,6" ToolTip="Da' un nome ai due account mostrati (salvato in sposta-config.json)"/>
        <Button x:Name="btRipristina" Content="Ripristina..." Padding="6,3" ToolTip="Annulla un'esecuzione scegliendo il suo registro"/>
      </StackPanel>
$(Get-XamlPannello 'R' 'Account di destra')
    </Grid>
    <TextBlock x:Name="txStato" Grid.Row="1" Margin="0,8,0,6" Foreground="#555"/>
    <TextBox x:Name="tbLog" Grid.Row="2" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
             FontFamily="Consolas" FontSize="12"/>
  </Grid>
</Window>
"@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$ui = @{}
foreach ($n in 'cbL','tbL','txL','dgL','cbR','tbR','txR','dgR','btDestra','btSinistra','rbSposta','rbCopia','chProva','chRiapri','chArchiviate','btAggiorna','btRinomina','btRipristina','txStato','tbLog') {
    $ui[$n] = $win.FindName($n)
}
$script:LogBox = $ui.tbLog
$Lati = @{ L = @{ cb = $ui.cbL; tb = $ui.tbL; dg = $ui.dgL; tx = $ui.txL; Tutte = @() }
           R = @{ cb = $ui.cbR; tb = $ui.tbR; dg = $ui.dgR; tx = $ui.txR; Tutte = @() } }

function Get-AccLato([string]$k) { $it = $Lati[$k].cb.SelectedItem; if ($it) { $it.Tag } else { $null } }
function Get-Opposto([string]$k) { if ($k -eq 'L') { 'R' } else { 'L' } }

# Tendine: "etichetta (n sessioni)"; Tag = cartella dell'account. Mantiene la scelta corrente.
function Fill-Account {
    foreach ($k in 'L', 'R') {
        $cb = $Lati[$k].cb; $prima = Get-AccLato $k
        $cb.Items.Clear()
        foreach ($a in $accounts) {
            $it = New-Object Windows.Controls.ComboBoxItem
            $it.Content = "$(Get-NomeAccount $a.Name)  ($(@(Get-ChildItem $a.FullName -Recurse -Filter 'local_*.json').Count) sessioni)"
            $it.Tag = $a
            [void]$cb.Items.Add($it)
            if ($prima -and $prima.Name -eq $a.Name) { $cb.SelectedItem = $it }
        }
    }
}

function Update-Stato {
    $app = (Get-ProcessiApp).Count; $cli = (Get-ProcessiCli).Count
    $ui.txStato.Text = "App desktop: $(if ($app) { 'APERTA (verra'' chiusa alla prima freccia)' } else { 'chiusa' })   |   processi Claude da terminale: $cli   |   schede: $radice"
}

# v1.3: schede di entrambi i lati allineate. Colore = progetto (cartella), uguale nei due pannelli; una sessione presente
# in tutti e due gli account occupa la stessa riga (sull'altro lato resta una riga vuota grigia se assente).
$Palette = @('#DCEBFA','#E3F4D7','#FBE5CF','#EBDDF5','#FFF4C2','#D5F1EF','#F8D9E1','#E4E8C8','#D9DEF7','#F2DFD0','#CFEBDD','#EFD5EC')
function New-RigaVuota([string]$id) {
    [pscustomobject]@{ Titolo = ''; UltimaTesto = ''; Altro = ''; Cartella = ''; Vuota = $true; Colore = '#EEEEEE'; Id = $id; Archiviata = $false }
}
function Update-Allineato {
    $dati = @{ L = @{}; R = @{} }
    foreach ($k in 'L', 'R') {
        $acc = Get-AccLato $k
        if ($acc) { foreach ($x in @(Get-Schede $acc)) { $dati[$k][$x.Id] = $x } }
    }
    $aL = Get-AccLato 'L'; $aR = Get-AccLato 'R'
    $stessi = ($aL -and $aR -and $aL.Name -eq $aR.Name)
    # un colore per cartella, assegnato in ordine alfabetico sull'unione delle due liste (stesso colore nei due pannelli)
    $cart = @(@($dati.L.Values) + @($dati.R.Values) | ForEach-Object { [string]$_.Cartella } | Where-Object { $_ } | Sort-Object -Unique)
    $mappa = @{}; for ($n = 0; $n -lt $cart.Count; $n++) { $mappa[$cart[$n]] = $Palette[$n % $Palette.Count] }
    # unione delle sessioni, ordinate per progetto (il piu' recente per primo) e poi per ultima attivita' decrescente
    $tutte = @{}
    foreach ($k in 'L', 'R') { foreach ($id in $dati[$k].Keys) {
        $x = $dati[$k][$id]
        if (-not $tutte.ContainsKey($id)) { $tutte[$id] = @{ Cartella = [string]$x.Cartella; Ult = $x.UltimaAttivita } }
        elseif ($x.UltimaAttivita -and (-not $tutte[$id].Ult -or $x.UltimaAttivita -gt $tutte[$id].Ult)) { $tutte[$id].Ult = $x.UltimaAttivita }
    } }
    $ultProg = @{}
    foreach ($id in $tutte.Keys) {
        $c = $tutte[$id].Cartella; $u = $tutte[$id].Ult
        if (-not $ultProg.ContainsKey($c) -or ($u -and (-not $ultProg[$c] -or $u -gt $ultProg[$c]))) { $ultProg[$c] = $u }
    }
    $ordine = @($tutte.Keys | Sort-Object `
        @{ Expression = { $ultProg[$tutte[$_].Cartella] }; Descending = $true }, `
        @{ Expression = { $tutte[$_].Cartella } }, `
        @{ Expression = { $tutte[$_].Ult }; Descending = $true })
    foreach ($k in 'L', 'R') {
        $o = if ($k -eq 'L') { 'R' } else { 'L' }
        $righe = @(); $reali = @()
        foreach ($id in $ordine) {
            $x = $dati[$k][$id]
            if (-not $x) { $righe += New-RigaVuota $id; continue }
            $ult = if ($x.UltimaAttivita) { $x.UltimaAttivita.ToString('dd/MM/yyyy HH:mm') } else { '' }
            $altro = if ($dati[$o].ContainsKey($id) -and -not $stessi) { 'si' } else { '' }
            $col = if ($x.Cartella) { $mappa[[string]$x.Cartella] } else { '#FFFFFF' }
            $r = $x | Select-Object *, @{ n = 'UltimaTesto'; e = { $ult } }, @{ n = 'Altro'; e = { $altro } },
                 @{ n = 'Vuota'; e = { $false } }, @{ n = 'Colore'; e = { $col } }
            $reali += $r; $righe += $r
        }
        $Lati[$k].Tutte = $reali
        $Lati[$k].Righe = $righe
    }
    Apply-Filtro 'L'; Apply-Filtro 'R'
}
# Filtro (ricerca + archiviate): una riga sparisce da entrambi i lati solo se non passa il filtro in nessuno dei due
function Test-Passa($r, [string]$q) {
    ($ui.chArchiviate.IsChecked -or -not $r.Archiviata) -and (-not $q -or "$($r.Titolo) $($r.Cartella)" -like "*$q*")
}
function Apply-Filtro([string]$k) {
    $o = if ($k -eq 'L') { 'R' } else { 'L' }
    $q = $Lati[$k].tb.Text.Trim(); $qo = $Lati[$o].tb.Text.Trim()
    $altri = @{}; foreach ($r in $Lati[$o].Tutte) { $altri[$r.Id] = $r }
    $v = @(); $n = 0
    foreach ($r in $Lati[$k].Righe) {
        $okAltro = $altri.ContainsKey($r.Id) -and (Test-Passa $altri[$r.Id] $qo)
        if ($r.Vuota) {
            if ($okAltro) { $v += $r }                                   # l'altro lato la mostra: riga vuota per l'allineamento
        } elseif (Test-Passa $r $q) { $v += $r; $n++ }
        elseif ($okAltro) { $v += New-RigaVuota $r.Id }
    }
    $Lati[$k].dg.ItemsSource = $v
    $Lati[$k].Mostrate = $n
    Update-Conteggio $k
}
# v1.5: colore di sfondo e riga vuota non cliccabile, impostati sulla riga quando la griglia la crea o la riusa
function Set-StileRiga($riga) {
    $it = $riga.Item
    if ($it -isnot [psobject] -or -not ($it.PSObject.Properties['Colore'])) { return }
    try {
        $c = [Windows.Media.ColorConverter]::ConvertFromString([string]$it.Colore)
        $b = New-Object Windows.Media.SolidColorBrush $c
        $b.Freeze()
        $riga.Background = $b
    } catch { $riga.Background = [Windows.Media.Brushes]::White }
    $riga.IsHitTestVisible = -not [bool]$it.Vuota
}
function Update-Conteggio([string]$k) {
    $sel = @($Lati[$k].dg.SelectedItems | Where-Object { -not $_.Vuota }).Count
    $Lati[$k].tx.Text = "$($Lati[$k].Mostrate) sessioni mostrate su $(@($Lati[$k].Tutte).Count), $sel selezionate"
}

function Update-Tutto { Update-Allineato; Update-Stato }
# Freccia: dal lato $k verso il lato opposto
function Invoke-Freccia([string]$k) {
    $da = Get-AccLato $k; $a = Get-AccLato (Get-Opposto $k)
    if (-not $da -or -not $a) { [void][Windows.MessageBox]::Show("Scegliere un account per ogni lato.", "Sposta sessioni"); return }
    if ($da.Name -eq $a.Name) { [void][Windows.MessageBox]::Show("I due lati mostrano lo stesso account.", "Sposta sessioni"); return }
    $sel = @($Lati[$k].dg.SelectedItems | Where-Object { -not $_.Vuota })
    if ($sel.Count -eq 0) { [void][Windows.MessageBox]::Show("Selezionare almeno una sessione nel pannello di $(if ($k -eq 'L') { 'sinistra' } else { 'destra' }).", "Sposta sessioni"); return }
    $mod = if ($ui.rbCopia.IsChecked) { 'Copia' } else { 'Sposta' }
    if ($ui.chProva.IsChecked) {
        try { [void](Invoke-Operazione $da $a $sel $mod $true) } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
        Write-Log "(anteprima: nessuna modifica; togliere 'Solo anteprima' per eseguire)"
        return
    }
    $msg = "$mod $($sel.Count) sessioni da $(Get-NomeAccount $da.Name) a $(Get-NomeAccount $a.Name).`n`n" +
           "L'app desktop di Claude verra' chiusa (le sessioni in corso nell'app si fermano).`nProcedere?"
    if ([Windows.MessageBox]::Show($msg, "Sposta sessioni", 'YesNo', 'Question') -ne 'Yes') { return }
    try {
        [void](Close-App)
        $cli = (Get-ProcessiCli).Count
        if ($cli -gt 0) {
            $m2 = "Ci sono $cli processi Claude Code da terminale aperti.`nSe uno lavora su una sessione scelta, va chiuso prima di riprenderla con l'altro account.`n`nContinuare?"
            if ([Windows.MessageBox]::Show($m2, "Sposta sessioni", 'YesNo', 'Warning') -ne 'Yes') { Write-Log "Annullato (app non riaperta)."; Update-Stato; return }
        }
        $f = Invoke-Operazione $da $a $sel $mod $false
        if ($f) { Write-Log "Per annullare: 'Ripristina...' e scegliere $([IO.Path]::GetFileName($f))" }
        if ($ui.chRiapri.IsChecked) { Start-App }
    } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
    Fill-Account; Update-Tutto
}

$ui.cbL.Add_SelectionChanged({ Update-Allineato })
$ui.cbR.Add_SelectionChanged({ Update-Allineato })
$ui.tbL.Add_TextChanged({ Apply-Filtro 'L'; Apply-Filtro 'R' })
$ui.tbR.Add_TextChanged({ Apply-Filtro 'R'; Apply-Filtro 'L' })
$ui.dgL.Add_LoadingRow({ Set-StileRiga $args[1].Row })
$ui.dgR.Add_LoadingRow({ Set-StileRiga $args[1].Row })
$ui.dgL.Add_SelectionChanged({ Update-Conteggio 'L' })
$ui.dgR.Add_SelectionChanged({ Update-Conteggio 'R' })
$ui.chArchiviate.Add_Click({ Apply-Filtro 'L'; Apply-Filtro 'R' })
$ui.btDestra.Add_Click({ Invoke-Freccia 'L' })
$ui.btSinistra.Add_Click({ Invoke-Freccia 'R' })
$ui.btAggiorna.Add_Click({ Fill-Account; Update-Tutto })
# v1.3: dare un nome agli account mostrati (salvato in sposta-config.json, vale anche per la riga di comando)
$ui.btRinomina.Add_Click({
    Add-Type -AssemblyName Microsoft.VisualBasic
    foreach ($k in 'L', 'R') {
        $acc = Get-AccLato $k
        if (-not $acc) { continue }
        $lato = if ($k -eq 'L') { 'sinistra' } else { 'destra' }
        $nuovo = [Microsoft.VisualBasic.Interaction]::InputBox("Nome per l'account di $lato ($($acc.Name)).`\nLasciare vuoto per non cambiare.", "Rinomina account", (Get-NomeAccount $acc.Name))
        if ($nuovo.Trim()) { $Etichette[$acc.Name.ToLower()] = $nuovo.Trim() }
    }
    try { Save-Etichette; Write-Log "Nomi salvati in $ConfigFile" } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
    Fill-Account; Update-Tutto
})
$ui.btRipristina.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = $(if (Test-Path $Registri) { $Registri } else { $PSScriptRoot })
    $dlg.Filter = "Registri (sposta_*.csv)|sposta_*.csv"
    if ($dlg.ShowDialog() -ne 'OK') { return }
    if ([Windows.MessageBox]::Show("Annullare le operazioni di $([IO.Path]::GetFileName($dlg.FileName))?`nL'app desktop verra' chiusa.", "Sposta sessioni", 'YesNo', 'Question') -ne 'Yes') { return }
    try { Invoke-Ripristino $dlg.FileName $false ([bool]$ui.chRiapri.IsChecked) } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
    Fill-Account; Update-Tutto
})

# Avvio: personale a sinistra e lavoro a destra se presenti, altrimenti i primi due account
Fill-Account
$nomi = @($accounts | ForEach-Object { Get-NomeAccount $_.Name })
$iL = [array]::IndexOf($nomi, 'personale'); if ($iL -lt 0) { $iL = 0 }
$iR = [array]::IndexOf($nomi, 'lavoro');    if ($iR -lt 0) { $iR = [Math]::Min(1, $accounts.Count - 1) }
$ui.cbL.SelectedIndex = $iL; $ui.cbR.SelectedIndex = $iR
Update-Tutto
Write-Log "Sposta-SessioniClaude v$Version  |  $($accounts.Count) account. Selezionare le sessioni in un pannello e premere la freccia verso l'altro."
if ($accounts.Count -lt 2) { Write-Log "Sul PC c'e' un solo account nell'app desktop: niente da spostare." }
# v1.3: i due pannelli scorrono insieme (hanno sempre lo stesso numero di righe)
function Find-ScrollViewer($o) {
    if ($o -is [Windows.Controls.ScrollViewer]) { return $o }
    for ($n = 0; $n -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($o); $n++) {
        $r = Find-ScrollViewer ([Windows.Media.VisualTreeHelper]::GetChild($o, $n))
        if ($r) { return $r }
    }
    return $null
}
$win.Add_ContentRendered({
    $Lati.L.sv = Find-ScrollViewer $ui.dgL
    $Lati.R.sv = Find-ScrollViewer $ui.dgR
    if ($Lati.L.sv -and $Lati.R.sv) {
        $Lati.L.sv.Add_ScrollChanged({ if ($Lati.R.sv.VerticalOffset -ne $Lati.L.sv.VerticalOffset) { $Lati.R.sv.ScrollToVerticalOffset($Lati.L.sv.VerticalOffset) } })
        $Lati.R.sv.Add_ScrollChanged({ if ($Lati.L.sv.VerticalOffset -ne $Lati.R.sv.VerticalOffset) { $Lati.L.sv.ScrollToVerticalOffset($Lati.R.sv.VerticalOffset) } })
    }
})
[void]$win.ShowDialog()

# =============================================================================================================
# 2026-10-26 v1.1 - finestra a pannello unico, sostituita dalla v1.2:
<#
# --- INTERFACCIA GRAFICA (v1.1) -----------------------------------------------------------------------------
# Costruita al livello principale dello script (non dentro una funzione): i gestori degli eventi leggono e
# scrivono le variabili $script: senza .GetNewClosure().
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Sposta sessioni Claude v$Version" Width="1100" Height="720" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="13">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/><RowDefinition Height="140"/>
    </Grid.RowDefinitions>
    <WrapPanel Grid.Row="0" Margin="0,0,0,8">
      <TextBlock Text="Da" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <ComboBox x:Name="cbDa" Width="230" Margin="0,0,16,0"/>
      <TextBlock Text="A" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <ComboBox x:Name="cbA" Width="230" Margin="0,0,16,0"/>
      <RadioButton x:Name="rbSposta" Content="Sposta" IsChecked="True" VerticalAlignment="Center" Margin="0,0,10,0"
                   ToolTip="La sessione passa nell'account di destinazione e sparisce da quello di origine (scheda in backup)"/>
      <RadioButton x:Name="rbCopia" Content="Copia (in entrambi)" VerticalAlignment="Center" Margin="0,0,16,0"
                   ToolTip="La sessione compare in tutti e due gli account"/>
      <CheckBox x:Name="chRiapri" Content="Riapri l'app alla fine" IsChecked="True" VerticalAlignment="Center"/>
    </WrapPanel>
    <WrapPanel Grid.Row="1" Margin="0,0,0,8">
      <TextBlock Text="Cerca" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBox x:Name="tbCerca" Width="320" Margin="0,0,16,0" ToolTip="Filtra per titolo o cartella"/>
      <CheckBox x:Name="chArchiviate" Content="Mostra archiviate" VerticalAlignment="Center" Margin="0,0,16,0"/>
      <Button x:Name="btTutte" Content="Seleziona tutte" Padding="10,2" Margin="0,0,8,0"/>
      <Button x:Name="btAggiorna" Content="Aggiorna" Padding="10,2" Margin="0,0,16,0"/>
      <TextBlock x:Name="txStato" VerticalAlignment="Center" Foreground="#555"/>
    </WrapPanel>
    <DataGrid x:Name="dg" Grid.Row="2" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended"
              CanUserAddRows="False" HeadersVisibility="Column" GridLinesVisibility="Horizontal">
      <DataGrid.Columns>
        <DataGridTextColumn Header="Titolo" Binding="{Binding Titolo}" Width="3*"/>
        <DataGridTextColumn Header="Ultima attivita'" Binding="{Binding UltimaTesto}" Width="140" SortMemberPath="UltimaAttivita"/>
        <DataGridTextColumn Header="Cartella" Binding="{Binding Cartella}" Width="3*"/>
        <DataGridTextColumn Header="Arch." Binding="{Binding ArchTesto}" Width="50"/>
        <DataGridTextColumn Header="Id" Binding="{Binding Id}" Width="120"/>
      </DataGrid.Columns>
    </DataGrid>
    <DockPanel Grid.Row="3" Margin="0,8,0,8" LastChildFill="False">
      <TextBlock x:Name="txSel" DockPanel.Dock="Left" VerticalAlignment="Center"/>
      <Button x:Name="btEsegui" Content="Esegui" DockPanel.Dock="Right" Padding="18,4" Margin="8,0,0,0" FontWeight="Bold"/>
      <Button x:Name="btProva" Content="Anteprima" DockPanel.Dock="Right" Padding="14,4" Margin="8,0,0,0"
              ToolTip="Mostra cosa farebbe, senza modificare nulla e senza chiudere l'app"/>
      <Button x:Name="btRipristina" Content="Ripristina da registro..." DockPanel.Dock="Right" Padding="14,4"/>
    </DockPanel>
    <TextBox x:Name="tbLog" Grid.Row="4" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
             FontFamily="Consolas" FontSize="12"/>
  </Grid>
</Window>
"@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$ui = @{}
foreach ($n in 'cbDa','cbA','rbSposta','rbCopia','chRiapri','tbCerca','chArchiviate','btTutte','btAggiorna','txStato','dg','txSel','btEsegui','btProva','btRipristina','tbLog') {
    $ui[$n] = $win.FindName($n)
}
$script:LogBox = $ui.tbLog
$script:Tutte = @()

# Voci delle due tendine: "etichetta (n sessioni)"; Tag = cartella dell'account
function Fill-Account {
    foreach ($cb in $ui.cbDa, $ui.cbA) {
        $cb.Items.Clear()
        foreach ($a in $accounts) {
            $it = New-Object Windows.Controls.ComboBoxItem
            $it.Content = "$(Get-NomeAccount $a.Name)  ($(@(Get-ChildItem $a.FullName -Recurse -Filter 'local_*.json').Count) sessioni)"
            $it.Tag = $a
            [void]$cb.Items.Add($it)
        }
    }
}
function Get-AccScelto($cb) { if ($cb.SelectedItem) { $cb.SelectedItem.Tag } else { $null } }

# Stato dell'app e dei terminali, mostrato accanto ai pulsanti
function Update-Stato {
    $app = (Get-ProcessiApp).Count; $cli = (Get-ProcessiCli).Count
    $ui.txStato.Text = "App desktop: $(if ($app) { 'APERTA (verra'' chiusa)' } else { 'chiusa' })   |   processi Claude da terminale: $cli"
}

# Elenco delle sessioni dell'account di origine, con filtro di ricerca e archiviate
function Update-Lista {
    $acc = Get-AccScelto $ui.cbDa
    if (-not $acc) { $ui.dg.ItemsSource = $null; return }
    $script:Tutte = @(Get-Schede $acc | Sort-Object UltimaAttivita -Descending | ForEach-Object {
        $_ | Add-Member -NotePropertyName UltimaTesto -NotePropertyValue $(if ($_.UltimaAttivita) { $_.UltimaAttivita.ToString('dd/MM/yyyy HH:mm') } else { '' }) -PassThru |
             Add-Member -NotePropertyName ArchTesto -NotePropertyValue $(if ($_.Archiviata) { 'si' } else { '' }) -PassThru
    })
    Apply-Filtro
}
function Apply-Filtro {
    $q = $ui.tbCerca.Text.Trim()
    $v = @($script:Tutte | Where-Object {
        ($ui.chArchiviate.IsChecked -or -not $_.Archiviata) -and
        (-not $q -or "$($_.Titolo) $($_.Cartella)" -like "*$q*")
    })
    $ui.dg.ItemsSource = $v
    $ui.txSel.Text = "$($v.Count) sessioni mostrate, 0 selezionate"
}

$ui.cbDa.Add_SelectionChanged({ Update-Lista })
$ui.tbCerca.Add_TextChanged({ Apply-Filtro })
$ui.chArchiviate.Add_Click({ Apply-Filtro })
$ui.btTutte.Add_Click({ $ui.dg.SelectAll() })
$ui.btAggiorna.Add_Click({ Update-Stato; Update-Lista })
$ui.dg.Add_SelectionChanged({ $ui.txSel.Text = "$(@($ui.dg.ItemsSource).Count) sessioni mostrate, $($ui.dg.SelectedItems.Count) selezionate" })

# Controlli comuni ad Anteprima ed Esegui; restituisce $null se manca qualcosa
function Get-Richiesta {
    $da = Get-AccScelto $ui.cbDa; $a = Get-AccScelto $ui.cbA
    if (-not $da -or -not $a) { [void][Windows.MessageBox]::Show("Scegliere l'account di origine e quello di destinazione.", "Sposta sessioni"); return $null }
    if ($da.Name -eq $a.Name) { [void][Windows.MessageBox]::Show("Origine e destinazione coincidono.", "Sposta sessioni"); return $null }
    $sel = @($ui.dg.SelectedItems)
    if ($sel.Count -eq 0) { [void][Windows.MessageBox]::Show("Selezionare almeno una sessione.", "Sposta sessioni"); return $null }
    return @{ Da = $da; A = $a; Scelte = $sel; Modalita = $(if ($ui.rbCopia.IsChecked) { 'Copia' } else { 'Sposta' }) }
}

$ui.btProva.Add_Click({
    $r = Get-Richiesta; if (-not $r) { return }
    try { [void](Invoke-Operazione $r.Da $r.A $r.Scelte $r.Modalita $true) } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
})

$ui.btEsegui.Add_Click({
    $r = Get-Richiesta; if (-not $r) { return }
    $msg = "$($r.Modalita) $($r.Scelte.Count) sessioni da $(Get-NomeAccount $r.Da.Name) a $(Get-NomeAccount $r.A.Name).`n`n" +
           "L'app desktop di Claude verra' chiusa (le sessioni in corso nell'app si fermano).`nProcedere?"
    if ([Windows.MessageBox]::Show($msg, "Sposta sessioni", 'YesNo', 'Question') -ne 'Yes') { return }
    try {
        $chiusa = Close-App
        $cli = (Get-ProcessiCli).Count
        if ($cli -gt 0) {
            $m2 = "Ci sono $cli processi Claude Code da terminale aperti.`nSe uno lavora su una sessione scelta, va chiuso prima di riprenderla con l'altro account.`n`nContinuare?"
            if ([Windows.MessageBox]::Show($m2, "Sposta sessioni", 'YesNo', 'Warning') -ne 'Yes') { Write-Log "Annullato (app non riaperta)."; Update-Stato; return }
        }
        $f = Invoke-Operazione $r.Da $r.A $r.Scelte $r.Modalita $false
        if ($ui.chRiapri.IsChecked) { Start-App }                                    # riapre l'app (anche se era gia' chiusa)
        Fill-Account; $ui.cbDa.SelectedIndex = [array]::IndexOf($accounts, $r.Da); $ui.cbA.SelectedIndex = [array]::IndexOf($accounts, $r.A)
        Update-Lista
        if ($f) { Write-Log "Per annullare: 'Ripristina da registro...' e scegliere $([IO.Path]::GetFileName($f))" }
    } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
    Update-Stato
})

$ui.btRipristina.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = $(if (Test-Path $Registri) { $Registri } else { $PSScriptRoot })
    $dlg.Filter = "Registri (sposta_*.csv)|sposta_*.csv"
    if ($dlg.ShowDialog() -ne 'OK') { return }
    if ([Windows.MessageBox]::Show("Annullare le operazioni di $([IO.Path]::GetFileName($dlg.FileName))?`nL'app desktop verra' chiusa.", "Sposta sessioni", 'YesNo', 'Question') -ne 'Yes') { return }
    try { Invoke-Ripristino $dlg.FileName $false ([bool]$ui.chRiapri.IsChecked); Fill-Account; Update-Lista } catch { Write-Log "ERRORE: $($_.Exception.Message)" }
    Update-Stato
})

# Avvio: personale come origine e lavoro come destinazione se presenti, altrimenti i primi due account
Fill-Account
$iDa = [array]::IndexOf(@($accounts | ForEach-Object { Get-NomeAccount $_.Name }), 'personale'); if ($iDa -lt 0) { $iDa = 0 }
$iA  = [array]::IndexOf(@($accounts | ForEach-Object { Get-NomeAccount $_.Name }), 'lavoro');    if ($iA -lt 0) { $iA = [Math]::Min(1, $accounts.Count - 1) }
$ui.cbDa.SelectedIndex = $iDa; $ui.cbA.SelectedIndex = $iA
Update-Stato
Write-Log "Sposta-SessioniClaude v$Version  |  schede: $radice  |  $($accounts.Count) account"
if ($accounts.Count -lt 2) { Write-Log "Sul PC c'e' un solo account nell'app desktop: niente da spostare." }
[void]$win.ShowDialog()
#>

# =============================================================================================================
# 2026-10-26 v1.0 - corpo principale precedente (solo riga di comando), sostituito dalla v1.1:
<#
# =============================================================================================================
$radice = Get-RadiceSchede
$backup = Join-Path (Split-Path $radice -Parent) 'claude-code-sessions-backup'
Write-Host "Sposta-SessioniClaude v$Version  |  schede: $radice"

# --- Ripristino -----------------------------------------------------------------------------------------------
if ($Ripristina) {
    $righe = @(Import-Csv $Ripristina -Delimiter ';')
    $chiusa = $false
    if (-not $Prova) { $chiusa = Close-App }
    foreach ($r in $righe) {
        if ($Prova) { Write-Host "[prova] annullerei: $($r.Azione) $($r.Titolo)"; continue }
        if ($r.Destinazione -and (Test-Path $r.Destinazione)) { Remove-Item $r.Destinazione -Force }   # scheda creata dal tool
        if ($r.Azione -eq 'Sposta' -and $r.Backup -and (Test-Path $r.Backup) -and -not (Test-Path $r.Origine)) {
            Move-Item $r.Backup $r.Origine                                             # rimette la scheda originale
        }
        Write-Host "Annullato: $($r.Titolo)"
    }
    if ($Riavvia -or $chiusa) { if (-not $Prova) { Start-App } }
    return
}

# --- Scelta degli account -------------------------------------------------------------------------------------
$accounts = @(Get-ChildItem $radice -Directory | Where-Object { $_.Name -match '^[0-9a-f-]{36}$' })
if ($accounts.Count -lt 2) { throw "Sul PC c'e' un solo account nell'app desktop: niente da spostare." }
$scegli = { param($titolo, $escludi)
    $sel = $accounts | Where-Object { $_.Name -ne $escludi } |
        ForEach-Object { [pscustomobject]@{ Account = (Get-NomeAccount $_.Name); Uuid = $_.Name; Schede = @(Get-ChildItem $_.FullName -Recurse -Filter 'local_*.json').Count } } |
        Out-GridView -Title $titolo -OutputMode Single
    if (-not $sel) { throw "Nessun account scelto." }
    $accounts | Where-Object { $_.Name -eq $sel.Uuid }
}
$accDa = if ($Da) { Resolve-Account $radice $Da } else { & $scegli "Account di ORIGINE" "" }
$accA  = if ($A)  { Resolve-Account $radice $A }  else { & $scegli "Account di DESTINAZIONE" $accDa.Name }
if ($accDa.Name -eq $accA.Name) { throw "Origine e destinazione coincidono." }
$orgA = Get-OrgDestinazione $accA
Write-Host "$Modalita da $(Get-NomeAccount $accDa.Name) a $(Get-NomeAccount $accA.Name) (organizzazione $($orgA.Name))"

# --- Scelta delle sessioni ------------------------------------------------------------------------------------
$schede = @(Get-Schede $accDa | Sort-Object UltimaAttivita -Descending)
if ($Sessioni.Count) { $scelte = @($schede | Where-Object { $Sessioni -contains $_.Id }) }
else { $scelte = @($schede | Out-GridView -Title "Sessioni da $($Modalita.ToLower()) (Ctrl/Maiusc per sceglierne piu' di una)" -PassThru) }
if ($scelte.Count -eq 0) { Write-Host "Nessuna sessione scelta."; return }

# --- Conferma, chiusura dell'app, controllo sessioni da terminale ----------------------------------------------
$chiusa = $false
if (-not $Prova) {
    $ok = Read-Host "$Modalita $($scelte.Count) sessioni: l'app desktop verra' chiusa. Procedere? [S/N]"
    if ($ok -notmatch '^[sS]') { Write-Host "Annullato."; return }
    $chiusa = Close-App
    # controllo dopo la chiusura dell'app, cosi' i suoi processi figli non vengono contati
    $cli = Get-ProcessiCli
    if ($cli.Count -gt 0) {
        Write-Warning "Ci sono $($cli.Count) processi Claude Code da terminale aperti: se uno lavora su una sessione scelta, va chiuso prima di riprenderla con l'altro account."
        $ok = Read-Host "Continuare comunque? [S/N]"
        if ($ok -notmatch '^[sS]') { Write-Host "Annullato (app non riaperta)."; return }
    }
}

# --- Esecuzione -------------------------------------------------------------------------------------------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = @()
foreach ($s in $scelte) {
    $dest = Join-Path $orgA.FullName ([IO.Path]::GetFileName($s.File))
    $esiste = @(Get-ChildItem $accA.FullName -Recurse -Filter ([IO.Path]::GetFileName($s.File))).Count -gt 0
    $bk = Join-Path $backup ("$stamp\" + $s.File.Substring($radice.Length).TrimStart('\'))
    if ($Prova) { Write-Host "[prova] $Modalita '$($s.Titolo)'$(if ($esiste) { ' (gia'' presente nella destinazione)' })"; continue }
    $creata = ""
    if (-not $esiste) { Write-Scheda $s.File $dest; $creata = $dest }
    $bkFatto = ""
    if ($Modalita -eq 'Sposta') {
        New-Item -ItemType Directory -Force (Split-Path $bk -Parent) | Out-Null
        Move-Item $s.File $bk                                                          # mai cancellata: va in backup
        $bkFatto = $bk
    }
    $log += [pscustomobject]@{ Data = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); Azione = $Modalita; Titolo = $s.Titolo; Id = $s.Id
                               Da = (Get-NomeAccount $accDa.Name); A = (Get-NomeAccount $accA.Name)
                               Origine = $s.File; Destinazione = $creata; Backup = $bkFatto }
    Write-Host "$Modalita fatto: $($s.Titolo)$(if ($esiste) { ' (scheda gia'' presente nella destinazione, non riscritta)' })"
}
if ($log.Count) {
    New-Item -ItemType Directory -Force $Registri | Out-Null
    $f = Join-Path $Registri "sposta_$stamp.csv"
    $log | Export-Csv $f -Delimiter ';' -NoTypeInformation -Encoding UTF8
    Write-Host "Registro: $f  (annullare con -Ripristina `"$f`")"
}
if (($Riavvia -or $chiusa) -and -not $Prova) { Start-App }
#>

# =============================================================================================================
# 2026-10-26 v1.2 - Update-Lato / Apply-Filtro (pannelli indipendenti, nessun colore), sostituiti dalla v1.3:
<#
# Carica le sessioni di un lato; "Anche nell'altro" = la stessa sessione ha una scheda anche nell'account opposto
function Update-Lato([string]$k) {
    $acc = Get-AccLato $k; $alt = Get-AccLato (Get-Opposto $k)
    if (-not $acc) { $Lati[$k].Tutte = @(); Apply-Filtro $k; return }
    $idAltro = @{}
    if ($alt -and $alt.Name -ne $acc.Name) { foreach ($x in @(Get-Schede $alt)) { $idAltro[$x.Id] = $true } }
    $Lati[$k].Tutte = @(Get-Schede $acc | Sort-Object UltimaAttivita -Descending | ForEach-Object {
        $_ | Add-Member -NotePropertyName UltimaTesto -NotePropertyValue $(if ($_.UltimaAttivita) { $_.UltimaAttivita.ToString('dd/MM/yyyy HH:mm') } else { '' }) -PassThru |
             Add-Member -NotePropertyName Altro -NotePropertyValue $(if ($idAltro.ContainsKey($_.Id)) { 'si' } else { '' }) -PassThru
    })
    Apply-Filtro $k
}
function Update-Tutto { Update-Lato 'L'; Update-Lato 'R'; Update-Stato }
function Apply-Filtro([string]$k) {
    $q = $Lati[$k].tb.Text.Trim()
    $v = @($Lati[$k].Tutte | Where-Object {
        ($ui.chArchiviate.IsChecked -or -not $_.Archiviata) -and (-not $q -or "$($_.Titolo) $($_.Cartella)" -like "*$q*")
    })
    $Lati[$k].dg.ItemsSource = $v
    $Lati[$k].tx.Text = "$($v.Count) sessioni mostrate su $(@($Lati[$k].Tutte).Count), $($Lati[$k].dg.SelectedItems.Count) selezionate"
}

#>
