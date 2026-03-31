# modules/vpc/main.tf

# 1. Création du VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
  }
}

# 2. Internet Gateway (pour que les subnets publics accèdent à internet)
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
  }
}

# 3. Subnets publics (un par AZ)
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Permet aux instances d'avoir une IP publique automatiquement
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.vpc_name}-public-${var.azs[count.index]}"
    Environment = var.environment
    Type        = "public"
  }
}

# 4. Subnets privés (un par AZ)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name        = "${var.vpc_name}-private-${var.azs[count.index]}"
    Environment = var.environment
    Type        = "private"
  }
}

# 5. Route Table publique (associée aux subnets publics)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # Route par défaut : tout le trafic vers internet passe par l'IGW
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.vpc_name}-rt-public"
    Environment = var.environment
  }
}

# 6. Association des subnets publics à la route table publique
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 7. Route Table privée (sans route vers internet)
# Les subnets privés n'ont pas accès direct à internet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.vpc_name}-rt-private"
    Environment = var.environment
  }
}

# 8. Association des subnets privés à la route table privée
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
