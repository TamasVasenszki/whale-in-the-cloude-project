terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az1 = data.aws_availability_zones.available.names[0]
  az2 = data.aws_availability_zones.available.names[1]

  app_image = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"

  name = var.project_name
}

data "aws_ssm_parameter" "al2023_base_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# --- VPC ---
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# --- Subnets ---
# Public (2 AZ)
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az1
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-az1" }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az2
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-az2" }
}

# Server (private) (2 AZ)
resource "aws_subnet" "server_az1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = local.az1
  tags              = { Name = "${local.name}-server-az1" }
}

resource "aws_subnet" "server_az2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = local.az2
  tags              = { Name = "${local.name}-server-az2" }
}

# DB (private) (2 AZ) - empty for now
resource "aws_subnet" "db_az1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = local.az1
  tags              = { Name = "${local.name}-db-az1" }
}

resource "aws_subnet" "db_az2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = local.az2
  tags              = { Name = "${local.name}-db-az2" }
}

# --- Route tables ---
# Public RT -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (single NAT to keep it simpler/cheaper)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az1.id
  tags          = { Name = "${local.name}-nat" }

  depends_on = [aws_internet_gateway.igw]
}

# Private RT -> NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

resource "aws_route" "private_internet_via_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "server_az1" {
  subnet_id      = aws_subnet.server_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "server_az2" {
  subnet_id      = aws_subnet.server_az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_az1" {
  subnet_id      = aws_subnet.db_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_az2" {
  subnet_id      = aws_subnet.db_az2.id
  route_table_id = aws_route_table.private.id
}

# --- Security Groups ---
# Bastion: SSH from your IP
resource "aws_security_group" "bastion" {
  name        = "${local.name}-sg-bastion"
  description = "SSH from my IP"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-sg-bastion" }
}

# Servers: allow 8080 ONLY from bastion SG (Easy mode)
resource "aws_security_group" "servers" {
  name        = "${local.name}-sg-servers"
  description = "Allow app access from bastion"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Nginx on 8080 from Bastion"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Optional: allow SSH from bastion (debug)
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-sg-servers" }
}

# --- IAM role for EC2 to pull from ECR ---
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ecr_read" {
  name               = "${local.name}-ec2-ecr-read"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_ecr_read.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2_ecr_read.name
}

# --- ECR repo (app) ---
resource "aws_ecr_repository" "app" {
  name         = "${local.name}-app"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name}-app" }
}

# --- AMI (Amazon Linux 2023) ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Bastion EC2 ---
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_base_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_az1.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  user_data = file("${path.module}/user_data_bastion.sh")

  tags = { Name = "${local.name}-bastion" }
}

# --- Server EC2s (2 AZ) ---
resource "aws_instance" "server_az1" {
  ami                    = data.aws_ssm_parameter.al2023_base_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.server_az1.id
  vpc_security_group_ids = [aws_security_group.servers.id]
  key_name               = var.key_pair_name

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = templatefile("${path.module}/user_data_server.sh", {
    APP_IMAGE = local.app_image
  })

  tags = { Name = "${local.name}-server-az1" }
}

resource "aws_instance" "server_az2" {
  ami                    = data.aws_ssm_parameter.al2023_base_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.server_az2.id
  vpc_security_group_ids = [aws_security_group.servers.id]
  key_name               = var.key_pair_name

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = templatefile("${path.module}/user_data_server.sh", {
    APP_IMAGE = local.app_image
  })

  tags = { Name = "${local.name}-server-az2" }
}