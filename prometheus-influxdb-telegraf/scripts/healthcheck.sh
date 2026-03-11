#!/usr/bin/env bash
set -euo pipefail

printf "Checking docker compose services...\n"
docker compose ps

printf "\nChecking InfluxDB health endpoint...\n"
curl -fsS http://localhost:8086/health | sed 's/,/\n/g'

printf "\nChecking Telegraf recent logs (last 30 lines)...\n"
docker compose logs --tail=30 telegraf

printf "\nChecking that recent metrics are written to InfluxDB...\n"
docker exec influxdb2 influx query \
  --host http://localhost:8086 \
  --org "${INFLUXDB_INIT_ORG:-observability}" \
  --token "${INFLUXDB_INIT_ADMIN_TOKEN:?INFLUXDB_INIT_ADMIN_TOKEN is required in environment}" \
  'from(bucket: "'"${INFLUXDB_INIT_BUCKET:-telegraf_metrics}"'" ) |> range(start: -5m) |> limit(n: 5)'
