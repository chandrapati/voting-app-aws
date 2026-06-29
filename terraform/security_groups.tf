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

resource "aws_security_group" "dev_client_sg" {
  count = var.enable_traffic_generator ? 1 : 0

  name        = "${var.project_name}-client-sg"
  description = "Traffic generator client"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "SSH from operator and jump hosts"
    from_port   = 22
    to_port     = 22
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
    Name    = "${var.project_name}-client-sg"
    Project = var.project_name
    Tier    = "client"
  }
}

resource "aws_security_group_rule" "web_http_from_client" {
  count = var.enable_traffic_generator ? 1 : 0

  type                     = "ingress"
  description              = "HTTP from traffic generator"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dev_web_sg.id
  source_security_group_id = aws_security_group.dev_client_sg[0].id
}

resource "aws_security_group_rule" "web_https_from_client" {
  count = var.enable_traffic_generator ? 1 : 0

  type                     = "ingress"
  description              = "HTTPS from traffic generator"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dev_web_sg.id
  source_security_group_id = aws_security_group.dev_client_sg[0].id
}

resource "aws_security_group_rule" "app_http_from_client" {
  count = var.enable_traffic_generator ? 1 : 0

  type                     = "ingress"
  description              = "HTTP from traffic generator (east-west API)"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dev_app_sg.id
  source_security_group_id = aws_security_group.dev_client_sg[0].id
}

resource "aws_security_group_rule" "client_ssh_from_web" {
  count = var.enable_traffic_generator ? 1 : 0

  type                     = "ingress"
  description              = "SSH from web tier (jump host)"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dev_client_sg[0].id
  source_security_group_id = aws_security_group.dev_web_sg.id
}

resource "aws_security_group_rule" "client_ssh_from_app" {
  count = var.enable_traffic_generator ? 1 : 0

  type                     = "ingress"
  description              = "SSH from app tier (jump host)"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dev_client_sg[0].id
  source_security_group_id = aws_security_group.dev_app_sg.id
}
