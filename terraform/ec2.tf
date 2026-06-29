resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_file)
}

locals {
  vm_config = {
    voting-db = {
      script        = "${path.module}/scripts/install-voting-db.sh"
      subnet_id     = aws_subnet.db_dev_subnet01.id
      sg_ids        = [aws_security_group.dev_db_sg.id]
      tier          = "db"
      instance_type = var.db_instance_type
    }
    voting-app = {
      script        = "${path.module}/scripts/install-voting-app.sh"
      subnet_id     = aws_subnet.app_dev_subnet01.id
      sg_ids        = [aws_security_group.dev_app_sg.id]
      tier          = "app"
      instance_type = var.instance_type
    }
    voting-web = {
      script        = "${path.module}/scripts/install-voting-web.sh"
      subnet_id     = aws_subnet.web_dev_subnet01.id
      sg_ids        = [aws_security_group.dev_web_sg.id]
      tier          = "web"
      instance_type = var.instance_type
    }
  }
}

resource "aws_instance" "voting" {
  for_each = local.vm_config

  ami                    = data.aws_ami.ubuntu_ami.id
  instance_type          = each.value.instance_type
  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = each.value.sg_ids
  subnet_id              = each.value.subnet_id

  user_data = templatefile(each.value.script, {
    hostname  = "${each.key}01"
    sql_host  = "voting-db01.ec2.internal"
    sqlServer = "voting-db01.ec2.internal"
    username  = "sa"
    password  = random_password.sql_sa_password.result
    app_host  = "voting-app01.ec2.internal"
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
    Name        = "${each.key}01"
    Project     = var.project_name
    environment = "dev"
    tier        = each.value.tier
    app         = "voting"
  }
}
