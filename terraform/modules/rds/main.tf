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
