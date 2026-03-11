# prometheus-influxdb-telegraf

Ubuntu-focused observability starter where:

- Telegraf collects node + Docker metrics.
- InfluxDB stores the metrics.
- Grafana runs on a remote system and connects to this InfluxDB.

Note: Project name includes `prometheus` for naming consistency, but this implementation is `Telegraf -> InfluxDB -> Remote Grafana`.

## 1. Overall Architecture

`Ubuntu host + Docker Engine -> Telegraf (Docker) -> InfluxDB v2 -> Remote Grafana`

## 2. Overall Installation First (Step by Step)

### 2.1 Prerequisites on Ubuntu

1. Install Docker Engine and Docker Compose plugin.
2. Ensure ports are reachable:
   - `8086/tcp` from your remote Grafana system to this Ubuntu host.
3. Minimum host sizing: 2 vCPU, 4 GB RAM.
4. Verify Docker is healthy:

```bash
docker --version
docker compose version
docker info >/dev/null && echo "docker ok"
```

### 2.2 Clone and Prepare Environment

```bash
cd /path/to/your/workspace/prometheus-influxdb-telegraf
cp .env.example .env
```

Edit `.env` and set strong values:

- `INFLUXDB_INIT_USERNAME`
- `INFLUXDB_INIT_PASSWORD`
- `INFLUXDB_INIT_ADMIN_TOKEN`
- `INFLUXDB_INIT_ORG`
- `INFLUXDB_INIT_BUCKET`

### 2.3 Start InfluxDB + Telegraf

```bash
docker compose up -d
```

### 2.4 Ubuntu Health Checks

```bash
chmod +x scripts/healthcheck.sh
set -a && source .env && set +a
./scripts/healthcheck.sh
```

Manual checks:

```bash
curl -fsS http://localhost:8086/health
docker compose logs --tail=50 telegraf
```

### 2.5 Allow Remote Grafana to Reach InfluxDB

Open firewall only for your Grafana host IP (example with UFW):

```bash
sudo ufw allow from <GRAFANA_SERVER_IP> to any port 8086 proto tcp
sudo ufw status
```

## 3. Component-Wise Guide

### 3.1 Docker (Runtime Layer)

Purpose:

- Runs InfluxDB and Telegraf containers.
- Exposes Docker API to Telegraf for container metrics.

Main file:

- `docker-compose.yml`

Important mounts used by Telegraf:

- `/var/run/docker.sock` for Docker metrics.
- `/proc`, `/sys`, `/etc`, `/` for host metrics from inside container.

### 3.2 InfluxDB (Metrics Storage)

Purpose:

- Stores all time-series metrics.

Key config source:

- `.env` values injected via `docker-compose.yml`.

Auto-bootstrap variables:

- `INFLUXDB_INIT_ORG`
- `INFLUXDB_INIT_BUCKET`
- `INFLUXDB_INIT_ADMIN_TOKEN`
- `INFLUXDB_INIT_RETENTION`

Health checks:

```bash
curl -fsS http://localhost:8086/health
docker compose logs --tail=50 influxdb
```

### 3.3 Telegraf (Collector)

Purpose:

- Collects host metrics (`cpu`, `mem`, `disk`, `diskio`, `net`, `system`, `processes`).
- Collects Docker metrics (`inputs.docker`).
- Writes to InfluxDB using `outputs.influxdb_v2`.

Configuration file:

- `telegraf/telegraf.conf`

Health checks:

```bash
docker compose logs --tail=100 telegraf
docker exec influxdb2 influx query \
  --host http://localhost:8086 \
  --org "$INFLUXDB_INIT_ORG" \
  --token "$INFLUXDB_INIT_ADMIN_TOKEN" \
  'from(bucket: "'"$INFLUXDB_INIT_BUCKET"'" ) |> range(start: -5m) |> limit(n: 10)'
```

### 3.4 Remote Grafana (No Docker Here)

Purpose:

- Connects from a separate system to this Ubuntu host InfluxDB and builds dashboards.

Step-by-step on remote Grafana server:

1. Open Grafana UI.
2. Go to `Connections -> Data sources -> Add data source`.
3. Select `InfluxDB`.
4. Query language: `Flux`.
5. Set URL to `http://<UBUNTU_HOST_IP>:8086`.
6. Set Organization to `.env` value `INFLUXDB_INIT_ORG`.
7. Set Token to `.env` value `INFLUXDB_INIT_ADMIN_TOKEN`.
8. Set Default Bucket to `.env` value `INFLUXDB_INIT_BUCKET`.
9. Click `Save & test`.

Dashboard bootstrap option:

- Import starter JSON from `grafana/dashboards/node-docker-overview.json` into remote Grafana.

## 4. Operations

Start/stop:

```bash
docker compose up -d
docker compose down
```

Logs:

```bash
docker compose logs -f telegraf
docker compose logs -f influxdb
```

Reset fresh state:

```bash
docker compose down -v
docker compose up -d
```

## 5. Troubleshooting

### 5.1 Telegraf cannot read Docker metrics

- Confirm Docker socket mount exists in `docker-compose.yml`.
- Confirm Docker daemon is running.
- Check permissions and logs: `docker compose logs telegraf`.

### 5.2 Remote Grafana cannot connect to InfluxDB

- Verify Ubuntu firewall allows Grafana server IP on port `8086`.
- Verify host IP/hostname in Grafana datasource URL.
- Verify token/org/bucket are correct.

### 5.3 InfluxDB setup values do not change

- InfluxDB initialization runs only on first start for a fresh volume.
- If needed, recreate volumes with `docker compose down -v`.

## 6. Security Baseline

- Keep `INFLUXDB_INIT_ADMIN_TOKEN` secret.
- Restrict `8086` to Grafana host IP, not the full internet.
- Do not commit real `.env` values.

