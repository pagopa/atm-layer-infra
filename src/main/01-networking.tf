########
# VPC + Subnet + IGW
########
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.namespace}-vpc"
  }
}

resource "aws_subnet" "priv_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnets_cidr[0]
  availability_zone = var.azs[0]

  tags = {
    Name                              = "${local.namespace}-priv-1"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "priv_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnets_cidr[1]
  availability_zone = var.azs[1]
  tags = {
    Name                              = "${local.namespace}-priv-2"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "priv_subnet_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnets_cidr[2]
  availability_zone = var.azs[2]
  tags = {
    Name                              = "${local.namespace}-priv-3"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "pub_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_public_subnets_cidr[0]
  availability_zone = var.azs[0]
  tags = {
    Name                     = "${local.namespace}-pub-1"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "pub_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_public_subnets_cidr[1]
  availability_zone = var.azs[1]
  tags = {
    Name                     = "${local.namespace}-pub-2"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "pub_subnet_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_public_subnets_cidr[2]
  availability_zone = var.azs[2]
  tags = {
    Name                     = "${local.namespace}-pub-3"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.namespace}-igw"
  }
}

########
# Route Table + Routes
########
resource "aws_route_table" "pub_1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.namespace}-pub-rt"
  }
}

resource "aws_route" "pub_1_route_1" {
  route_table_id         = aws_route_table.pub_1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.pub_subnet_1.id
  route_table_id = aws_route_table.pub_1.id
}
resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.pub_subnet_2.id
  route_table_id = aws_route_table.pub_1.id
}
resource "aws_route_table_association" "pub_3" {
  subnet_id      = aws_subnet.pub_subnet_3.id
  route_table_id = aws_route_table.pub_1.id
}

resource "aws_route_table" "priv_1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.namespace}-priv-rt-1"
  }
}

resource "aws_route" "priv_1_route_1" {
  route_table_id         = aws_route_table.priv_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_1.id
}

resource "aws_route_table_association" "priv_1" {
  subnet_id      = aws_subnet.priv_subnet_1.id
  route_table_id = aws_route_table.priv_1.id
}

resource "aws_route_table" "priv_2" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.namespace}-priv-rt-2"
  }
}

resource "aws_route" "priv_2_route_1" {
  route_table_id         = aws_route_table.priv_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_2.id
}

resource "aws_route_table_association" "priv_2" {
  subnet_id      = aws_subnet.priv_subnet_2.id
  route_table_id = aws_route_table.priv_2.id
}

resource "aws_route_table" "priv_3" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.namespace}-priv-rt-3"
  }
}

resource "aws_route" "priv_3_route_1" {
  route_table_id         = aws_route_table.priv_3.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_3.id
}

resource "aws_route_table_association" "priv_3" {
  subnet_id      = aws_subnet.priv_subnet_3.id
  route_table_id = aws_route_table.priv_3.id
}

########
# EIP + NAT
########
resource "aws_eip" "nat_1" {
  domain = "vpc"
  tags = {
    Name = "${local.namespace}-eip-nat-1"
  }
}

resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.pub_subnet_1.id

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "${local.namespace}-nat-1"
  }
}

resource "aws_eip" "nat_2" {
  domain = "vpc"
  tags = {
    Name = "${local.namespace}-eip-nat-2"
  }
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.pub_subnet_2.id

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "${local.namespace}-nat-2"
  }
}

resource "aws_eip" "nat_3" {
  domain = "vpc"
  tags = {
    Name = "${local.namespace}-eip-nat-3"
  }
}

resource "aws_nat_gateway" "nat_3" {
  allocation_id = aws_eip.nat_3.id
  subnet_id     = aws_subnet.pub_subnet_3.id

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "${local.namespace}-nat-3"
  }
}

########
# Subnet Group for DB
########
resource "aws_db_subnet_group" "rds" {
  name       = "${local.namespace}-aurora-sbnt-group"
  subnet_ids = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.namespace}-redis-sbnt-group"
  subnet_ids = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
}

########
# Security Group for VPC Endpoints
########
resource "aws_security_group" "vpc_endpoint" {
  name   = "${local.namespace}-vpc-endpoint-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.namespace}-vpc-endpoint-sg"
  }
}

resource "aws_security_group_rule" "vpc_endpoint_rule_ingress_1" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpc_endpoint.id
}

resource "aws_security_group_rule" "vpc_endpoint_rule_egress_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpc_endpoint.id
}

########
# VPC Endpoints
########
resource "aws_vpc_endpoint" "endpoint" {
  for_each = var.vpc_endpoints

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.${each.value.name}"
  vpc_endpoint_type = each.value.type

  security_group_ids = [
    aws_security_group.vpc_endpoint.id,
  ]

  subnet_ids = [
    aws_subnet.priv_subnet_1.id,
    aws_subnet.priv_subnet_2.id,
    aws_subnet.priv_subnet_3.id
  ]

  private_dns_enabled = each.value.priv_dns
  tags = {
    Name = "${local.namespace}-${each.value.name}"
  }

}
