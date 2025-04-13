##########
# 1. NW  #
##########

# 1-1. VPCの作成
resource "aws_vpc" "paloma-dv-vpc01" {
  count      = var.is_create_aws_resources
  cidr_block = "10.11.0.0/24"

  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.aws_resname_prefix}-vpc01"
  }
}

# 1-1. パブリックサブネットの作成
resource "aws_subnet" "paloma-dv-vpc01-pub-subnet01" {
  count    = var.is_create_aws_resources
  provider = aws

  vpc_id            = aws_vpc.paloma-dv-vpc01[0].id
  cidr_block        = "10.11.0.0/26"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-pub-subnet01"
  }
}

# 1-2. プライベートサブネットの作成
resource "aws_subnet" "paloma-dv-vpc01-pri-subnet01" {
  count    = var.is_create_aws_resources
  provider = aws

  vpc_id            = aws_vpc.paloma-dv-vpc01[0].id
  cidr_block        = "10.11.0.64/26"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-pri-subnet01"
  }
}

# 1-3. IGWの作成
resource "aws_internet_gateway" "paloma-dv-vpc01-igw01" {
  count  = var.is_create_aws_resources
  vpc_id = aws_vpc.paloma-dv-vpc01[0].id

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-igw01"
  }
}

# 1-4. Pubルートテーブルの作成
resource "aws_route_table" "paloma-dv-pub-rt01" {
  count  = var.is_create_aws_resources
  vpc_id = aws_vpc.paloma-dv-vpc01[0].id

  # localのルートはデフォルトで作成される？
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.paloma-dv-vpc01-igw01[0].id
  }
}

# 1-5. パブリックサブネットのルートテーブルの関連付け
resource "aws_route_table_association" "paloma-dv-pub_subnet01_association" {
  count          = var.is_create_aws_resources
  subnet_id      = aws_subnet.paloma-dv-vpc01-pub-subnet01[0].id
  route_table_id = aws_route_table.paloma-dv-pub-rt01[0].id
}

# 1-6. Priルートテーブルの作成
resource "aws_route_table" "paloma-dv-pri-rt01" {
  count  = var.is_create_aws_resources
  vpc_id = aws_vpc.paloma-dv-vpc01[0].id
}

# 1-7. プライベートサブネットのルートテーブルの関連付け
resource "aws_route_table_association" "paloma-dv-pri_subnet01_association" {
  count          = var.is_create_aws_resources
  subnet_id      = aws_subnet.paloma-dv-vpc01-pri-subnet01[0].id
  route_table_id = aws_route_table.paloma-dv-pri-rt01[0].id
}

# 1-8. VPC Endpont
module "paloma-dv-vpc-endpoint-ssm" {
  count = var.is_create_aws_resources

  source = "../../../modules/aws_ssm_vpce"

  vpc_id               = aws_vpc.paloma-dv-vpc01[0].id
  subnet_id            = aws_subnet.paloma-dv-vpc01-pri-subnet01[0].id
  security_group_id    = aws_security_group.paloma-dv-vpce-sg01[0].id
  resource_name_prefix = var.aws_resname_prefix

}

##################
# 2. EC2 (+IAM)  #
##################

# 2-1. SSM接続用IAMロール
resource "aws_iam_role" "paloma-dv-iam-role-ssm" {
  count              = var.is_create_aws_resources > 0 ? var.is_create_aws_instance > 0 ? 1 : 0 : 0
  name               = "${var.aws_resname_prefix}-iam-role-ssm"
  description        = "Allows EC2 instances to call AWS services on your behalf"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "${var.aws_resname_prefix}-iam-role-SSM"
  }
}

# 2-1. IAMポリシーのアタッチ
resource "aws_iam_role_policy_attachment" "paloma-dv-iam-role-ssm" {
  count      = var.is_create_aws_resources > 0 ? var.is_create_aws_instance > 0 ? 1 : 0 : 0
  role       = aws_iam_role.paloma-dv-iam-role-ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 2-1. EC2インスタンスプロファイルの作成
resource "aws_iam_instance_profile" "paloma-dv-instance-profile01" {
  count = var.is_create_aws_resources > 0 ? var.is_create_aws_instance > 0 ? 1 : 0 : 0

  name = "${var.aws_resname_prefix}-instance-profile01"
  role = aws_iam_role.paloma-dv-iam-role-ssm[0].name
}

# 2-2. EC2インスタンス（パブリックサブネット）
resource "aws_instance" "paloma-dv-pub-instance01" {
  count = var.is_create_aws_resources > 0 ? var.is_create_aws_instance > 0 ? var.is_create_aws_instance : 0 : 0

  provider = aws

  ami                         = "ami-0bc23e4337e8bc5ea" # Amazon Linuxを選択
  instance_type               = "t2.micro"
  key_name                    = "paloma-pr-keypair01"
  subnet_id                   = aws_subnet.paloma-dv-vpc01-pub-subnet01[0].id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.paloma-dv-instance-profile01[0].name

  # ディスク
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.paloma-dv-pub-sg01[0].id]
  tags = {
    Name = "${var.aws_resname_prefix}-pub-instance01"
  }
}

# 2-3. EC2インスタンス（プライベートサブネット Linux）
resource "aws_instance" "paloma-dv-pri-linux-instance01" {
  count = var.is_create_aws_resources > 0 ? var.is_create_aws_instance > 0 ? var.is_create_aws_instance : 0 : 0

  provider = aws

  ami                         = "ami-0d739893974bd27d0" # Amazon Linux2を選択
  instance_type               = "t2.micro"
  key_name                    = "paloma-pr-keypair01"
  subnet_id                   = aws_subnet.paloma-dv-vpc01-pri-subnet01[0].id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.paloma-dv-instance-profile01[0].name

  # ディスク
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.paloma-dv-pri-sg01[0].id]
  tags = {
    Name = "${var.aws_resname_prefix}-pri-linux-instance01"
  }
}

# 2-4. EC2インスタンス（プライベートサブネット Windows）
resource "aws_instance" "paloma-dv-pri-win-instance01" {
  count = var.is_create_aws_resources > 0 ? var.is_create_aws_instance > 0 ? var.is_create_aws_instance : 0 : 0

  provider = aws

  ami                         = "ami-0222cfd6a9c020197" # Windows_Server-2022-English-Full-Base-2023.07.12
  instance_type               = "t2.large"
  key_name                    = "paloma-pr-keypair01"
  subnet_id                   = aws_subnet.paloma-dv-vpc01-pri-subnet01[0].id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.paloma-dv-instance-profile01[0].name

  # ディスク
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }

  vpc_security_group_ids = [aws_security_group.paloma-dv-pri-sg01[0].id]
  tags = {
    Name = "${var.aws_resname_prefix}-pri-win-instance01"
  }
}


# 2-5. パブリックサブネットのEC2用セキュリティグループ
resource "aws_security_group" "paloma-dv-pub-sg01" {
  count       = var.is_create_aws_resources
  name        = "paloma-dv-pub-sg01"
  description = "Allow public access"
  vpc_id      = aws_vpc.paloma-dv-vpc01[0].id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [aws_security_group.paloma-dv-pri-sg01[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.aws_resname_prefix}-pub-sg01"
  }
}

# 2-6. プライベートサブネットのEC2用セキュリティグループ
resource "aws_security_group" "paloma-dv-pri-sg01" {
  count       = var.is_create_aws_resources
  name        = "paloma-dv-pri-sg01"
  description = "Allow local access"
  vpc_id      = aws_vpc.paloma-dv-vpc01[0].id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  /* Cycleエラーを回避するため、sg外で定義
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/24"]
    security_groups = [aws_security_group.paloma-dv-pub-sg01.name]
  }
*/
  tags = {
    Name = "${var.aws_resname_prefix}-pri-sg01"
  }
}

# Cycleエラーを回避するため、pri-sg01の sg向け egressルールを外だし（SG Ruleで定義）
resource "aws_security_group_rule" "paloma-dv-pri-sg01-rule-egress" {
  count                    = var.is_create_aws_resources
  security_group_id        = aws_security_group.paloma-dv-pri-sg01[0].id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.paloma-dv-pub-sg01[0].id
}

# GCP VPCへのEgress許可を追加
resource "aws_security_group_rule" "paloma-dv-pri-sg01-rule-egress-gcp" {
  count             = var.is_create_aws_resources
  security_group_id = aws_security_group.paloma-dv-pri-sg01[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = [
    "10.1.0.0/24"
  ]

}

# 2-7. SSM用VPC Endpoint用セキュリティグループ
resource "aws_security_group" "paloma-dv-vpce-sg01" {
  count = var.is_create_aws_resources

  name        = "paloma-dv-vpce-sg01"
  description = "Allow local access"
  vpc_id      = aws_vpc.paloma-dv-vpc01[0].id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.paloma-dv-vpc01[0].cidr_block]
  }

  tags = {
    Name = "${var.aws_resname_prefix}-vpce-sg01"
  }
}


# SSM用VPC Endpointの作成（ループで作成してみる）
/**** TODO：削除　一時的に残している
locals {
  vpc_endpoint_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "paloma-dv-vpc-endpoint-ssm" {
  count    = var.is_create_aws_resources
  for_each = toset(local.vpc_endpoint_services)

  vpc_id              = aws_vpc.paloma-dv-vpc01[0].id
  service_name        = "com.amazonaws.ap-northeast-1.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.paloma-dv-vpc01-pri-subnet01[0].id]
  security_group_ids = [
    aws_security_group.paloma-dv-vpce-sg01[0].id
  ]
  tags = {
    Name = "${var.aws_resname_prefix}-vpc-endpoint-${each.value}"
  }
}
*/
