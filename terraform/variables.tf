variable "project_name" {
  description = "Prefix used for resource naming."
  type        = string
  default     = "voting-app"
}

variable "vpc_name" {
  description = "Name tag for the VPC."
  type        = string
  default     = "voting-app-vpc"
}

variable "vpc_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_availability_zones" {
  description = "Two availability zones for DB subnet group."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key used for EC2 access."
  type        = string
  default     = "voting-app-key.pub"
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "web_dev_subnet01_cidr" {
  type    = string
  default = "192.168.1.0/24"
}

variable "app_dev_subnet01_cidr" {
  type    = string
  default = "192.168.101.0/24"
}

variable "db_dev_subnet01_cidr" {
  type    = string
  default = "192.168.201.0/24"
}

variable "db_instance_type" {
  description = "EC2 type for SQL Server Docker (needs 2 GiB RAM — t3.small minimum)."
  type        = string
  default     = "t3.small"
}

variable "aws_credentials_profile" {
  description = "AWS CLI profile name. Leave empty to use default credentials chain."
  type        = string
  default     = ""
}

variable "use_spot_instances" {
  description = "Use EC2 Spot instances (cheaper but can be interrupted)."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type for web and app tiers."
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "Optional extra CIDR for SSH access. Your public IP is always added automatically."
  type        = string
  default     = ""
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs delivered to an encrypted S3 bucket."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Days to retain VPC flow log objects in S3 before lifecycle expiration."
  type        = number
  default     = 7
}

variable "enable_traffic_generator" {
  description = "Deploy a client EC2 that generates HTTP/HTTPS traffic every minute."
  type        = bool
  default     = true
}

variable "client_dev_subnet01_cidr" {
  description = "Private subnet for the traffic generator client."
  type        = string
  default     = "192.168.102.0/24"
}

variable "client_private_ip" {
  description = "Fixed private IP for the traffic generator (must be in client subnet)."
  type        = string
  default     = "192.168.102.40"
}

variable "client_instance_type" {
  description = "EC2 instance type for the traffic generator client."
  type        = string
  default     = "t3.micro"
}
