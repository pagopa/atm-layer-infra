########
# VPC + Subnet + IGW
########
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "PagoPA VPC"
  }
}

resource "aws_subnet" "priv_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnets_cidr[0]
  availability_zone = var.azs[0]

  tags = {
    Name                              = "Priv 1 - PagoPA VPC"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "priv_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnets_cidr[1]
  availability_zone = var.azs[1]
  tags = {
    Name                              = "Priv 2 - PagoPA VPC"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "priv_subnet_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_private_subnets_cidr[2]
  availability_zone = var.azs[2]
  tags = {
    Name                              = "Priv 3 - PagoPA VPC"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "pub_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_public_subnets_cidr[0]
  availability_zone = var.azs[0]
  tags = {
    Name                     = "Pub 1 - PagoPA VPC"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "pub_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_public_subnets_cidr[1]
  availability_zone = var.azs[1]
  tags = {
    Name                     = "Pub 2 - PagoPA VPC"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "pub_subnet_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_public_subnets_cidr[2]
  availability_zone = var.azs[2]
  tags = {
    Name                     = "Pub 3 - PagoPA VPC"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "IGW - PagoPA VPC"
  }
}

########
# Route Table + Routes
########
resource "aws_route_table" "pub_1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Pub RT - PagoPA VPC"
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
    Name = "Priv 1 RT - PagoPA VPC"
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
    Name = "Priv 2 RT - PagoPA VPC"
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
    Name = "Priv 3 RT - PagoPA VPC"
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
    Name = "EIP NAT 1 - PagoPA VPC"
  }
}

resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.pub_subnet_1.id

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT 1 - PagoPA VPC"
  }
}

resource "aws_eip" "nat_2" {
  domain = "vpc"
  tags = {
    Name = "EIP NAT 2 - PagoPA VPC"
  }
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.pub_subnet_2.id

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT 2 - PagoPA VPC"
  }
}

resource "aws_eip" "nat_3" {
  domain = "vpc"
  tags = {
    Name = "EIP NAT 3 - PagoPA VPC"
  }
}

resource "aws_nat_gateway" "nat_3" {
  allocation_id = aws_eip.nat_3.id
  subnet_id     = aws_subnet.pub_subnet_3.id

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT 3 - PagoPA VPC"
  }
}

########
# Subnet Group for DB
########
resource "aws_db_subnet_group" "rds" {
  name       = "postgresql-sbnt-group"
  subnet_ids = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-sbnt-group"
  subnet_ids = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
}

########
# Security Group for VPC Endpoints
########
resource "aws_security_group" "vpc_endpoint" {
  name   = "vpc-endpoint-sg"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "VPC Endpoint SG - PagoPA VPC"
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

  private_dns_enabled = true
  tags = {
    Name = each.value.tag_name
  }

}
