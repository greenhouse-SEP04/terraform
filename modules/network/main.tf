
# ───────────────────────────────────────────────────────────────────────────────
# 1. VPC
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "greenhouse-vpc"
  }
}

# ───────────────────────────────────────────────────────────────────────────────
# 2. Availability Zones (static for local dev)
# ───────────────────────────────────────────────────────────────────────────────
locals {
  region = var.aws_region

  availability_zones = [
    "${local.region}a",
    "${local.region}b",
  ]
}

# ───────────────────────────────────────────────────────────────────────────────
# 3. Public subnets
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${count.index}"
  }
}

# ───────────────────────────────────────────────────────────────────────────────
# 4. Private subnets
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "private-${count.index}"
  }
}