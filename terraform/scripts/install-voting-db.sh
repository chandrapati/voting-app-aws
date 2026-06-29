#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > /var/log/voting-db-install.log 2>&1

hostnamectl set-hostname ${hostname}

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

apt_update_with_retry() {
  local retries=10 pause=20
  for i in $(seq 1 "$retries"); do
    echo "apt-get update attempt $i/$retries..."
    if apt-get update -y; then
      return 0
    fi
    sleep "$pause"
  done
  return 1
}

wait_for_internet() {
  echo "Waiting for outbound internet (NAT)..."
  for i in $(seq 1 30); do
    if curl -sf --max-time 8 http://checkip.amazonaws.com >/dev/null 2>&1; then
      echo "Outbound internet ready"
      return 0
    fi
    sleep 10
  done
  echo "WARNING: internet check timed out; continuing anyway"
}

wait_for_internet
apt_update_with_retry

# Prefer Docker CE install script (more reliable than docker.io on first boot).
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker
systemctl start docker

docker rm -f sqlserver 2>/dev/null || true

docker run \
  -e "ACCEPT_EULA=Y" \
  -e "MSSQL_SA_PASSWORD=${password}" \
  -p 1433:1433 \
  --name sqlserver \
  --restart unless-stopped \
  -d mcr.microsoft.com/mssql/server:2019-latest

ready=0
for i in $(seq 1 60); do
  if docker logs sqlserver 2>&1 | grep -q "SQL Server is now ready for client connections"; then
    ready=1
    break
  fi
  sleep 5
done

if [[ "$ready" -ne 1 ]]; then
  echo "SQL Server did not become ready in time" >&2
  docker logs sqlserver >&2 || true
  exit 1
fi

# Create application database (do not use tempdb).
for sqlcmd in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
  if docker exec sqlserver test -x "$sqlcmd" 2>/dev/null; then
    docker exec sqlserver "$sqlcmd" -S localhost -U sa -P "${password}" -C -Q \
      "IF DB_ID('votingapp') IS NULL CREATE DATABASE votingapp;" && break
  fi
done

echo "voting-db bootstrap complete" > /var/log/voting-db-bootstrap.log
