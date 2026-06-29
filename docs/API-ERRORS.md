# Voting App API Errors — Reference

This document explains HTTP errors seen on the voting app stack (UI, API, traffic generator) and how to fix them. Keep this handy for customer demos and CSW POV workshops.

## Architecture reminder

```
Browser / traffic-client
        → voting-web (port 80/443) → VotingWeb .NET → voting-app (api/Votes)
                                                      → voting-db (SQL :1433)
```

The Angular UI calls **relative** paths such as `api/Votes` on the **web** host. The web tier forwards to the app tier. The app tier reads/writes **SQL Server** on the db host.

---

## Symptom → cause → fix

| HTTP code | Where | Meaning | Root cause | Fix |
|-----------|-------|---------|------------|-----|
| **200** | `/` | UI OK | — | — |
| **200** | `/api/Votes` | API OK | App + SQL healthy | — |
| **411** | `PUT /api/Votes/...` | Length Required | PUT sent with **no body** | Use multipart form: `curl -X PUT ... -F "item=Name"` (traffic generator does this) |
| **400** | `PUT /api/Votes/...` | Bad Request | Wrong payload shape | Use `-F "item=<name>"` like the Angular client |
| **500** | `/api/Votes` (via web) | Internal Server Error | Web tier cannot reach app API, or app returned error | Check app tier (`systemctl status votingdata`); see **503** below |
| **503** | `/api/Votes` (app direct) | Service Unavailable | Apache up but **VotingData .NET crashed** or not listening on 5001 | See **VotingData crash loop** below |
| **000** | any | curl failed | Network, DNS, or host down | Check security groups and instance state |

---

## VotingData crash loop (503 / 500)

**Typical log** (`sudo journalctl -u votingdata -n 50` on app host):

```
SqlException: A network-related or instance-specific error occurred while establishing a connection to SQL Server
```

### Cause A — SQL Server never started (most common)

On the **db** host, Docker failed to install during first boot (apt could not reach the internet yet).

**Check:**

```bash
# Jump via web tier
terraform output ssh_client_via_web   # use same ProxyCommand pattern for db IP
sudo tail -50 /var/log/voting-db-install.log
sudo docker ps
nc -zv voting-db01.ec2.internal 1433
```

**Expected:** `sqlserver` container running, port 1433 open.

**Fix:** Recreate db (and app) instances so fixed user-data runs:

```bash
cd terraform
terraform taint 'aws_instance.voting["voting-db"]'
terraform taint 'aws_instance.voting["voting-app"]'
terraform apply
```

Fixed bootstrap (v2+) uses: outbound internet wait, apt retry, `get.docker.com`, creates **`votingapp`** database.

### Cause B — Wrong database name

Older installs used `Initial Catalog=tempdb`. The app expects its own database **`votingapp`**.

**Check:** `grep Catalog /var/www/votingdata/appsettings.json` on app host — should show `votingapp`.

**Fix:** Recreate app instance with current Terraform, or edit appsettings and `systemctl restart votingdata`.

### Cause C — SQL password / connection string

Passwords with special characters broke older `sed`-based install scripts.

**Fix (v2+):** appsettings.json is written via heredoc in `install-voting-app.sh` (no sed on password).

---

## Traffic generator log codes

The client runs `/usr/local/bin/voting_traffic_probe.sh` every minute.

| Log line | OK? | Notes |
|----------|-----|-------|
| `[http/web] GET / -> 200` | Yes | Web UI serving |
| `[http/web] GET api/Votes -> 200` | Yes | Full path web→app→db works |
| `[https/web] GET api/Votes -> 200` | Yes | TLS path works (self-signed; curl uses `-k`) |
| `[http/app] GET api/Votes -> 200` | Yes | East-west direct to API tier |
| `-> 500` / `-> 503` | No | App or SQL unhealthy — fix db/app first |
| `-> 411` on PUT | No | Old probe without `-F`; update traffic script from repo |

**Monitor:**

```bash
terraform output monitor_traffic_log
```

---

## Quick diagnostic script

From repo root:

```bash
chmod +x scripts/diagnose-voting-app.sh
./scripts/diagnose-voting-app.sh
```

---

## Full stack recovery

```bash
cd terraform
terraform taint 'aws_instance.voting["voting-db"]'
terraform taint 'aws_instance.voting["voting-app"]'
terraform taint 'aws_instance.voting["voting-web"]'
terraform apply
./scripts/test-voting-app.sh
./scripts/diagnose-voting-app.sh
```

Allow **~15 minutes** for bootstrap. Order of readiness: db (SQL) → app (API) → web (UI) → traffic client.

---

## Bootstrap log locations

| Tier | Install log | Success marker |
|------|-------------|----------------|
| db | `/var/log/voting-db-install.log` | `/var/log/voting-db-bootstrap.log` |
| app | `/var/log/voting-app-install.log` | `/var/log/voting-app-bootstrap.log` |
| web | `/var/log/voting-web-install.log` | `/var/log/voting-web-bootstrap.log` |
| client | `/var/log/voting-client-install.log` | `/var/log/voting-client-bootstrap.log` |

---

## Version history

| Date | Change |
|------|--------|
| 2026-06-29 | Initial doc: db Docker bootstrap failure, tempdb→votingapp, PUT 411, aspnetcore-runtime on app tier, connection string heredoc |
