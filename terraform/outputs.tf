output "operator_public_ip" {
  description = "Your public IP used for security group rules."
  value       = local.myip
}

output "voting_web_url_http" {
  description = "Voting app UI (HTTP)."
  value       = "http://${aws_instance.voting["voting-web"].public_ip}"
}

output "voting_web_url_https" {
  description = "Voting app UI (HTTPS — self-signed cert)."
  value       = "https://${aws_instance.voting["voting-web"].public_ip}"
}

output "voting_app_private_dns" {
  description = "Internal DNS name for the API tier."
  value       = "voting-app01.ec2.internal"
}

output "voting_db_private_dns" {
  description = "Internal DNS name for the database tier."
  value       = "voting-db01.ec2.internal"
}

output "voting_web_public_ip" {
  value = aws_instance.voting["voting-web"].public_ip
}

output "voting_app_public_ip" {
  value = aws_instance.voting["voting-app"].public_ip
}

output "voting_db_private_ip" {
  value = aws_instance.voting["voting-db"].private_ip
}

output "sql_username" {
  value = "sa"
}

output "sql_password" {
  value     = random_password.sql_sa_password.result
  sensitive = true
}

output "ssh_web" {
  description = "SSH to web tier."
  value       = "ssh -i voting-app-key ubuntu@${aws_instance.voting["voting-web"].public_ip}"
}

output "ssh_app" {
  description = "SSH to app tier."
  value       = "ssh -i voting-app-key ubuntu@${aws_instance.voting["voting-app"].public_ip}"
}

output "ssh_db" {
  description = "SSH to db tier (via app subnet bastion path — db has no public IP)."
  value       = "ssh -i voting-app-key ubuntu@${aws_instance.voting["voting-db"].private_ip}  # from app/web host"
}

output "bootstrap_note" {
  value = "All 3 EC2 instances launch in parallel. SQL Server Docker is ready in ~3-5 min; full app stack ~8-12 min. Run ../scripts/test-voting-app.sh to verify."
}

output "vpc_flow_logs_enabled" {
  description = "Whether VPC Flow Logs to S3 are enabled."
  value       = var.enable_vpc_flow_logs
}

output "vpc_flow_logs_s3_bucket" {
  description = "S3 bucket receiving VPC Flow Logs (plain-text, hourly partitions)."
  value       = var.enable_vpc_flow_logs ? aws_s3_bucket.vpc_flow_logs[0].id : null
}

output "vpc_flow_logs_s3_prefix" {
  description = "S3 key prefix where flow log objects are written."
  value       = var.enable_vpc_flow_logs ? "AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${var.vpc_region}/" : null
}

output "csw_flow_log_bucket_name" {
  description = "S3 bucket name for CSW AWS connector Flow Log Ingestion."
  value       = var.enable_vpc_flow_logs ? aws_s3_bucket.vpc_flow_logs[0].id : null
}

output "verify_flow_logs_command" {
  description = "Run flow log diagnostic from repo root."
  value       = "bash scripts/verify-flow-logs.sh"
}

output "vpc_region" {
  description = "AWS region of the voting-app VPC."
  value       = var.vpc_region
}

output "traffic_generator_enabled" {
  description = "Whether the traffic generator client is deployed."
  value       = var.enable_traffic_generator
}

output "traffic_client_private_ip" {
  description = "Private IP of the traffic generator client."
  value       = var.enable_traffic_generator ? aws_instance.traffic_client[0].private_ip : null
}

output "ssh_client_via_web" {
  description = "SSH to traffic generator via web tier jump host (ProxyCommand)."
  value       = var.enable_traffic_generator ? "ssh -i voting-app-key -o ProxyCommand=\"ssh -i voting-app-key -W %h:%p ubuntu@${aws_instance.voting["voting-web"].public_ip}\" ubuntu@${aws_instance.traffic_client[0].private_ip}" : null
}

output "monitor_traffic_log" {
  description = "Tail traffic generator log on the client VM."
  value       = var.enable_traffic_generator ? "ssh -i voting-app-key -o ProxyCommand=\"ssh -i voting-app-key -W %h:%p ubuntu@${aws_instance.voting["voting-web"].public_ip}\" ubuntu@${aws_instance.traffic_client[0].private_ip} 'sudo tail -f /var/log/voting_traffic_probe.log'" : null
}
