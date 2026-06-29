# Voting App on AWS (Terraform)

Deploy a **3-tier voting demo app** to AWS in ~5 minutes of Terraform time (vs 20–40 minutes with RDS SQL Server). Designed for lab/POV use — especially east-west segmentation demos with Cisco Secure Workload.

## Architecture

```
                    Internet
                        |
                 [ voting-web ]  :80/:443   (Ubuntu + Apache + .NET 2.2 UI)
                        |
              ec2.internal DNS
                        |
                 [ voting-app ]  :80         (Ubuntu + Apache + .NET 2.2 API)
                        |
                   SQL :1433
                        |
                 [ voting-db  ]               (Ubuntu + SQL Server 2019 in Docker)
```

| Tier | Hostname | Subnet | Instance |
|------|----------|--------|----------|
| Web | `voting-web01` | `192.168.1.0/24` (public) | `t3.micro` |
| App | `voting-app01` | `192.168.101.0/24` (public) | `t3.micro` |
| DB | `voting-db01` | `192.168.201.0/24` (private) | `t3.small` |

Application binaries come from [wajihalsaid/Voting_app](https://github.com/wajihalsaid/Voting_app).

### Why this design is faster

| Old (RDS) | New (Docker on EC2) |
|-----------|---------------------|
| RDS SQL Server: 20–40 min | Docker SQL Server: 3–5 min |
| EC2 blocked until RDS ready | All 3 EC2 launch **in parallel** |
| RDS cost while idle | EC2-only; destroy when done |

---

## Prerequisites

- **AWS CLI** configured (`aws sts get-caller-identity` works)
- **Terraform** >= 1.3
- **SSH key** (generated once — see below)
- Outbound internet from EC2 (package downloads)

---

## Quick start

### 1. Generate SSH key (first time only)

```bash
cd terraform
ssh-keygen -t rsa -b 4096 -f voting-app-key -N "" -C "voting-app-deploy"
```

### 2. Configure (optional)

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit region, instance types, or AWS profile if needed
```

### 3. Deploy

```bash
terraform init
terraform apply
```

Terraform finishes in **~3–5 minutes**. Application bootstrap (user-data) takes **~8–12 minutes** after that.

### 4. Get URLs

```bash
terraform output voting_web_url_http
# e.g. http://54.x.x.x
```

Open that URL in a browser and vote for a candidate.

### 5. Smoke test

```bash
../scripts/test-voting-app.sh
```

---

## Test the app manually

1. Open `terraform output -raw voting_web_url_http`
2. You should see a voting UI with candidate options
3. Submit a vote — the app tier writes to SQL Server on the db host
4. Refresh — vote counts should update

HTTPS works with a self-signed cert: `terraform output voting_web_url_https` (browser will warn).

---

## Tear down

```bash
cd terraform
terraform destroy
```

Destroys all resources in ~2–3 minutes. No orphan RDS to clean up.

---

## Troubleshooting

### Terraform apply is slow

| Symptom | Cause | Fix |
|---------|-------|-----|
| Stuck >10 min on one resource | Unusual for this design | `Ctrl+C`, then `terraform apply` again |
| Old RDS design | Previous version used RDS | Use this repo version (Docker DB) |

### App URL returns connection refused / timeout

Bootstrap is still running. Wait 8–12 minutes after `terraform apply` completes.

```bash
../scripts/test-voting-app.sh   # polls up to 15 min
```

### Check bootstrap on web tier

```bash
ssh -i terraform/voting-app-key ubuntu@$(cd terraform && terraform output -raw voting_web_public_ip)
sudo tail -100 /var/log/cloud-init-output.log
sudo systemctl status votingweb apache2
curl -s localhost:5000 | head
```

### Check API tier

```bash
ssh -i terraform/voting-app-key ubuntu@$(cd terraform && terraform output -raw voting_app_public_ip)
sudo tail -100 /var/log/cloud-init-output.log
sudo systemctl status votingdata apache2
cat /var/www/votingdata/appsettings.json
```

### Check database tier

DB has **no public IP**. SSH via app host:

```bash
APP_IP=$(cd terraform && terraform output -raw voting_app_public_ip)
ssh -i terraform/voting-app-key -J ubuntu@$APP_IP ubuntu@voting-db01.ec2.internal
# or use private IP:
# ssh -i terraform/voting-app-key -J ubuntu@$APP_IP ubuntu@$(cd terraform && terraform output -raw voting_db_private_ip)

sudo docker ps
sudo docker logs sqlserver
cat /var/log/voting-db-bootstrap.log
```

### SQL connection errors on app tier

- App waits up to **15 min** for `voting-db01.ec2.internal:1433`
- Verify Route53 private zone: `dig voting-db01.ec2.internal` from app host
- Verify security group allows 1433 from app subnet (`192.168.101.0/24`)

### Security group / can't SSH or browse

Your public IP is auto-detected at apply time. If your IP changed:

```bash
terraform apply   # refreshes SG rules from ifconfig.me
```

### .NET / package install failures

User-data installs legacy .NET Core 2.2 on Ubuntu 22.04 with compatibility packages. If mirrors fail:

```bash
sudo tail -200 /var/log/cloud-init-output.log
```

Re-run apply to recreate instances: `terraform taint 'aws_instance.voting["voting-web"]' && terraform apply`

### Get SQL SA password

```bash
cd terraform && terraform output -raw sql_password
```

---

## Outputs reference

| Output | Description |
|--------|-------------|
| `voting_web_url_http` | Main UI URL |
| `voting_web_public_ip` | Web tier public IP |
| `voting_app_public_ip` | API tier public IP |
| `voting_db_private_ip` | DB private IP |
| `sql_password` | SQL Server `sa` password (sensitive) |
| `ssh_web` / `ssh_app` | SSH commands |

---

## Cost note

Approximate on-demand cost while running (us-east-1): ~$0.05–0.08/hr (`t3.micro` × 2 + `t3.small` × 1). **Run `terraform destroy` when finished.**

---

## Repository layout

```
voting-app-aws/
├── README.md
├── scripts/
│   └── test-voting-app.sh      # Post-deploy smoke test
└── terraform/
    ├── main.tf
    ├── network.tf
    ├── security_groups.tf
    ├── ec2.tf
    ├── dns.tf
    ├── secrets.tf
    ├── scripts/
    │   ├── install-voting-db.sh
    │   ├── install-voting-app.sh
    │   └── install-voting-web.sh
    └── terraform.tfvars.example
```

---

## License

Terraform code: use freely. Application assets: see upstream [Voting_app](https://github.com/wajihalsaid/Voting_app) repo.
