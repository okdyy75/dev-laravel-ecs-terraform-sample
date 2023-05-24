terraform {
  required_version = "~> 1.4.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.65.0"
    }
  }
  backend "s3" {
    bucket  = "y-oka-ecs-dev"
    region  = "ap-northeast-1"
    key     = "y-oka-ecs-dev.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      env     = var.env
      service = var.app_name
      Name    = var.app_name
    }
  }
}

variable "env" {
  type = string
}
variable "app_domain" {
  type = string
}
variable "app_name" {
  type = string
}
variable "app_key" {
  type = string
}
variable "db_name" {
  type = string
}
variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}

output "variable_env" {
  value = var.env
}
output "variable_app_name" {
  value = var.app_name
}

############################################################
### ネットワーク 
############################################################
### VPC ####################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.app_name}-${var.env}-vpc"
  }
}

### Public ####################
## Subnet
resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "${var.app_name}-${var.env}-subnet-public-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-northeast-1c"
  cidr_block        = "10.0.2.0/24"
  tags = {
    Name = "${var.app_name}-${var.env}-subnet-public-1c"
  }
}

resource "aws_subnet" "public_1d" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-northeast-1d"
  cidr_block        = "10.0.3.0/24"
  tags = {
    Name = "${var.app_name}-${var.env}-subnet-public-1d"
  }
}

## IGW
resource "aws_internet_gateway" "main" {
  tags = {
    Name = "${var.app_name}-${var.env}-igw"
  }
}
resource "aws_internet_gateway_attachment" "igw_main_attach" {
  vpc_id              = aws_vpc.main.id
  internet_gateway_id = aws_internet_gateway.main.id
}

## RTB
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.app_name}-${var.env}-rtb-public"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1d" {
  subnet_id      = aws_subnet.public_1d.id
  route_table_id = aws_route_table.public.id
}

### Private ####################
## Subnet
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.0.10.0/24"
  tags = {
    Name = "${var.app_name}-${var.env}-subnet-private-1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-northeast-1c"
  cidr_block        = "10.0.20.0/24"
  tags = {
    Name = "${var.app_name}-${var.env}-subnet-private-1c"
  }
}

resource "aws_subnet" "private_1d" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-northeast-1d"
  cidr_block        = "10.0.30.0/24"
  tags = {
    Name = "${var.app_name}-${var.env}-subnet-private-1d"
  }
}

## NGW
resource "aws_eip" "ngw_1a" {
  vpc = true
  tags = {
    Name = "${var.app_name}-${var.env}-eip-ngw-1a"
  }
}

resource "aws_eip" "ngw_1c" {
  vpc = true
  tags = {
    Name = "${var.app_name}-${var.env}-eip-ngw-1c"
  }
}

resource "aws_eip" "ngw_1d" {
  vpc = true
  tags = {
    Name = "${var.app_name}-${var.env}-eip-ngw-1d"
  }
}

resource "aws_nat_gateway" "ngw_1a" {
  subnet_id     = aws_subnet.public_1a.id
  allocation_id = aws_eip.ngw_1a.id
  tags = {
    Name = "${var.app_name}-${var.env}-ngw-1a"
  }
}

resource "aws_nat_gateway" "ngw_1c" {
  subnet_id     = aws_subnet.public_1c.id
  allocation_id = aws_eip.ngw_1c.id
  tags = {
    Name = "${var.app_name}-${var.env}-ngw-1c"
  }
}

resource "aws_nat_gateway" "ngw_1d" {
  subnet_id     = aws_subnet.public_1d.id
  allocation_id = aws_eip.ngw_1d.id
  tags = {
    Name = "${var.app_name}-${var.env}-ngw-1d"
  }
}

## RTB
resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.app_name}-${var.env}-rtb-private-1a"
  }
}

resource "aws_route_table" "private_1c" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.app_name}-${var.env}-rtb-private-1c"
  }
}

resource "aws_route_table" "private_1d" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.app_name}-${var.env}-rtb-private-1d"
  }
}

resource "aws_route" "private_1a" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private_1a.id
  nat_gateway_id         = aws_nat_gateway.ngw_1a.id
}

resource "aws_route" "private_1c" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private_1c.id
  nat_gateway_id         = aws_nat_gateway.ngw_1c.id
}

resource "aws_route" "private_1d" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private_1d.id
  nat_gateway_id         = aws_nat_gateway.ngw_1d.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private_1c.id
}

resource "aws_route_table_association" "private_1d" {
  subnet_id      = aws_subnet.private_1d.id
  route_table_id = aws_route_table.private_1d.id
}

############################################################
### RDS 
############################################################
module "rds" {
  source         = "../../modules/rds"
  env            = var.env
  app_name       = var.app_name
  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = var.db_password
  vpc_id         = aws_vpc.main.id
  vpc_cidr_block = aws_vpc.main.cidr_block
  private_subnet_ids = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1c.id,
    aws_subnet.private_1d.id
  ]
}

############################################################
### ECS 
############################################################
module "ecs" {
  source                   = "../../modules/ecs"
  env                      = var.env
  app_name                 = var.app_name
  app_key                  = var.app_key
  db_host                  = module.rds.endpoint
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  vpc_id                   = aws_vpc.main.id
  vpc_cidr_block           = aws_vpc.main.cidr_block
  acm_cert_app_domain_arn  = data.aws_acm_certificate.app_domain.arn
  public_subnet_ids = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1c.id,
    aws_subnet.public_1d.id
  ]
  private_subnet_ids = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1c.id,
    aws_subnet.private_1d.id
  ]
}

############################################################
### Route 53
############################################################
data "aws_route53_zone" "app_domain" {
  name = var.app_domain
}

resource "aws_route53_record" "app_domain_a" {
  zone_id = data.aws_route53_zone.app_domain.zone_id
  name    = var.app_domain
  type    = "A"
  alias {
    name                   = module.ecs.lb_dns_name
    zone_id                = module.ecs.lb_zone_id
    evaluate_target_health = true
  }
}

data "aws_acm_certificate" "app_domain" {
  domain = var.app_domain
}

output "app_domain_nameserver" {
  value = join(", ", data.aws_route53_zone.app_domain.name_servers)
}
