Clear-Host
$Host.UI.RawUI.WindowTitle = "Event Explorer"

Write-Host "Event Explorer iniciando..." -ForegroundColor Cyan

# ================= CONFIG =================
$MaxEventsPerLog = 800
$Logs = @("Application","System","Security")
$OutputFile = Join-Path $env:TEMP "Event_Explorer.html"

# ================= COLETA =================
$Events = @()
foreach ($Log in $Logs) {
    try {
        Write-Host "Coletando: $Log" -ForegroundColor Yellow
        $Events += Get-WinEvent -LogName $Log -MaxEvents $MaxEventsPerLog
    } catch {}
}
Write-Host "Eventos coletados: $($Events.Count)" -ForegroundColor Green

# ================= FUNÇÃO: EXTRAIR IP REAL =================
function Get-RealIP($text) {

    # Somente se existir contexto de IP (evita pegar versões)
    if ($text -notmatch '(?i)(source|client|remote|ip address|ipv4|network address)') {
        return "-"
    }

    # Regex IPv4 real (0–255)
    if ($text -match '(?<!\d)((?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})(?!\d)') {
        return $Matches[1]
    }

    return "-"
}

# ================= FUNÇÃO: EXTRAIR PORTA =================
function Get-Port($text) {
    if ($text -match '(?i)port(?:a)?\s*[:=]\s*(\d{1,5})') { return $Matches[1] }
    if ($text -match ':(\d{1,5})\b') { return $Matches[1] }
    return "-"
}

# ================= GERAR LINHAS =================
$Rows = ""

foreach ($Event in $Events) {

    # USER
    $User = "-"
    if ($Event.UserId) {
        try {
            $User = (New-Object System.Security.Principal.SecurityIdentifier($Event.UserId)).
                    Translate([System.Security.Principal.NTAccount]).Value
        } catch {}
    }

    # LEVEL
    switch ($Event.Level) {
        1 { $Level="Critical" }
        2 { $Level="Error" }
        3 { $Level="Warning" }
        default { $Level="Information" }
    }

    # MESSAGE
    $FullMessage = ($Event.Message -replace "`n"," ")
    $ShortMessage = if ($FullMessage.Length -gt 220) { $FullMessage.Substring(0,220)+"..." } else { $FullMessage }

    # IP e PORTA (corrigidos)
    $IP   = Get-RealIP $FullMessage
    $Port = Get-Port  $FullMessage

$Rows += @"
<tr class="dataRow"
 data-id="$($Event.Id)"
 data-level="$Level"
 data-log="$($Event.LogName)"
 data-search="$($Event.Id) $User $IP $Port $FullMessage">

<td>$($Event.TimeCreated)</td>
<td class="log-$($Event.LogName.ToLower())">$($Event.LogName)</td>
<td>$($Event.Id)</td>
<td class="lvl-$($Level.ToLower())">$Level</td>
<td>$User</td>
<td>$IP</td>
<td>$Port</td>
<td>
 <div class="msgShort">$ShortMessage</div>
 <div class="msgFull">$($Event.Message -replace "`n","<br>")</div>
</td>
</tr>
"@
}

# ================= CONTADORES =================
$CountInfo  = ($Events | Where-Object Level -eq 4).Count
$CountWarn  = ($Events | Where-Object Level -eq 3).Count
$CountError = ($Events | Where-Object Level -eq 2).Count
$CountCrit  = ($Events | Where-Object Level -eq 1).Count

# ================= HTML =================
$HTML = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Event Explorer</title>

<style>
:root{
 --bg:#0b1320;--panel:#111827;--header:#020617;--text:#e5e7eb;
 --border:#1f2937;--input:#1e293b;
}
body.light{
 --bg:#f3f4f6;--panel:#ffffff;--header:#e5e7eb;--text:#111827;
 --border:#d1d5db;--input:#f9fafb;
}
body{background:var(--bg);color:var(--text);font-family:Segoe UI;margin:15px;}
.topBar{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;}
.filters{display:flex;gap:8px;align-items:center;}
input,select,button{
 background:var(--input);color:var(--text);border:none;
 padding:6px 10px;border-radius:10px;font-size:12px;
}
button{cursor:pointer;}
.counter{padding:5px 12px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;}
.info{background:#1d4ed8;} .warn{background:#b45309;}
.error{background:#991b1b;} .crit{background:#7f1d1d;}

table{width:100%;border-collapse:separate;border-spacing:0;background:var(--panel);border-radius:14px;overflow:hidden;}
th{background:var(--header);padding:10px;font-size:12px;}
td{padding:8px;border-bottom:1px solid var(--border);font-size:11px;}
tr:hover{background:var(--border);}
.msgFull{display:none;}

.log-application{color:#2563eb;}
.log-system{color:#059669;}
.log-security{color:#dc2626;}
.lvl-information{color:#3b82f6;}
.lvl-warning{color:#f59e0b;}
.lvl-error{color:#ef4444;}
.lvl-critical{color:#dc2626;}
</style>

<script>
let activeLevel="All";

function toggleRow(e){
 let r=e.target.closest("tr");
 if(!r) return;
 let f=r.querySelector(".msgFull");
 let s=r.querySelector(".msgShort");
 f.style.display=f.style.display==="block"?"none":"block";
 s.style.display=s.style.display==="none"?"block":"none";
}

function filterTable(){
 let search=searchBox.value.toLowerCase();
 let ids=idFilter.value.split(/[ ,]+/).filter(x=>x);
 let log=logFilter.value;

 document.querySelectorAll(".dataRow").forEach(r=>{
  let show=true;
  if(search && !r.dataset.search.toLowerCase().includes(search)) show=false;
  if(ids.length && !ids.includes(r.dataset.id)) show=false;
  if(activeLevel!="All" && r.dataset.level!=activeLevel) show=false;
  if(log!="All" && r.dataset.log!=log) show=false;
  r.style.display=show?"":"none";
 });
}

function setLevel(l){activeLevel=l;filterTable();}
function clearFilters(){
 searchBox.value=""; idFilter.value=""; logFilter.value="All"; activeLevel="All"; filterTable();
}
function toggleTheme(){
 document.body.classList.toggle("light");
}
</script>
</head>

<body onclick="toggleRow(event)">

<div class="topBar">
 <div class="title">🛡️ Event Explorer</div>
 <div class="filters">
  <span class="counter info" onclick="setLevel('Information')">INFO $CountInfo</span>
  <span class="counter warn" onclick="setLevel('Warning')">WARN $CountWarn</span>
  <span class="counter error" onclick="setLevel('Error')">ERROR $CountError</span>
  <span class="counter crit" onclick="setLevel('Critical')">CRIT $CountCrit</span>

  <input id="searchBox" placeholder="Search User, IP, Keyword" onkeyup="filterTable()">
  <input id="idFilter" placeholder="IDs: 1001,7031" onkeyup="filterTable()">

  <select id="logFilter" onchange="filterTable()">
   <option>All</option><option>Application</option><option>System</option><option>Security</option>
  </select>

  <button onclick="clearFilters()">Limpar</button>
  <button onclick="toggleTheme()">☀️</button>
 </div>
</div>

<table>
<thead>
<tr>
 <th>DATE</th><th>LOG</th><th>ID</th><th>LEVEL</th>
 <th>USER</th><th>IP</th><th>PORT</th><th>MESSAGE</th>
</tr>
</thead>
<tbody>
$Rows
</tbody>
</table>

</body>
</html>
"@

$HTML | Out-File -Encoding UTF8 $OutputFile
Start-Process $OutputFile

Write-Host "Abrindo Dashboard no navegador" -ForegroundColor Green
