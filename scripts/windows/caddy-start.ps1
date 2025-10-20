param(
  [string]$CaddyExe = 'C:\tools\caddy\caddy_windows_amd64.exe',
  [int]$ListenPort = 5274,
  [int]$ApiPort = 3000
)

# Autodetectar caddy.exe si no existe la ruta indicada
if (-not (Test-Path $CaddyExe)) {
  $cmd = Get-Command caddy -ErrorAction SilentlyContinue
  if ($cmd) { $CaddyExe = $cmd.Source }
}
if (-not (Test-Path $CaddyExe)) {
  if (Test-Path 'C:\Program Files\Caddy\caddy.exe') { $CaddyExe = 'C:\Program Files\Caddy\caddy.exe' }
}
if (-not (Test-Path $CaddyExe)) {
  Write-Error "No encuentro caddy.exe. Ajusta -CaddyExe."
  exit 1
}

# --- Caddyfile (mínimo, WS incluido) ---
# Generación minimalista: proxy todo (incluye /health, /ws y /ws-test) a la API.
# Si en el futuro quieres activar compresión o un matcher explícito para /ws,
# descomenta las líneas marcadas abajo ("OPTION: ...").
$cfg = @"
:$ListenPort {
  # OPTION: habilitar compresión (version anterior):
  # encode zstd gzip

  # OPTION: matcher explícito para WS (version anterior):
  # @ws path /ws
  # reverse_proxy @ws 127.0.0.1:$ApiPort

  # Proxy todo (incluye /health y rutas WS)
  reverse_proxy 127.0.0.1:$ApiPort
}
"@

$cfgPath = Join-Path $PSScriptRoot 'Caddyfile.gen'
$cfg | Out-File -Encoding ascii $cfgPath

# Si hay un Caddy previo, lo paramos
$pidPath = Join-Path $PSScriptRoot 'caddy.pid'
if (Test-Path $pidPath) {
  try {
    $oldPid = Get-Content $pidPath | Select-Object -First 1
    if ($oldPid) { Stop-Process -Id $oldPid -ErrorAction SilentlyContinue }
  } catch {}
}

Write-Host "Iniciando Caddy ($CaddyExe): :$ListenPort -> 127.0.0.1:$ApiPort (incluye WS /ws)"
$proc = Start-Process -FilePath $CaddyExe -ArgumentList @('run','--config', $cfgPath) -NoNewWindow -PassThru
$proc.Id | Out-File -Encoding ascii $pidPath
Write-Host "Caddy PID: $($proc.Id) (guardado en $pidPath)"
