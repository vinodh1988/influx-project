$ErrorActionPreference = 'Stop'

Write-Host "Checking docker compose services..."
docker compose ps

Write-Host "\nChecking InfluxDB health endpoint..."
try {
  $influx = Invoke-RestMethod -Uri "http://localhost:8086/health" -Method Get
  $influx | ConvertTo-Json -Depth 5
} catch {
  Write-Host "InfluxDB health check failed: $($_.Exception.Message)"
}

Write-Host "\nTelegraf recent logs (last 30 lines)..."
docker compose logs --tail=30 telegraf
