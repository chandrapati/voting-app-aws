#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > /var/log/voting-web-install.log 2>&1

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

cd /tmp

wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingweb.conf
wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingweb-ssl.conf
wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingweb.service
wget -q https://raw.githubusercontent.com/wajihalsaid/Voting_app/main/votingweb.zip

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

unzip -o -d /var/www/votingweb votingweb.zip
chown -R www-data:www-data /var/www/votingweb

if [ -f /var/www/votingweb/appsettings.json ]; then
  sed -i "s|http://localhost:5001|http://${app_host}|g" /var/www/votingweb/appsettings.json || true
  sed -i "s|https://localhost:5001|http://${app_host}|g" /var/www/votingweb/appsettings.json || true
fi

a2enmod headers proxy_html proxy_http ssl
a2dissite 000-default || true

cp votingweb.conf /etc/apache2/sites-available/
cp votingweb-ssl.conf /etc/apache2/sites-available/
a2ensite votingweb
a2ensite votingweb-ssl

cp votingweb.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable votingweb.service
systemctl start votingweb.service
systemctl restart apache2

echo "voting-web bootstrap complete" > /var/log/voting-web-bootstrap.log
