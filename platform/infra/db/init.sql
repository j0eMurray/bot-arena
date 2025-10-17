create table if not exists telemetry (
  device_id text not null,
  ts        timestamptz not null default now(),
  payload   jsonb not null
);

create index if not exists idx_telemetry_ts on telemetry(ts desc);
create index if not exists idx_telemetry_device_ts on telemetry(device_id, ts desc);
