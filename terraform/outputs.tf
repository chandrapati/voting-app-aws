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
