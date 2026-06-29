#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

hostnamectl set-hostname ${hostname}

apt-get update
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# SQL Server 2019 Express in Docker (~2-4 min to ready vs 20-40 min for RDS).
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

echo "voting-db bootstrap complete" > /var/log/voting-db-bootstrap.log
