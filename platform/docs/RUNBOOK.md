
### `docs/RUNBOOK.md`

```md
# Runbook – Operaciones día a día (DEV local)

## A. Prerrequisitos (una vez)
1) **Docker Desktop** abierto.
2) **Caddy** descomprimido en `C:\tools\caddy\caddy_windows_amd64.exe`.
3) **Mosquitto (Windows)** instalado como servicio, con:
   - `listener 1883 0.0.0.0`
   - `allow_anonymous false`
   - `password_file C:\Program Files\mosquitto\passwords`
   - Regla firewall **entrada TCP 1883**.
   - Iniciado en "C:\Program Files\mosquitto>" con comando: .\mosquitto.exe -c mosquitto.conf -v
4) Firewall con reglas de entrada:
   - TCP 3001 (HTTP/WS) (Caddy)
   - TCP 1883 (MQTT)
   - TCP 5432 (opcional, si accedes a DB desde fuera)
5) Inicializar Caddy: C:\tools\caddy\caddy_windows_amd64.exe run --config C:\tools\caddy\Caddyfile

## B. Levantar todo (scripts)
- **DEV**: En VSC "F1" -> "Dev Containers: Rebuild Container"
- **Start**: `.\scripts\start-dev.ps1`
- **Stop**:  `.\scripts\stop-dev.ps1`

## C. Correr web server
- En carpeta "" correr comando: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5274 --dart-define=API_BASE_URL=http://192.168.1.146:3001 --dart-define=WS_URL=ws://192.168.1.146:3001/ws

## D. Verificar status
- En Docker Desktop: Containers 'dev', 'ingest', 'db, 'api' corriendo
- En Powershell 'mosquitto', 'caddy', 'web server fluuter' corriendo
- http://192.168.1.146:3001/health funciona
- http://192.168.1.146:5274/ funciona

## E. Comandos manuales útiles
### C.1 Infra containers
```powershell
cd \\wsl$\Ubuntu-22.04\home\joemurray\code\iot-platform
docker compose -f .\infra\docker-compose.dev.yml up -d db ingest api
docker compose -f .\infra\docker-compose.dev.yml ps
docker logs --tail=100 -f infra-api-1
docker logs --tail=100 -f infra-ingest-1

### C.2 Health checks útiles
# API local (loopback)
curl http://127.0.0.1:3000/health
# API por Caddy (LAN)
curl http://X.X.X.X:3001/health
# DB (desde contenedor)
docker exec -it infra-db-1 psql -U postgres -d iot -c "select 1;"
# MQTT: escuchar lo que publica el ESP32 (en broker Windows usa cualquier cliente MQTT)
# En broker container (si lo usas):
docker exec -it infra-mosquitto-1 sh -lc 'apk add --no-cache mosquitto-clients >/dev/null 2>&1; mosquitto_sub -h 127.0.0.1 -t "#" -v -C 3 -W 5'

### C.3 Consultas a Postgres
docker exec -it infra-db-1 psql -U postgres -d iot
\dt
\d telemetry
SELECT COUNT(*) FROM telemetry;
SELECT device_id, ts, payload FROM telemetry ORDER BY ts DESC LIMIT 10;
\q
