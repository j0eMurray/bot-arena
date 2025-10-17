#Requires -Version 5.1
<#
  Sirve Flutter Web con el dispositivo "web-server" (NO abre navegador).
  Lee variables de app\.env.dev y las pasa como --dart-define.
#>
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$AppDir   = Join-Path $RepoRoot "app"
$EnvPath  = Join-Path $AppDir ".env.dev"

if (-not (Test-Path $EnvPath)) {
  Write-Error "Env file not found: $EnvPath"
  exit 1
}

# Parse .env.dev
$envMap = @{}
Get-Content -Path $EnvPath | ForEach-Object {
  $line = $_.Trim()
  if ([string]::IsNullOrWhiteSpace($line)) { return }
  if ($line.StartsWith("#")) { return }
  $eq = $line.IndexOf("=")
  if ($eq -lt 1) { return }
  $k = $line.Substring(0, $eq).Trim()
  $v = $line.Substring($eq + 1).Trim()
  $envMap[$k] = $v
}

# Defaults
if (-not $envMap.ContainsKey("WEB_HOST")) { $envMap["WEB_HOST"] = "0.0.0.0" }
if (-not $envMap.ContainsKey("WEB_PORT")) { $envMap["WEB_PORT"] = "5275" }
if (-not $envMap.ContainsKey("API_HTTP")) { $envMap["API_HTTP"] = "http://192.168.1.146:5274" }
if (-not $envMap.ContainsKey("API_WS"))   { $envMap["API_WS"]   = "ws://192.168.1.146:5274" }

# Export a env del proceso (por si la app los lee vía Platform.environment)
$env:API_HTTP = $envMap["API_HTTP"]
$env:API_WS   = $envMap["API_WS"]

# Define flags para Flutter
$defines = @(
  "--dart-define=API_HTTP=$($envMap["API_HTTP"])",
  "--dart-define=API_WS=$($envMap["API_WS"])"
)

Push-Location $AppDir
try {
  Write-Host "==> flutter pub get"
  flutter pub get | Write-Host

  $webHost = $envMap["WEB_HOST"]
  $webPort = $envMap["WEB_PORT"]

  Write-Host "==> Serving Flutter Web (web-server) at http://$webHost`:$webPort/"
  Write-Host "    API_HTTP: $($envMap["API_HTTP"])"
  Write-Host "    API_WS  : $($envMap["API_WS"])"

  # Dispositivo: web-server (no abre navegador)
  flutter run -d web-server `
    --web-hostname $webHost `
    --web-port $webPort `
    @defines
}
finally {
  Pop-Location
}
