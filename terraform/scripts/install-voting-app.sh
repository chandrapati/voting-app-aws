#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > /var/log/voting-app-install.log 2>&1

hostnamectl set-hostname ${hostname}

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

apt_update_with_retry() {
  local retries=10 pause=20
  for i in $(seq 1 "$retries"); do
    if apt-get update -y; then return 0; fi
    sleep "$pause"
  done
  return 1
}

echo "Waiting for SQL Server at ${sql_host}:1433..."
for i in $(seq 1 90); do
  if timeout 2 bash -c "echo >/dev/tcp/${sql_host}/1433" 2>/dev/null; then
    echo "SQL Server port is open"
    break
  fi
  sleep 10
done

cd /tmp

wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingdata.conf
wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingdata.service
wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingdata.zip

wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/i/icu/libicu60_60.2-3ubuntu3_amd64.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/u/ust/liblttng-ust0_2.11.0-1_amd64.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/libu/liburcu/liburcu6_0.11.1-2_amd64.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/u/ust/liblttng-ust-ctl4_2.11.0-1_amd64.deb

dpkg -i packages-microsoft-prod.deb
dpkg -i libicu60_60.2-3ubuntu3_amd64.deb
dpkg -i liburcu6_0.11.1-2_amd64.deb
dpkg -i liblttng-ust-ctl4_2.11.0-1_amd64.deb
dpkg -i liblttng-ust0_2.11.0-1_amd64.deb
dpkg -i libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb

add-apt-repository -y universe
apt_update_with_retry
apt-get -y install apt-transport-https
apt-get -y install apache2 dotnet-sdk-2.2 aspnetcore-runtime-2.2 unzip

unzip -o -d /var/www/votingdata votingdata.zip

# Write connection string directly — avoids sed breakage on special characters in password.
cat > /var/www/votingdata/appsettings.json << EOF
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "SqlDbConnection": "Server=tcp:${sqlServer},1433;Initial Catalog=votingapp;Persist Security Info=False;User ID=${username};Password=${password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  }
}
EOF

sed -i "s/openssl_conf = openssl_init/#openssl_conf = openssl_init/g" /etc/ssl/openssl.cnf

chown -R www-data:www-data /var/www/votingdata

a2enmod headers proxy_html proxy_http
a2dissite 000-default || true

cp votingdata.conf /etc/apache2/sites-available/
a2ensite votingdata

cp votingdata.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable votingdata.service
systemctl restart votingdata.service
systemctl restart apache2

# Wait for API to respond before marking bootstrap complete.
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:5001/api/Votes >/dev/null 2>&1; then
    echo "VotingData API healthy"
    break
  fi
  sleep 5
done

echo "voting-app bootstrap complete" > /var/log/voting-app-bootstrap.log
