data "http" "myip" {
  url = "https://ifconfig.me/ip"
}

locals {
  myip = trimspace(data.http.myip.response_body)

  ssh_cidrs = compact([
    "${local.myip}/32",
    var.allowed_ssh_cidr != "" ? var.allowed_ssh_cidr : null,
  ])

  # Web tier: operator IP + RFC1918 (for internal proxy paths during bootstrap).
  web_http_cidrs = distinct(concat(local.ssh_cidrs, ["172.16.0.0/12", "192.168.0.0/16", "10.0.0.0/8"]))
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
