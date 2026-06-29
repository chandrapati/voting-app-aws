resource "aws_vpc" "dev_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name    = var.vpc_name
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_subnet" "web_dev_subnet01" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.web_dev_subnet01_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.vpc_availability_zones[0]

  tags = {
    Name    = "web_dev_subnet01"
    Project = var.project_name
    Tier    = "web"
  }
}

resource "aws_subnet" "app_dev_subnet01" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.app_dev_subnet01_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.vpc_availability_zones[0]

  tags = {
    Name    = "app_dev_subnet01"
    Project = var.project_name
    Tier    = "app"
  }
}

resource "aws_subnet" "db_dev_subnet01" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.db_dev_subnet01_cidr
  availability_zone = var.vpc_availability_zones[0]

  tags = {
    Name    = "db_dev_subnet01"
    Project = var.project_name
    Tier    = "db"
  }
}

resource "aws_route_table" "dev_rt01" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_main_route_table_association" "dev_rta01" {
  vpc_id         = aws_vpc.dev_vpc.id
  route_table_id = aws_route_table.dev_rt01.id
}
