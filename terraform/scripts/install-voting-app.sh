#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

hostnamectl set-hostname ${hostname}

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
apt-get -y install apt-transport-https
apt-get -y update
apt-get -y install apache2 dotnet-sdk-2.2 unzip

unzip -o -d /var/www/votingdata votingdata.zip

sed -i "s/%SQLSERVER%.database.windows.net/${sqlServer}/g" /var/www/votingdata/appsettings.json
sed -i "s/msqldb_votingapp/tempdb/g" /var/www/votingdata/appsettings.json
sed -i "s/TrustServerCertificate=False/TrustServerCertificate=True/g" /var/www/votingdata/appsettings.json
sed -i "s/%USERNAME%/${username}/g" /var/www/votingdata/appsettings.json
sed -i "s/%PASSWORD%/${password}/g" /var/www/votingdata/appsettings.json
sed -i "s/openssl_conf = openssl_init/#openssl_conf = openssl_init/g" /etc/ssl/openssl.cnf

chown -R www-data:www-data /var/www/votingdata

a2enmod headers proxy_html proxy_http
a2dissite 000-default || true

cp votingdata.conf /etc/apache2/sites-available/
a2ensite votingdata

cp votingdata.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable votingdata.service
systemctl start votingdata.service
systemctl restart apache2

echo "voting-app bootstrap complete" > /var/log/voting-app-bootstrap.log
