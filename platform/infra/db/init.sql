-- platform/infra/db/init.sql
-- Esquema mínimo para almacenar telemetría publicada por dispositivos

-- Telemetry base
CREATE TABLE IF NOT EXISTS telemetry (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ DEFAULT now(),
  device_id TEXT,
  topic TEXT,
  payload JSONB
);

-- Índices útiles
CREATE INDEX IF NOT EXISTS idx_telemetry_ts_desc ON telemetry (ts DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_device_ts ON telemetry (device_id, ts DESC);
