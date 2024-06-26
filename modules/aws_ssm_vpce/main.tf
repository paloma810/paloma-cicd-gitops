# SSM用VPC Endpointの作成
# count句とfor_each句を一度に併用できないため、for_eachを用いたmoduleを作成し、moduleを参照する形でcount句を用いる。

locals {
  vpc_endpoint_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "paloma-dv-vpc-endpoint-ssm" {
  for_each = toset(local.vpc_endpoint_services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.ap-northeast-1.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [var.subnet_id]
  security_group_ids = [
    var.security_group_id
  ]
  tags = {
    Name = "${var.resource_name_prefix}-vpc-endpoint-${each.value}"
  }
}
