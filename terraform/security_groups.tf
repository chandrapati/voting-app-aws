resource "aws_security_group" "dev_web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Voting app web tier"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web-sg"
    Project = var.project_name
    Tier    = "web"
  }
}

resource "aws_security_group" "dev_app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Voting app API tier"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  ingress {
    description = "HTTP from web tier and operator"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  ingress {
    description = "HTTPS from web tier and operator"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
    Tier    = "app"
  }
}

resource "aws_security_group" "dev_db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Voting app SQL Server (Docker on EC2)"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "SSH from operator (via jump through app/web)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.web_http_cidrs
  }

  ingress {
    description = "SQL Server from app and web tiers"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [var.app_dev_subnet01_cidr, var.web_dev_subnet01_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-db-sg"
    Project = var.project_name
    Tier    = "db"
  }
}
