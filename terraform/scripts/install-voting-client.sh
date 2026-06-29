#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > /var/log/voting-client-install.log 2>&1

hostnamectl set-hostname ${hostname}

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

apt-get update
apt-get install -y curl netcat-openbsd

echo "Waiting for web tier ${web_host} (${web_private_ip}:80)..."
for i in $(seq 1 60); do
  if timeout 3 bash -c "echo >/dev/tcp/${web_private_ip}/80" 2>/dev/null; then
    echo "Web tier port 80 is open"
    break
  fi
  sleep 15
done

echo "Waiting 60s for app stack to stabilise..."
sleep 60

echo '${traffic_gen_b64}' | base64 -d > /usr/local/sbin/voting_client_generate_traffic.sh
chmod +x /usr/local/sbin/voting_client_generate_traffic.sh

bash /usr/local/sbin/voting_client_generate_traffic.sh "${web_host}" "${app_host}"

echo "voting-client bootstrap complete" > /var/log/voting-client-bootstrap.log
