# Parada dev

# 1) Matar Caddy (si corre)
#Get-Process | Where-Object { $_.Path -like "C:\tools\caddy\caddy_windows_amd64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 2) Bajamos containers principales
cd \\wsl$\Ubuntu-22.04\home\joemurray\code\iot-platform
docker compose -f .\infra\docker-compose.dev.yml stop api ingest
docker compose -f .\infra\docker-compose.dev.yml stop db
# (Opcional) docker compose down si quieres borrar network
