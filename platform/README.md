# IoT Platform (DEV)

Stack local con:
- **API** Fastify (HTTP + WS) → consultas y streaming.
- **Ingest** (worker) → suscribe a MQTT y persiste en Postgres.
- **DB** PostgreSQL.
- **Broker MQTT**: en DEV usamos **Mosquitto nativo en Windows** (service).
- **Caddy (DEV)**: reverse proxy HTTP/WS en Windows → expone `:3001` a la LAN.

## Arranque rápido
- Ver **docs/RUNBOOK.md** (start/stop en un clic con PowerShell).
- Arquitectura visual: **docs/ARCHITECTURE.md**.

Repos relacionados:
- App Flutter: `iot-app`
- Dispositivo ESP32: `iot-device` (proyecto `iot-device-v1`)
