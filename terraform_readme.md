
## Terraform解説
基本的には各環境ごとに`terraform/environments/`以下にディレクトリを分けてterraform applyを実行


### メインのtfファイル
ネットワーク周りはあえてmodule化せず各環境ごとに作るようにした。
tfstateファイル名はベタ書きしているので注意。
事前にRoute53でドメイン登録と証明書を作成しておく

terraform/environments/dev/main.tf

```hashicorp
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

###########################################################
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
```

### RDS用tfファイル
aws_rds_clusterのengine_versionはAWSのGUIからとドキュメントを参考に設定する
[Aurora MySQL のバージョン番号と特殊バージョン](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/AuroraUserGuide/AuroraMySQL.Updates.Versions.html)

aws_rds_cluster_instanceのinstance_classはmysql8から最小のインスタンスタイプである`db.t3.small`が使えず`db.t3.medium`からなので注意


terraform/modules/rds/main.tf

```hashicorp
variable "env" {
  type = string
}
variable "app_name" {
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
variable "vpc_id" {
  type = string
}
variable "vpc_cidr_block" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}

### DBサブネットグループ ####################
resource "aws_db_subnet_group" "this" {
  name       = "${var.app_name}-${var.env}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

# SG
resource "aws_security_group" "rds" {
  name   = "${var.app_name}-${var.env}-rds-sg"
  vpc_id = var.vpc_id
}

# アウトバウンド(外に出る)ルール
resource "aws_security_group_rule" "rds_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

# インバウンド(受け入れる)ルール
resource "aws_security_group_rule" "rds_in_mysql" {
  type      = "ingress"
  from_port = 3306
  to_port   = 3306
  protocol  = "tcp"
  cidr_blocks = [
    var.vpc_cidr_block
  ]
  security_group_id = aws_security_group.rds.id
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.app_name}-${var.env}-db-parameter-group"
  family = "aurora-mysql8.0"
}

resource "aws_rds_cluster_parameter_group" "this" {
  name   = "${var.app_name}-${var.env}-db-cluster-parameter-group"
  family = "aurora-mysql8.0"
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_bin"
  }
  parameter {
    name         = "time_zone"
    value        = "Asia/Tokyo"
    apply_method = "immediate"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier  = "${var.app_name}-${var.env}"
  database_name       = var.db_name
  master_username     = var.db_username
  master_password     = var.db_password
  port                = 3306
  apply_immediately   = false # apply時に再起動するか
  skip_final_snapshot = true  # インスタンス削除時にスナップショットを取るかどうか
  engine              = "aurora-mysql"
  engine_version      = "8.0.mysql_aurora.3.03.1"
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]
  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
}

resource "aws_rds_cluster_instance" "this" {
  identifier         = "${var.app_name}-${var.env}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.t3.medium"
  apply_immediately  = false # apply時に再起動するか

  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.03.1"

  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = aws_db_parameter_group.this.name
}

output "endpoint" {
  value = aws_rds_cluster.this.endpoint
}
output "reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}
```

### ECS用tfファイル
aws_lb_listenerのdefault_actionはlistener_ruleが適用されずに最後に実行される表示なので、デフォルトの固定レスポンスが表示される=>想定外の表示なので503エラーを返している

ECSクラスターを削除するタイミングでlocal-execからstop-tasks.shを実行しているのは、事前にクラスターのタスク数を0にしておかないとクラスターが削除できず「aws_ecs_service.service: Still destroying...」が無限に続いてしまうので、bashから直接タスクを0に更新している

詳しくはこちらのissueが参考になる
Destroy aws_ecs_service.service on Fargate gets stuck #3414
https://github.com/hashicorp/terraform-provider-aws/issues/3414

事前にGitHub Actionsからタスク定義を作成しておくこと

terraform/modules/ecs/main.tf

```hashicorp
variable "env" {
  type = string
}
variable "app_name" {
  type = string
}
variable "app_key" {
  type = string
}
variable "db_host" {
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
variable "vpc_id" {
  type = string
}
variable "vpc_cidr_block" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "acm_cert_app_domain_arn" {
  type = string
}

### ALB ####################
### SG
resource "aws_security_group" "alb" {
  name   = "${var.app_name}-${var.env}-alb-sg"
  vpc_id = var.vpc_id
}

# アウトバウンド(外に出る)ルール
resource "aws_security_group_rule" "alb_out_all" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# インバウンド(受け入れる)ルール
resource "aws_security_group_rule" "alb_in_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_in_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb" "this" {
  name               = "${var.app_name}-${var.env}-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  port              = "80"
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.this.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "503 Service Unavailable"
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener" "https" {
  port              = "443"
  protocol          = "HTTPS"
  load_balancer_arn = aws_lb.this.arn
  certificate_arn   = var.acm_cert_app_domain_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "503 Service Unavailable"
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener_rule" "http" {
  listener_arn = aws_lb_listener.http.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.id
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  tags = {
    Name = "${var.app_name}-${var.env}-lb-listener-rule-http"
  }
}

resource "aws_lb_listener_rule" "https" {
  listener_arn = aws_lb_listener.https.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.id
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  tags = {
    Name = "${var.app_name}-${var.env}-lb-listener-rule-https"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.app_name}-${var.env}-lb-target-group"
  vpc_id      = var.vpc_id
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  health_check {
    port = 80
    path = "/api/health_check"
  }
}

### ECS ####################
## SG
resource "aws_security_group" "ecs" {
  name   = "${var.app_name}-${var.env}-sg"
  vpc_id = var.vpc_id
}

# アウトバウンド(外に出る)ルール
resource "aws_security_group_rule" "ecs_out_all" {
  security_group_id = aws_security_group.ecs.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# インバウンド(受け入れる)ルール
resource "aws_security_group_rule" "ecs_in_http" {
  security_group_id = aws_security_group.ecs.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks = [
    var.vpc_cidr_block
  ]
}

# ECSのロールはタスク定義から参照される
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-${var.env}-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_ssm" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# タスク定義はGithubActionsのCIから作成・更新する
data "aws_ecs_task_definition" "this" {
  task_definition = "${var.app_name}-${var.env}"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-${var.env}"
  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/stop-tasks.sh"
    environment = {
      CLUSTER = self.name
    }
  }
}

resource "aws_ecs_service" "this" {
  name = "${var.app_name}-${var.env}"
  depends_on = [
    aws_lb_listener_rule.http,
    aws_lb_listener_rule.https,
  ]
  cluster         = aws_ecs_cluster.this.name
  launch_type     = "FARGATE"
  desired_count   = "1"
  task_definition = data.aws_ecs_task_definition.this.arn
  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [
      aws_security_group.ecs.id
    ]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "nginx"
    container_port   = "80"
  }
}

### Cloudwatch Log ####################
resource "aws_cloudwatch_log_group" "this" {
  name              = "/${var.app_name}/ecs"
  retention_in_days = 30
}

### Parameter Store ####################
resource "aws_ssm_parameter" "app_key" {
  name  = "/${var.app_name}/${var.env}/APP_KEY"
  type  = "SecureString"
  value = var.app_key
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.app_name}/${var.env}/DB_HOST"
  type  = "SecureString"
  value = var.db_host
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.app_name}/${var.env}/DB_USERNAME"
  type  = "SecureString"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.app_name}/${var.env}/DB_PASSWORD"
  type  = "SecureString"
  value = var.db_password
}

output "lb_dns_name" {
  value = aws_lb.this.dns_name
}
output "lb_zone_id" {
  value = aws_lb.this.zone_id
}
```

terraform/modules/ecs/scripts/stop-tasks.sh

```bash
#!/bin/bash

SERVICES="$(aws ecs list-services --cluster "${CLUSTER}" | grep "${CLUSTER}" || true | sed -e 's/"//g' -e 's/,//')"
for SERVICE in $SERVICES ; do
  # Idle the service that spawns tasks
  aws ecs update-service --cluster "${CLUSTER}" --service "${SERVICE}" --desired-count 0

  # Stop running tasks
  TASKS="$(aws ecs list-tasks --cluster "${CLUSTER}" --service "${SERVICE}" | grep "${CLUSTER}" || true | sed -e 's/"//g' -e 's/,//')"
  for TASK in $TASKS; do
    aws ecs stop-task --task "$TASK"
  done

  # Delete the service after it becomes inactive
  aws ecs wait services-inactive --cluster "${CLUSTER}" --service "${SERVICE}"
  aws ecs delete-service --cluster "${CLUSTER}" --service "${SERVICE}"
done

```