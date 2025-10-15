# Arquitectura – DEV local (Hybrid Edge)

```mermaid
flowchart LR
  subgraph Windows Host
    Caddy[Caddy (HTTP/WS) :3001]
    Mosq[ Mosquitto (TCP) :1883 ]
    VSCode[VS Code + DevContainer UX]
  end

  subgraph Docker/WSL Network
    API[API Fastify :3000]
    ING[Ingest Worker]
    DB[(PostgreSQL)]
  end

  subgraph LAN
    ESP32[ESP32-WROOM-32D]
    Phone[Flutter App/Web]
    PCBrowser[Navegador PC]
  end

  Caddy ---|proxy http/ws| API
  Mosq ---|listener tcp| ESP32
  ESP32 -->|mqtt :1883| Mosq
  Phone -->|http/ws :3001| Caddy
  PCBrowser -->|http/ws :3001| Caddy
  ING -->|mqtt subscribe| Mosq
  ING -->|sql insert| DB
  API -->|sql read| DB
