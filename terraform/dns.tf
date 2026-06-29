resource "aws_route53_zone" "internal_dns" {
  name = "ec2.internal"

  vpc {
    vpc_id = aws_vpc.dev_vpc.id
  }

  tags = {
    Name    = "${var.project_name}-internal-dns"
    Project = var.project_name
  }
}

resource "aws_route53_record" "internal_dns" {
  for_each = aws_instance.voting

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "${each.value.tags.Name}.ec2.internal"
  type    = "A"
  ttl     = 300
  records = [each.value.private_ip]
}

resource "aws_route53_record" "traffic_client_dns" {
  count = var.enable_traffic_generator ? 1 : 0

  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "voting-client01.ec2.internal"
  type    = "A"
  ttl     = 300
  records = [aws_instance.traffic_client[0].private_ip]
}
