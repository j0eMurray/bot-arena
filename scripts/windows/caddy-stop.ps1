param(
  [int]$ListenPort = 3001
)

$pidPath  = Join-Path $PSScriptRoot 'caddy.pid'
$cfgPath  = Join-Path $PSScriptRoot 'Caddyfile.gen'

function Stop-Ids([int[]]$ids, [int]$timeoutSec = 5) {
  $stopped = $false
  foreach ($id in $ids) {
    try {
      $p = Get-Process -Id $id -ErrorAction SilentlyContinue
      if ($p) {
        Write-Host ("Deteniendo Caddy por PID ({0})..." -f $id)
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        try { Wait-Process -Id $id -Timeout $timeoutSec -ErrorAction SilentlyContinue } catch {}
        if (-not (Get-Process -Id $id -ErrorAction SilentlyContinue)) { $stopped = $true }
      }
    } catch {
      Write-Warning ("No pude detener PID {0}: {1}" -f $id, $_.Exception.Message)
    }
  }
  return $stopped
}

function Get-PidsByCommandLine($cfg) {
  $ids = @()
  try {
    $procs = Get-CimInstance Win32_Process -Filter "Name='caddy.exe' OR Name='caddy_windows_amd64.exe'"
    foreach ($pr in $procs) {
      if (-not $cfg -or ($pr.CommandLine -and $pr.CommandLine -match [Regex]::Escape($cfg))) {
        $ids += [int]$pr.ProcessId
      }
    }
  } catch {}
  return $ids | Select-Object -Unique
}

function Get-PidsByPort([int]$port) {
  $ids = @()
  try {
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conns) { $ids += ($conns | Select-Object -ExpandProperty OwningProcess -Unique) }
  } catch {}
  return $ids | Select-Object -Unique
}

$stopped = $false

# 1) Por PID file
if (Test-Path $pidPath) {
  $CaddyPid = (Get-Content $pidPath | Select-Object -First 1).Trim()
  if ($CaddyPid -match '^\d+$') {
    $stopped = Stop-Ids @([int]$CaddyPid)
    if ($stopped) { Remove-Item $pidPath -Force -ErrorAction SilentlyContinue }
  }
}

# 2) Por CommandLine / nombre
if (-not $stopped) {
  $ids = Get-PidsByCommandLine $cfgPath
  if ($ids.Count -gt 0) { $stopped = Stop-Ids $ids }
}

# 3) Por puerto
if (-not $stopped) {
  $ids = Get-PidsByPort $ListenPort
  if ($ids.Count -gt 0) { $stopped = Stop-Ids $ids }
}

if ($stopped) {
  Write-Host "Caddy detenido."
} else {
  Write-Warning "No encontré proceso de Caddy para detener. Si se inició elevado, ejecuta este script en una consola elevada."
}
