// platform/services/api/src/index.ts
// Fastify HTTP + WS con endpoints base + /telemetry (consulta reciente)

import Fastify from "fastify";
import fastifyCors from "@fastify/cors";
import { WebSocketServer, WebSocket } from "ws";
import { Client } from "pg";

const {
  FASTIFY_ADDRESS = "0.0.0.0",
  PORT = "3000",
  DATABASE_URL = "postgres://postgres:postgres@db:5432/iot",
  LOG_LEVEL = "info",
} = process.env;

const app = Fastify({
  logger: LOG_LEVEL === "debug" ? { level: "debug" } : false,
});

app.register(fastifyCors, { origin: true });

const pg = new Client({ connectionString: DATABASE_URL });

const clamp = (n: number, min: number, max: number) =>
  Math.max(min, Math.min(max, n));

// --- HTTP base ---
app.get("/", async () => ({ ok: true, service: "api" }));

app.get("/health", async () => {
  try {
    await pg.query("SELECT 1");
    return { ok: true, db: "up" };
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    return { ok: false, db: "down", error: message };
  }
});

// --- Telemetry: recientes ---
app.get<{
  Querystring: { limit?: string; offset?: string; device_id?: string };
}>("/telemetry", async (req) => {
  const rawLimit = Number(req.query.limit);
  const limit = Number.isFinite(rawLimit) ? clamp(rawLimit, 1, 500) : 50;

  const rawOffset = Number(req.query.offset);
  const offset = Number.isFinite(rawOffset) ? Math.max(0, Math.floor(rawOffset)) : 0;

  const deviceId = req.query.device_id;

  const params: string[] = [];
  let where = "";
  if (deviceId) {
    where = "WHERE device_id = $1";
    params.push(deviceId);
  }

  const sql = `
    SELECT id::text AS id, ts, device_id, topic, payload
    FROM telemetry
    ${where}
    ORDER BY ts DESC
    LIMIT ${limit}
    OFFSET ${offset}
  `;
  const res = await pg.query(sql, params);
  return { ok: true, count: res.rowCount, data: res.rows };
});

// --- WS demo /ws y /ws-test (latidos) ---
const server = app.server;
const wss = new WebSocketServer({ noServer: true });
const wssTest = new WebSocketServer({ noServer: true });

let tickTimer: NodeJS.Timeout | null = null;
function startTicks(): void {
  if (tickTimer) return;
  tickTimer = setInterval(() => {
    if (wss.clients.size === 0) return;
    const msg = JSON.stringify({ t: Date.now(), type: "tick" });
    wss.clients.forEach((c: WebSocket) => {
      if (c.readyState === WebSocket.OPEN) c.send(msg);
    });
  }, 2000);
}

function maybeStopTicks(): void {
  if (wss.clients.size === 0 && tickTimer) {
    clearInterval(tickTimer);
    tickTimer = null;
  }
}

server.on("upgrade", (request, socket, head) => {
  const url = request.url || "/";
  const pathname = new URL(url, "http://localhost").pathname;

  if (pathname === "/ws") {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit("connection", ws, request);
    });
  } else if (pathname === "/ws-test") {
    wssTest.handleUpgrade(request, socket, head, (ws) => {
      wssTest.emit("connection", ws, request);
    });
  } else {
    socket.destroy();
  }
});

wss.on("connection", (ws: WebSocket) => {
  ws.send(JSON.stringify({ hello: "welcome", service: "api", at: Date.now() }));
  startTicks();
  ws.on("close", maybeStopTicks);
  ws.on("error", maybeStopTicks);
});

wssTest.on("connection", (ws: WebSocket) => {
  const timer = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) ws.send(`heartbeat ${Date.now()}`);
  }, 1000);
  const cleanup = () => clearInterval(timer);
  ws.on("close", cleanup);
  ws.on("error", cleanup);
});

// --- start ---
async function start(): Promise<void> {
  await pg.connect();
  await app.listen({ host: FASTIFY_ADDRESS, port: parseInt(PORT, 10) });
  console.log(`[api] listening on ${FASTIFY_ADDRESS}:${PORT}`);
}
start().catch((e: unknown) => {
  const message = e instanceof Error ? e.message : String(e);
  console.error("api failed:", message);
  process.exit(1);
});
