# Arranque dev "one-liner"

# 1) Docker Desktop abierto
# (Opcional) Start-Service com.docker.service

# 2) Infra containers
cd \\wsl$\Ubuntu-22.04\home\joemurray\code\iot-platform
docker compose -f .\infra\docker-compose.dev.yml up -d db ingest api

# 3) Esperar API lista (loop simple)
$ok = $false
for ($i=0; $i -lt 12; $i++) {
  try {
    $r = Invoke-WebRequest -Uri http://127.0.0.1:3001/health -TimeoutSec 3 -UseBasicParsing
    if ($r.StatusCode -eq 200) { $ok = $true; break }
  } catch {}
  Start-Sleep -Seconds 2
}
if (-not $ok) { Write-Warning "API no respondió /health en localhost:3000, sigo de todas formas..." }

# 4) Lanzar Caddy proxy (HTTP/WS :3001) en otra ventana
#Start-Process -NoNewWindow -FilePath "C:\tools\caddy\caddy_windows_amd64.exe" -ArgumentList @(
#  "reverse-proxy","--from",":3001","--to","127.0.0.1:3000"
#)

Write-Host "DONE: api+db+ingest containers + Caddy listening :3001"
Write-Host "Prueba: curl http://192.168.1.146:3001/health"
