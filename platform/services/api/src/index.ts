/* eslint-disable @typescript-eslint/no-unused-vars */
import Fastify, { FastifyInstance, FastifyRequest } from "fastify";
import websocket from "@fastify/websocket";
import cors from "@fastify/cors";

// ===== Config =====
const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? "0.0.0.0";

// ===== App =====
const app: FastifyInstance = Fastify({
  logger: true,
});

// CORS abierto para desarrollo en LAN
await app.register(cors, {
  origin: true,
  credentials: false,
});

// WebSocket plugin
await app.register(websocket);

// ===== Rutas HTTP básicas =====
app.get("/", async () => {
  return { ok: true, service: "api" };
});

app.get("/health", async () => {
  return { ok: true, status: "healthy" };
});

// (Opcional) evitar 404 de favicon en dev
app.get("/favicon.ico", async (_req, reply) => {
  reply.code(204).send();
});

// ===== Utilidades WS (sin any) =====
type WSOn = {
  (event: "close", cb: (code: number, reason: unknown) => void): void;
  (event: "error", cb: (err: unknown) => void): void;
  (event: "message", cb: (data: unknown, isBinary?: boolean) => void): void;
};
type WSLike = {
  readyState: number;
  send: (data: string | ArrayBufferLike | ArrayBufferView) => void;
  on: WSOn;
};
const WS_OPEN = 1 as const;

function isWS(obj: unknown): obj is WSLike {
  return (
    !!obj &&
    typeof obj === "object" &&
    typeof (obj as WSLike).on === "function" &&
    typeof (obj as WSLike).send === "function" &&
    typeof (obj as WSLike).readyState === "number"
  );
}

/**
 * Los handlers de @fastify/websocket pueden recibir:
 *  - v10: el WebSocket directo
 *  - v9/v10: un SocketStream con { socket: WebSocket }
 */
function pickSocket(connection: unknown): WSLike | null {
  if (isWS(connection)) return connection;
  if (connection && typeof connection === "object" && "socket" in connection) {
    const s = (connection as { socket?: unknown }).socket;
    if (isWS(s)) return s;
  }
  return null;
}

function safeSend(ws: WSLike | null, data: string) {
  try {
    if (ws && ws.readyState === WS_OPEN) ws.send(data);
  } catch {
    // noop
  }
}

// ===== Handlers WS =====

// /ws-test → heartbeat cada 1s (sin DB)
app.get(
  "/ws-test",
  { websocket: true },
  (connection: unknown, _req: FastifyRequest) => {
    const socket = pickSocket(connection);
    if (!socket) return; // si no hubo upgrade, salgo sin romper

    const timer = setInterval(() => {
      safeSend(
        socket,
        JSON.stringify({ kind: "heartbeat", t: Date.now() }),
      );
    }, 1000);

    socket.on("close", () => clearInterval(timer));
    socket.on("error", () => clearInterval(timer));
  },
);

// /ws → tick “demo” cada 2s (sin DB por ahora)
app.get("/ws", { websocket: true }, (connection: unknown, _req: FastifyRequest) => {
  const socket = pickSocket(connection);
  if (!socket) return;

  safeSend(socket, JSON.stringify({ kind: "welcome", msg: "ws connected" }));

  const timer = setInterval(() => {
    const payload = {
      kind: "tick",
      now: new Date().toISOString(),
      note: "demo stream",
    };
    safeSend(socket, JSON.stringify(payload));
  }, 2000);

  socket.on("close", () => clearInterval(timer));
  socket.on("error", () => clearInterval(timer));
});

// ===== Start =====
app.ready().then(() => {
  app.log.info(`API routes ready`);
});

try {
  await app.listen({ host: HOST, port: PORT });
  app.log.info(`API on :${PORT}`);
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
