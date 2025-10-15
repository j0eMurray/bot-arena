import mqtt from "mqtt";
import { Client } from "pg";
import { z } from "zod";
import pino from "pino";

const log = pino({ name: "ingest", level: process.env.LOG_LEVEL || "info" });

const env = {
  MQTT_URL: process.env.MQTT_URL || "mqtt://localhost:1883",
  MQTT_USER: process.env.MQTT_USER || "iot_ingest",
  MQTT_PASS: process.env.MQTT_PASS || "changeme",
  PG_URL: process.env.PG_URL || "postgres://postgres:postgres@localhost:5432/iot",
};

const telemSchema = z
  .object({
    v: z.number().optional(),
    ts: z.union([z.number(), z.string()]).optional(),
  })
  .passthrough();

type Telemetry = z.infer<typeof telemSchema>;

// ---------- PG bootstrap ----------
const pg = new Client({ connectionString: env.PG_URL });
await pg.connect();

await pg.query(`
  CREATE TABLE IF NOT EXISTS device (
    id TEXT PRIMARY KEY,
    secret TEXT,
    name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    last_seen TIMESTAMPTZ
  );
  CREATE TABLE IF NOT EXISTS telemetry (
    device_id TEXT NOT NULL,
    ts TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL
  );
  CREATE INDEX IF NOT EXISTS telemetry_device_ts_idx ON telemetry(device_id, ts DESC);
`);

// Normaliza ts a Date (acepta number sec/ms o string ISO)
function coerceTs(val: unknown): Date {
  if (typeof val === "number" && Number.isFinite(val)) {
    const ms = val >= 1e12 ? val : Math.round(val * 1000);
    return new Date(ms);
  }
  if (typeof val === "string") {
    const d = new Date(val);
    if (!isNaN(d.valueOf())) return d;
  }
  return new Date();
}

// ---------- MQTT ----------
const client = mqtt.connect(env.MQTT_URL, {
  username: env.MQTT_USER,
  password: env.MQTT_PASS,
  clean: true,
});

client.on("connect", () => {
  log.info("MQTT connected");
  client.subscribe("devices/+/telemetry", { qos: 1 });
});

client.on("message", async (topic, buf) => {
  // DEBUG duro para ver qué llega
  const rawStr = buf.toString("utf8");
  log.debug({ topic, raw: rawStr }, "mqtt message received");

  try {
    const m = topic.match(/^devices\/([^/]+)\/telemetry$/);
    if (!m) {
      log.debug({ topic }, "topic skipped");
      return;
    }
    const deviceId = m[1];

    const s = rawStr.trim();
    let rawUnknown: unknown;

    try {
      rawUnknown = JSON.parse(s) as unknown;
    } catch (e) {
      log.warn({ topic, raw: s, err: (e as Error).message }, "discarding non-JSON payload");
      return;
    }

    const parsed = telemSchema.safeParse(rawUnknown);
    if (!parsed.success) {
      log.warn({ topic, raw: s, err: parsed.error.flatten() }, "invalid payload");
      return;
    }

    const data: Telemetry = parsed.data;
    const ts = coerceTs(data.ts);

    await pg.query(
      `INSERT INTO device(id, last_seen) VALUES ($1, now())
       ON CONFLICT (id) DO UPDATE SET last_seen = EXCLUDED.last_seen`,
      [deviceId]
    );

    await pg.query(
      "INSERT INTO telemetry(device_id, ts, payload) VALUES ($1, $2, $3)",
      [deviceId, ts, data]
    );

    log.info({ deviceId }, "telemetry stored");
  } catch (e) {
    log.error({ err: e }, "ingest error");
  }
});
