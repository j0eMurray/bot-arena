param(
  [string]$EnvPath = $null,
  [int]$Port = 5173
)

# Repo root = ...\bot-arena-pre-alpha
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if (-not $EnvPath) {
  $EnvPath = Join-Path $RepoRoot "app\.env.dev"
}
$FullPath = Resolve-Path -Path $EnvPath -ErrorAction SilentlyContinue
if (-not $FullPath) { Write-Error "Env file not found: $EnvPath"; exit 1 }

# Lee .env (K=V)
$vars = @{}
Get-Content $FullPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#")) {
    $k,$v = $line.Split("=",2)
    $vars[$k.Trim()] = $v.Trim()
  }
}
if (-not $vars.ContainsKey("API_BASE_URL") -or -not $vars.ContainsKey("WS_URL")) {
  Write-Error "API_BASE_URL or WS_URL missing in $FullPath"; exit 1
}

# Mata proceso que esté en $Port
try {
  $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($conns) {
    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($p in $pids) {
      Write-Host ("Deteniendo proceso previo en puerto {0} (PID {1})..." -f $Port, $p)
      Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }
  }
} catch {}

Write-Host ("Launching Flutter web-server on 0.0.0.0:{0}" -f $Port)
$api = $vars["API_BASE_URL"]
$ws  = $vars["WS_URL"]

Push-Location (Join-Path $RepoRoot "app")
flutter run -d web-server --web-hostname 0.0.0.0 --web-port $Port `
  --dart-define=API_BASE_URL=$api `
  --dart-define=WS_URL=$ws
Pop-Location
