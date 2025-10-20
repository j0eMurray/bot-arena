// platform/services/ingest/src/index.ts
// Servicio "ingest": se conecta a MQTT y guarda mensajes en Postgres.

import mqtt, { MqttClient } from "mqtt";
import { Client } from "pg";

const {
  DATABASE_URL = "postgres://postgres:postgres@db:5432/iot",
  MQTT_URL = "mqtt://host.docker.internal:1883",
  LOG_LEVEL = "info",
} = process.env;

function log(...args: unknown[]) {
  console.log("[ingest]", ...args);
}

const maskConn = (s: string): string => s.replace(/:\/\/.*@/, "://***:***@");

async function main(): Promise<void> {
  log("starting ingest…");
  log("DATABASE_URL:", maskConn(DATABASE_URL));
  log("MQTT_URL:", maskConn(MQTT_URL));

  // Postgres
  const pg = new Client({ connectionString: DATABASE_URL });
  await pg.connect();
  log("pg connected");

  // MQTT
  const client: MqttClient = mqtt.connect(MQTT_URL, {
    reconnectPeriod: 2000,
    protocolVersion: 4,
    connectTimeout: 10_000,
  });

  client.on("connect", () => {
    log("mqtt connected");
    const topic = "botarena/dev/+/up";
    client.subscribe(topic, { qos: 0 }, (err: Error | null, granted?: mqtt.ISubscriptionGrant[]) => {
      if (err) { console.error("subscribe error:", err.message); return; }
      log("subscribed:", granted?.map(g => `${g.topic}@${g.qos}`).join(", ") ?? topic);
    });
  });

  client.on("reconnect", () => log("mqtt reconnecting…"));
  client.on("error", (err) => {
    console.error("mqtt error:", err?.message ?? String(err));
  });
  client.on("close", () => log("mqtt connection closed"));

  client.on("message", async (topic: string, message: Buffer) => {
    try {
      // topic: botarena/dev/<device_id>/up
      const parts = topic.split("/");
      const deviceId = parts.length >= 4 ? parts[2] : "unknown";

      // payload: JSON o raw string si no es JSON válido
      const raw = message.toString("utf-8");
      let payload: unknown;
      try {
        payload = JSON.parse(raw) as unknown;
      } catch {
        payload = { raw };
      }

      await pg.query(
        `INSERT INTO telemetry (device_id, topic, payload)
         VALUES ($1, $2, $3)`,
        [deviceId, topic, payload]
      );

      if (LOG_LEVEL === "debug") {
        log("stored", { deviceId, topic, payload });
      }
    } catch (e: unknown) {
      const err = e instanceof Error ? e.message : String(e);
      console.error("ingest store error:", err);
    }
  });

  // shutdown limpio
  const shutdown = async (): Promise<void> => {
    try {
      client.end(true);
      await pg.end();
    } finally {
      process.exit(0);
    }
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((e: unknown) => {
  const err = e instanceof Error ? e.message : String(e);
  console.error("fatal ingest error:", err);
  process.exit(1);
});
