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
