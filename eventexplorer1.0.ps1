Clear-Host
$Host.UI.RawUI.WindowTitle = "Event Explorer"

Write-Host "Event Explorer Iniciando..." -ForegroundColor Cyan

# ================= CONFIG =================
$MaxEventsPerLog = 500
$Logs = @("Application","System","Security")
$OutputFile = Join-Path $env:TEMP "Event_Explorer.html"

# ================= COLETAR LOGS =================
$Events = @()

foreach ($Log in $Logs) {
    try {
        Write-Host "Coletando: $Log" -ForegroundColor Yellow
        $Events += Get-WinEvent -LogName $Log -MaxEvents $MaxEventsPerLog -ErrorAction Stop
    } catch {}
}

Write-Host "Total coletado: $($Events.Count) eventos" -ForegroundColor Green

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

    # LEVEL NORMALIZADO
    switch ($Event.Level) {
        1 { $Level = "Critical" }
        2 { $Level = "Error" }
        3 { $Level = "Warning" }
        4 { $Level = "Information" }
        default { $Level = "Information" }
    }

    # CRITICAL IDS
    $CriticalIDs = @(4624,4625,4688,1102,4719)
    $CriticalClass = if ($CriticalIDs -contains $Event.Id) { "criticalRow" } else { "" }

    # MESSAGE
    $FullMessage = ($Event.Message -replace "`n"," ")
    $ShortMessage = if ($FullMessage.Length -gt 200) {
        $FullMessage.Substring(0,200) + "..."
    } else { $FullMessage }

    # IP
    $IP = "-"
    if ($FullMessage -match "(\d{1,3}\.){3}\d{1,3}") { $IP = $Matches[0] }

$Rows += @"
<tr class="dataRow $CriticalClass"
 data-id="$($Event.Id)"
 data-level="$Level"
 data-log="$($Event.LogName)"
 data-search="$($Event.Id) $User $IP $FullMessage">

<td>$($Event.TimeCreated)</td>
<td class="log-$($Event.LogName.ToLower())">$($Event.LogName)</td>
<td>$($Event.Id)</td>
<td class="lvl-$($Level.ToLower())">$Level</td>
<td>$User</td>
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
 --bg:#0b1320;
 --panel:#111827;
 --header:#020617;
 --text:#e5e7eb;
 --border:#1f2937;
 --input:#1e293b;
}

body.light{
 --bg:#f3f4f6;
 --panel:#ffffff;
 --header:#e5e7eb;
 --text:#111827;
 --border:#d1d5db;
 --input:#f9fafb;
}

body{
 background:var(--bg);
 color:var(--text);
 font-family:Segoe UI;
 margin:15px;
 transition:.2s;
}

.topBar{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;}
.title{font-size:18px;font-weight:700;display:flex;align-items:center;gap:6px;}
.filters{display:flex;gap:8px;align-items:center;}

input,select{
 background:var(--input);
 color:var(--text);
 border:none;
 padding:6px 10px;
 border-radius:10px;
 font-size:12px;
}

button{
 background:var(--border);
 color:var(--text);
 border:none;
 padding:6px 12px;
 border-radius:10px;
 cursor:pointer;
}

.counter{padding:5px 12px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;}
.info{background:#1d4ed8;}
.warn{background:#b45309;}
.error{background:#991b1b;}
.crit{background:#7f1d1d;}

table{
 width:100%;
 border-collapse:separate;
 border-spacing:0;
 background:var(--panel);
 border-radius:14px;
 overflow:hidden;
}

th{background:var(--header);padding:12px;font-size:12px;}
td{padding:10px;border-bottom:1px solid var(--border);font-size:12px;}
tr:hover{background:var(--border);}
tr:last-child td{border-bottom:none;}

.criticalRow{border-left:4px solid #ef4444;}
.msgFull{display:none;}

/* LOG COLORS */
.log-application{color:#2563eb;}
.log-system{color:#059669;}
.log-security{color:#dc2626;}

/* LEVEL COLORS */
.lvl-information{color:#3b82f6;font-weight:600;}
.lvl-warning{color:#f59e0b;font-weight:600;}
.lvl-error{color:#ef4444;font-weight:700;}
.lvl-critical{color:#dc2626;font-weight:800;}
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
 searchBox.value="";
 idFilter.value="";
 logFilter.value="All";
 activeLevel="All";
 filterTable();
}

function toggleTheme(){
 document.body.classList.toggle("light");
 localStorage.setItem("theme",document.body.classList.contains("light")?"light":"dark");
 themeBtn.innerText=document.body.classList.contains("light")?"🌙":"☀️";
}

window.onload=()=>{
 if(localStorage.getItem("theme")==="light"){
  document.body.classList.add("light");
  themeBtn.innerText="🌙";
 }else{
  themeBtn.innerText="☀️";
 }
};
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
   <option>All</option>
   <option>Application</option>
   <option>System</option>
   <option>Security</option>
  </select>

  <button onclick="clearFilters()">Limpar</button>
  <button onclick="toggleTheme()" id="themeBtn">☀️</button>
 </div>
</div>

<table>
<thead>
<tr>
 <th>DATE</th>
 <th>LOG</th>
 <th>ID</th>
 <th>LEVEL</th>
 <th>USER</th>
 <th>MESSAGE</th>
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

Write-Host "Dashboard pronto e aberto no navegador." -ForegroundColor Cyan
