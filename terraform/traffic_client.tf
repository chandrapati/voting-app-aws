resource "aws_subnet" "client_dev_subnet01" {
  count = var.enable_traffic_generator ? 1 : 0

  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.client_dev_subnet01_cidr
  availability_zone = var.vpc_availability_zones[0]

  tags = {
    Name    = "client_dev_subnet01"
    Project = var.project_name
    Tier    = "client"
  }
}

resource "aws_instance" "traffic_client" {
  count = var.enable_traffic_generator ? 1 : 0

  ami                    = data.aws_ami.ubuntu_ami.id
  instance_type          = var.client_instance_type
  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.dev_client_sg[0].id]
  subnet_id              = aws_subnet.client_dev_subnet01[0].id
  private_ip             = var.client_private_ip

  user_data = templatefile("${path.module}/scripts/install-voting-client.sh", {
    hostname         = "voting-client01"
    web_host         = "voting-web01.ec2.internal"
    app_host         = "voting-app01.ec2.internal"
    web_private_ip   = aws_instance.voting["voting-web"].private_ip
    traffic_gen_b64  = base64encode(file("${path.module}/scripts/voting_client_generate_traffic.sh"))
  })

  dynamic "instance_market_options" {
    for_each = var.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = "0.02"
      }
    }
  }

  tags = {
    Name        = "voting-client01"
    Project     = var.project_name
    environment = "dev"
    tier        = "client"
    app         = "voting"
    Role        = "traffic-generator"
  }

  depends_on = [aws_instance.voting]
}
