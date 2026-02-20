# ==========================================
# EVENT EXPLORER
# ==========================================
Clear-Host

# --------- Parâmetros ---------
$MaxEventsPerLog = 2000    # eventos por log (Application, System, Security) para a grade
$OutputFile      = Join-Path $env:TEMP 'Event_Explorer.html'

# --------- Infos do topo ---------
$HostName    = $env:COMPUTERNAME
$GeneratedAt = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss')

# --------- Utilidades ---------
function Encode-Html { param([string]$s) if ($null -eq $s) { '' } else { [System.Net.WebUtility]::HtmlEncode($s) } }

function Normalize-Level {
    param([string]$LevelDisplayName)
    switch -Regex ($LevelDisplayName) {
        '^(Information|Informação|Informações)$' { 'Informações' }
        '^(Warning|Aviso)$'                      { 'Aviso' }
        '^(Error|Erro)$'                         { 'Erro' }
        '^(Critical|Crítico)$'                   { 'Crítico' }
        default { if ($LevelDisplayName) { $LevelDisplayName } else { 'Desconhecido' } }
    }
}
function Level-Class {
    param([string]$LevelNorm)
    switch -Regex ($LevelNorm) {
        '^Inform'      { 'lvl-info' }
        '^(Aviso|Warn)'{ 'lvl-warn' }
        '^(Erro|Error)'{ 'lvl-err'  }
        '^(Crít|Crit)' { 'lvl-crit' }
        default        { 'lvl-unk'  }
    }
}

# --------- Coleta (somente Application/System/Security; por log) ---------
$WantedLogs = @('Application','System','Security')

# Verifica logs habilitados
$EnabledWanted = @()
foreach ($ln in $WantedLogs) {
    try {
        $logInfo = Get-WinEvent -ListLog $ln -ErrorAction Stop
        if ($logInfo.IsEnabled) { $EnabledWanted += $ln }
    } catch { }
}

# Coleta por log com limite individual (evita perder IDs como 1001)
$allRows = New-Object System.Collections.Generic.List[object]
foreach ($ln in $EnabledWanted) {
    try {
        $items = Get-WinEvent -LogName $ln -MaxEvents $MaxEventsPerLog -ErrorAction Stop |
                 Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message, LogName,
                               @{n='EpochMs';e={ ([DateTimeOffset]$_.TimeCreated).ToUnixTimeMilliseconds() }}
        foreach ($it in $items) { $allRows.Add($it) | Out-Null }
    } catch { }
}

# Ordena globalmente por data/hora (desc)
$Events = $allRows | Sort-Object TimeCreated -Descending

# Projeção final e normalização mínima
$Data = foreach ($E in $Events) {
    $levelNorm = Normalize-Level $E.LevelDisplayName
    $levelCls  = Level-Class     $levelNorm
    [PSCustomObject]@{
        TimeCreated = $E.TimeCreated
        EpochMs     = $E.EpochMs
        LogName     = if ($E.LogName) { $E.LogName } else { 'Desconhecido' }
        Id          = [int]$E.Id
        LevelName   = $levelNorm
        LevelClass  = $levelCls
        Provider    = if ($E.ProviderName) { $E.ProviderName } else { '' }
        Message     = if ($E.Message) { $E.Message } else { '' }
    }
}

# --------- HTML (clean) ---------
$HtmlHeader = @"
<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<title>🛡️ Event Explorer</title>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
  :root{
    --bg:#0b1220; --panel:#111827; --ink:#e5e7eb; --muted:#9ca3af; --line:#1f2937;
    --tab:#1f2937; --tab-active:#0ea5e9; --ink-dark:#0b1220;
    --lvl-info:#38bdf8; --lvl-warn:#eab308; --lvl-err:#ef4444; --lvl-crit:#b91c1c; --lvl-unk:#94a3b8;
    --accent:#22c55e;
  }
  *{ box-sizing:border-box; }
  body{ margin:0; font-family:Segoe UI, Arial, Helvetica, sans-serif; background:var(--bg); color:var(--ink); }
  header{
    padding:16px 24px; display:flex; justify-content:space-between; align-items:center;
    background:#0f172a; border-bottom:1px solid #0b1a2b; font-weight:600;
  }
  .meta{ color:var(--muted); font-size:12px; }

  /* Container largo (sem scroll horizontal) */
  .container{
    margin:28px auto;
    max-width: 96vw;   /* ocupa quase a tela inteira */
    padding:0 8px;     /* padding curto para ganhar espaço útil */
  }

  /* Tabs (topo do container) */
  .tabs{ display:flex; gap:8px; border-bottom:1px solid var(--line); margin-bottom:14px; flex-wrap:wrap; }
  .tab-btn{
    padding:8px 14px; border:none; background:var(--tab); color:var(--ink); border-radius:8px 8px 0 0; cursor:pointer; font-size:13px;
  }
  .tab-btn.active{
    background:var(--tab-active); color:var(--ink-dark); font-weight:700;
    box-shadow: 0 -2px 0 0 var(--tab-active) inset, 0 2px 0 0 var(--panel);
  }
  .tab-btn:not(.active):hover{ background:#243041; }

  /* Toolbar: busca por ID + filtro de nível */
  .toolbar{
    display:flex; gap:10px; align-items:center; padding:12px;
    background:var(--panel); border:1px solid var(--line); border-radius:10px; margin-bottom:14px; flex-wrap:wrap;
  }
  .toolbar label{ font-size:13px; color:var(--muted); }
  .id-input, .level-select{
    padding:8px 12px; border:none; outline:none; background:#1f2937; color:#fff; border-radius:8px; font-size:13px;
  }
  .id-input{ width:220px; }
  .level-select{ width:180px; }
  .btn{ padding:8px 12px; border:none; border-radius:8px; cursor:pointer; font-size:13px; }
  .btn-clear{ background:#0f172a; color:var(--ink); border:1px solid var(--line); }
  .btn-clear:hover{ background:#162236; }

  /* Tabela — sem scroll horizontal (quebra de linha) */
  .panel{ background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:6px 0; }
  .table-wrap{
    overflow-x: hidden;  /* impede barra horizontal */
    overflow-y: visible; /* rolagem vertical natural da página */
  }
  table{
    width:100%;
    border-collapse:collapse;
    font-size:13px;
    table-layout: fixed; /* wraps previsíveis e sem overflow */
  }
  thead th{
    position:sticky; top:0; z-index:1; background:#141c2a; color:var(--muted); text-transform:uppercase;
    font-size:11px; letter-spacing:.4px; text-align:left; padding:12px 14px; border-bottom:1px solid var(--line);
  }
  tbody td{ padding:12px 14px; border-bottom:1px solid var(--line); vertical-align:top; }

  /* Larguras para caber sem scroll horizontal */
  .col-datetime{ width:160px; white-space:nowrap; }
  .col-id{ width:88px; font-weight:800; color:var(--accent); white-space:nowrap; }
  .col-log{ width:130px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .col-level{ width:120px; font-weight:800; white-space:nowrap; }
  .col-provider{ width:240px; overflow:hidden; text-overflow:ellipsis; }
  .col-message{
    width:auto; /* ocupa o restante */
    overflow-wrap:anywhere; word-break:break-word; white-space:normal;
  }

  tbody tr:hover{ background:#172133; }

  /* Cores por nível */
  .lvl-info{ color:var(--lvl-info); }
  .lvl-warn{ color:var(--lvl-warn); }
  .lvl-err { color:var(--lvl-err);  }
  .lvl-crit{ color:var(--lvl-crit); }
  .lvl-unk { color:var(--lvl-unk);  }

  details{ cursor:pointer; }
  summary{ list-style: disclosure-closed; color:var(--ink); }
  details[open] summary{ list-style: disclosure-open; }
</style>

<script>
  // Estado (aba e filtros)
  var currentLogTab = "Application"; // padrão

  function switchTab(tabId){
    document.querySelectorAll(".tab-btn").forEach(b=>b.classList.remove("active"));
    document.querySelector('[data-tab="'+tabId+'"]').classList.add("active");

    if (tabId==="tab-application") currentLogTab = "Application";
    else if (tabId==="tab-system") currentLogTab = "System";
    else if (tabId==="tab-security") currentLogTab = "Security";
    else currentLogTab = "Application";

    filtrar();
  }

  function filtrar(){
    // IDs
    var idTxt = (document.getElementById("idFilter").value || "").trim();
    var ids = idTxt.length>0 ? idTxt.split(/[\s,;]+/).filter(Boolean) : [];

    // Nível (valor normalizado)
    var lvlSel = (document.getElementById("levelFilter").value || "").trim(); // "", Informações, Aviso, Erro, Crítico, Desconhecido

    var rows = document.querySelectorAll("tbody.main-rows tr");
    rows.forEach(function(r){
      var okTab = (r.dataset.log === currentLogTab);

      var okId  = true;
      if (ids.length>0){
        var evId = (r.dataset.evid||"").toString();
        okId = ids.includes(evId);
      }

      var okLevel = true;
      if (lvlSel.length>0){
        var evLvl = (r.dataset.levelnorm||"");
        okLevel = (evLvl === lvlSel);
      }

      r.style.display = (okTab && okId && okLevel) ? "" : "none";
    });
  }

  function clearId(){ document.getElementById("idFilter").value=""; filtrar(); }
  function clearLevel(){ document.getElementById("levelFilter").value=""; filtrar(); }
  function clearAll(){ document.getElementById("idFilter").value=""; document.getElementById("levelFilter").value=""; filtrar(); }

  document.addEventListener("DOMContentLoaded", function(){
    switchTab("tab-application");
  });
</script>
</head>
<body>

<header>
  <div>🛡️ Event Explorer</div>
  <div class="meta">Host: $(Encode-Html $HostName) • Gerado em: $(Encode-Html $GeneratedAt)</div>
</header>

<div class="container">

  <!-- Abas no topo -->
  <div class="tabs">
    <button class="tab-btn active" data-tab="tab-application" onclick="switchTab('tab-application')">Application</button>
    <button class="tab-btn"        data-tab="tab-system"      onclick="switchTab('tab-system')">System</button>
    <button class="tab-btn"        data-tab="tab-security"    onclick="switchTab('tab-security')">Security</button>
  </div>

  <!-- Toolbar: ID + Nível -->
  <div class="toolbar">
    <label for="idFilter">Filtrar por ID:</label>
    <input id="idFilter" class="id-input" type="text" inputmode="numeric" pattern="[0-9,; ]*" placeholder="ex.: 1001 ou 1001,7031" oninput="filtrar()" />
    <label for="levelFilter">Nível:</label>
    <select id="levelFilter" class="level-select" onchange="filtrar()">
      <option value="">Todos</option>
      <option value="Informações">Informações</option>
      <option value="Aviso">Aviso</option>
      <option value="Erro">Erro</option>
      <option value="Crítico">Crítico</option>
      <option value="Desconhecido">Desconhecido</option>
    </select>
    <button class="btn btn-clear" onclick="clearAll()">Limpar</button>
  </div>

  <!-- Tabela -->
  <div class="panel">
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th class="col-datetime">Data/Hora</th>
            <th class="col-id">ID</th>
            <th class="col-log">Log</th>
            <th class="col-level">Nível</th>
            <th class="col-provider">Fonte</th>
            <th class="col-message">Mensagem</th>
          </tr>
        </thead>
        <tbody class="main-rows">
"@

# --------- Render das linhas ---------
$rows = New-Object System.Text.StringBuilder
foreach ($E in $Data) {
    $dateStr  = if ($E.TimeCreated) { $E.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss') } else { '' }
    $idStr    = $E.Id.ToString()
    $logName  = $E.LogName
    $level    = $E.LevelName
    $levelCls = $E.LevelClass
    $prov     = $E.Provider

    $msgHtml  = (Encode-Html $E.Message) -replace "(`r`n|`n|`r)", '<br/>'
    # preview com quebra garantida
    $preview  = ($msgHtml -replace '<br/>',' '); if($preview.Length -gt 240){ $preview = $preview.Substring(0,240) + '…' }

$null = $rows.AppendLine(@"
<tr data-log="$([System.Net.WebUtility]::HtmlEncode($logName))" data-evid="$idStr" data-levelnorm="$([System.Net.WebUtility]::HtmlEncode($level))">
  <td class="col-datetime">$dateStr</td>
  <td class="col-id">$idStr</td>
  <td class="col-log">$([System.Net.WebUtility]::HtmlEncode($logName))</td>
  <td class="col-level"><span class="$levelCls">$([System.Net.WebUtility]::HtmlEncode($level))</span></td>
  <td class="col-provider">$([System.Net.WebUtility]::HtmlEncode($prov))</td>
  <td class="col-message">
    <details>
      <summary>$preview</summary>
      <div style="margin-top:6px; color:#cbd5e1;">$msgHtml</div>
    </details>
  </td>
</tr>
"@)
}

$HtmlFooter = @"
        </tbody>
      </table>
    </div>
  </div> <!-- /panel -->

</div> <!-- /container -->
</body>
</html>
"@

# --------- Montagem final ---------
$FullHtml = $HtmlHeader + $rows.ToString() + $HtmlFooter

# --------- Grava e abre ---------
$FullHtml | Out-File -FilePath $OutputFile -Encoding UTF8 -Force

$opened = $false

# 1) Shell padrão
try { Start-Process -FilePath $OutputFile -ErrorAction Stop; $opened = $true } catch { }

# 2) Explorer
if (-not $opened) {
    try { Start-Process explorer.exe $OutputFile -ErrorAction Stop; $opened = $true } catch { }
}

# 3) Invoke-Item
if (-not $opened) {
    try { Invoke-Item -Path $OutputFile; $opened = $true } catch { }
}

# 4) Navegadores conhecidos
if (-not $opened) {
    $tryBrowsers = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
        "$env:ProgramFiles(x86)\Mozilla Firefox\firefox.exe"
    ) | Where-Object { Test-Path $_ }

    foreach ($exe in $tryBrowsers) {
        try { Start-Process -FilePath $exe -ArgumentList @($OutputFile) -ErrorAction Stop; $opened = $true; break } catch { }
    }
}

if (-not $opened) { Write-Warning "Não foi possível abrir automaticamente. Abra manualmente: $OutputFile" }
