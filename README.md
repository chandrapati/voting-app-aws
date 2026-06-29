# Voting App on AWS

**Public demo repo for customer labs and POV workshops.**

Deploy a **3-tier voting application** on AWS with Terraform in about **5 minutes**. The stack is designed for segmentation and security demos (e.g., Cisco Secure Workload east-west policy testing) — web, app, and database tiers on separate subnets with distinct security groups.

| | |
|---|---|
| **Repository** | https://github.com/chandrapati/voting-app-aws |
| **Deploy time** | ~5 min (Terraform) + ~8–12 min (app bootstrap) |
| **Teardown time** | ~2–3 min |
| **Default region** | `us-east-1` |
| **Estimated cost** | ~$0.04/hr on-demand (~$1/day if left running) |

---

## What you get

A working **"What's For Lunch?"** voting UI backed by a .NET API and SQL Server database:

```
                         Internet
                             |
                      ┌──────┴──────┐
                      │ voting-web  │  HTTP/HTTPS :80/:443
                      │  t3.micro   │  192.168.1.0/24 (public)
                      └──────┬──────┘
                             │  ec2.internal DNS
                      ┌──────┴──────┐
                      │ voting-app  │  HTTP :80
                      │  t3.micro   │  192.168.101.0/24 (public)
                      └──────┬──────┘
                             │  SQL :1433
                      ┌──────┴──────┐
                      │ voting-db   │  SQL Server 2019 (Docker)
                      │  t3.small   │  192.168.201.0/24 (private)
                      └─────────────┘
```

| Tier | Hostname | Access | Instance |
|------|----------|--------|----------|
| Web (UI) | `voting-web01` | Public IP | `t3.micro` |
| App (API) | `voting-app01` | Public IP | `t3.micro` |
| DB (SQL) | `voting-db01` | Private IP only | `t3.small` |

Application binaries are pulled at boot from [wajihalsaid/Voting_app](https://github.com/wajihalsaid/Voting_app).

---

## Prerequisites

Install and verify before you start:

| Tool | Check |
|------|-------|
| AWS CLI v2 | `aws sts get-caller-identity` |
| Terraform ≥ 1.3 | `terraform version` |
| SSH client | `ssh -V` |
| curl (for smoke test) | `curl --version` |

You need an AWS account with permissions to create VPC, EC2, Route53, and security groups. No pre-existing infrastructure is required.

---

## Bring up the app

### Step 1 — Clone the repository

```bash
git clone https://github.com/chandrapati/voting-app-aws.git
cd voting-app-aws/terraform
```

### Step 2 — Generate an SSH key (first time only)

```bash
ssh-keygen -t rsa -b 4096 -f voting-app-key -N "" -C "voting-app-deploy"
```

The private key `voting-app-key` stays on your machine (gitignored). Only the public key is registered in AWS.

### Step 3 — Configure (optional)

Defaults work for most labs. To customize region or instance sizes:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` if needed:

```hcl
vpc_region       = "us-east-1"    # change region if required
instance_type    = "t3.micro"     # web + app tiers
db_instance_type = "t3.small"     # SQL Server Docker needs 2 GiB RAM
```

If you use a named AWS CLI profile, set `aws_credentials_profile = "your-profile"`.

### Step 4 — Deploy

```bash
terraform init
terraform apply
```

Type `yes` when prompted (or use `terraform apply -auto-approve` in automation).

**Timeline:**

| Phase | Duration | What happens |
|-------|----------|--------------|
| Terraform apply | ~3–5 min | VPC, 3 EC2 instances, security groups, private DNS |
| User-data bootstrap | ~8–12 min | Docker SQL Server, .NET apps, Apache |
| Ready to use | ~15 min total | UI responds on port 80 |

Your public IP is auto-detected and added to security groups for SSH and HTTP access.

### Step 5 — Get the app URL

```bash
terraform output voting_web_url_http
```

Example: `http://44.201.139.245`

Open that URL in a browser. You should see **"What's For Lunch?"** — add lunch options and vote.

### Step 6 — Run the smoke test (recommended)

From the repo root:

```bash
./scripts/test-voting-app.sh
```

This polls the web tier for up to 15 minutes and reports success or troubleshooting hints.

### Useful outputs after deploy

```bash
terraform output                    # all outputs
terraform output -raw voting_web_url_http
terraform output -raw voting_app_public_ip
terraform output -raw sql_password  # SQL Server sa password (sensitive)
terraform output ssh_web            # copy-paste SSH command
```

---

## Verify the app works

1. Browse to `terraform output -raw voting_web_url_http`
2. Add a lunch suggestion and vote
3. Refresh the page — vote counts should update
4. (Optional) HTTPS: `terraform output -raw voting_web_url_https` — browser will warn about self-signed cert; proceed for lab use only

---

## Tear down the app

**Always destroy when the lab is finished** to avoid ongoing charges.

```bash
cd voting-app-aws/terraform
terraform destroy
```

Type `yes` when prompted. All resources are removed in **~2–3 minutes**.

### Confirm nothing is left behind

```bash
# Should return empty or no voting-app resources
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=voting-app" \
  --query 'Reservations[].Instances[].State.Name'

aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=voting-app" \
  --query 'Vpcs[].VpcId'
```

If `terraform destroy` fails partway, run it again — it is safe to retry.

---

## Cost to run

Pricing below is **approximate** for **us-east-1 on-demand** (June 2026). Actual charges depend on your AWS account, region, and usage.

### Compute (main cost)

| Resource | Qty | ~$/hour | ~$/day (24h) | ~$/month (730h) |
|----------|-----|---------|--------------|-----------------|
| `t3.micro` (web) | 1 | $0.0104 | $0.25 | $7.59 |
| `t3.micro` (app) | 1 | $0.0104 | $0.25 | $7.59 |
| `t3.small` (db) | 1 | $0.0208 | $0.50 | $15.18 |
| **EC2 subtotal** | | **~$0.042/hr** | **~$1.00/day** | **~$30/month** |

### Other charges (usually small)

| Item | Estimate |
|------|----------|
| EBS volumes (default ~8 GB × 3) | ~$2/month if instances run 24/7 |
| Route53 private hosted zone | $0.50/month per zone |
| Data transfer (inbound) | Free |
| Data transfer (outbound) | First 100 GB/month free, then per-GB rates |

### Cost-saving tips for customer demos

1. **Run `terraform destroy` immediately after the workshop** — a 4-hour lab costs ~$0.17 in EC2 alone.
2. **Do not leave the stack running overnight** — ~$1/day adds up across multiple demos.
3. **Use the same AWS account/region** for repeat workshops; no need to keep instances running between sessions.
4. **Spot instances** — set `use_spot_instances = true` in `terraform.tfvars` for ~60–70% EC2 savings (instances can be interrupted; acceptable for short demos).

### Example workshop scenarios

| Scenario | Duration | Approx. EC2 cost |
|----------|----------|------------------|
| Single 2-hour POV session | 2 hr | ~$0.08 |
| Full day lab (8 hr) | 8 hr | ~$0.34 |
| Forgot to destroy (1 week) | 168 hr | ~$7.00 |
| Left running 30 days | 730 hr | ~$30.00 |

> **Note:** This stack is **not** covered entirely by AWS Free Tier because the database tier uses `t3.small` (SQL Server in Docker requires 2 GiB RAM).

---

## Troubleshooting

### 1. App URL times out or connection refused

**Cause:** Bootstrap still running (normal for 8–12 min after `terraform apply`).

**Fix:**

```bash
./scripts/test-voting-app.sh
```

Wait until you see `OK: HTTP 200`.

---

### 2. Terraform apply fails or hangs

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ExpiredToken` / auth error | AWS credentials expired | `aws sso login` or refresh keys, then retry |
| `UnauthorizedOperation` | IAM permissions missing | Ensure EC2, VPC, Route53 create permissions |
| Stuck >15 min on one resource | Transient AWS API delay | `Ctrl+C`, then `terraform apply` again |
| `Error acquiring the state lock` | Previous run interrupted | Delete `.terraform.tfstate.lock.info` if no other apply is running |

---

### 3. Can't SSH or browse the app (but it worked earlier)

**Cause:** Your public IP changed; security groups only allow your IP at apply time.

**Fix:**

```bash
cd terraform
terraform apply   # re-detects IP and updates security groups
```

---

### 4. Web tier issues

```bash
ssh -i voting-app-key ubuntu@$(terraform output -raw voting_web_public_ip)

sudo tail -100 /var/log/cloud-init-output.log
sudo systemctl status votingweb apache2
curl -s localhost:5000 | head -20
```

Look for `voting-web bootstrap complete` in `/var/log/voting-web-bootstrap.log`.

---

### 5. API tier issues

```bash
ssh -i voting-app-key ubuntu@$(terraform output -raw voting_app_public_ip)

sudo tail -100 /var/log/cloud-init-output.log
sudo systemctl status votingdata apache2
grep -i connection /var/www/votingdata/appsettings.json
```

The app tier waits up to **15 minutes** for SQL Server on `voting-db01.ec2.internal:1433`.

---

### 6. Database tier issues

The DB host has **no public IP**. Jump through the app host:

```bash
APP_IP=$(terraform output -raw voting_app_public_ip)
ssh -i voting-app-key -J ubuntu@${APP_IP} ubuntu@voting-db01.ec2.internal

sudo docker ps
sudo docker logs sqlserver --tail 50
cat /var/log/voting-db-bootstrap.log
```

SQL Server is ready when docker logs show: `SQL Server is now ready for client connections`.

---

### 7. Votes don't persist / database errors

```bash
# From app host — test SQL port
nc -zv voting-db01.ec2.internal 1433

# Get SA password from your laptop
terraform output -raw sql_password
```

Check security group allows TCP 1433 from app subnet `192.168.101.0/24`.

---

### 8. .NET or package install failures

User-data installs legacy .NET Core 2.2 on Ubuntu 22.04. If apt/wget fails (mirror timeout):

```bash
sudo tail -200 /var/log/cloud-init-output.log
```

Recreate the affected instance:

```bash
terraform taint 'aws_instance.voting["voting-web"]'
terraform apply
```

---

### 9. Recreate everything from scratch

```bash
terraform destroy -auto-approve
terraform apply -auto-approve
./scripts/test-voting-app.sh
```

---

## Security notes for customer demos

- HTTP is open to **your IP** (auto-detected) plus RFC1918 ranges for tier-to-tier traffic.
- The database tier is **not** internet-facing.
- SQL `sa` password is randomly generated and stored in Terraform state — treat state files as sensitive.
- This is a **lab/demo** stack, not production-hardened. Do not store real customer data.
- Destroy the environment when finished.

---

## Repository layout

```
voting-app-aws/
├── README.md                       # This file
├── scripts/
│   └── test-voting-app.sh          # Post-deploy smoke test
└── terraform/
    ├── main.tf
    ├── network.tf
    ├── security_groups.tf
    ├── ec2.tf
    ├── dns.tf
    ├── secrets.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── scripts/
        ├── install-voting-db.sh    # SQL Server Docker
        ├── install-voting-app.sh # .NET API
        └── install-voting-web.sh # .NET UI
```

---

## Sharing with customers

Send them:

1. **Repo link:** https://github.com/chandrapati/voting-app-aws  
2. **Prerequisites:** AWS account, CLI, Terraform (table above)  
3. **Bring-up:** Steps in [Bring up the app](#bring-up-the-app)  
4. **Teardown:** `terraform destroy` when done  
5. **Cost:** ~$0.04/hr — destroy after the session  

---

## License

Terraform and documentation in this repository may be used freely for demos and workshops. Application binaries are sourced from the upstream [Voting_app](https://github.com/wajihalsaid/Voting_app) project — refer to that repository for application licensing.
