terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" } # for random_password
  }
}
###############################################################################
#                                  NETWORKING                                 #
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "gchq-demo-vpc"
  }
}

# ── Public subnets ───────────────────────────────────────────────────────────
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "gchq-demo-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "gchq-demo-public-b"
  }
}

# ── Internet gateway & public route table ────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "gchq-demo-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "gchq-demo-public-rt"
  }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

###############################################################################
#                                SECURITY GROUPS                              #
###############################################################################

# ── ALB security group (ingress 80 from anywhere) ────────────────────────────
resource "aws_security_group" "alb_sg" {
  name   = "gchq-demo-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── ECS task security group (5000 only from ALB) ─────────────────────────────
resource "aws_security_group" "ecs_sg" {
  name   = "gchq-demo-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = 5000
    to_port         = 5000
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
#                         LOAD BALANCER & TARGET GROUP                         #
###############################################################################

resource "aws_lb" "main" {
  name               = "gchq-demo-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = false

  tags = {
    Name = "gchq-demo-alb"
  }
}

resource "aws_lb_target_group" "tg" {
  name_prefix = "gchq-"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

###############################################################################
#                             IAM ROLE FOR ECS                                #
###############################################################################

resource "aws_iam_role" "ecs_task_exec" {
  name = "gchq-demo-ecs-task-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###############################################################################
#                           ECS TASK DEFINITION                                #
###############################################################################

resource "aws_ecs_cluster" "main" {
  name = "gchq-demo-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "gchq-demo-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([
    {
      name      = "gchq-demo-app"
      image     = "378898678389.dkr.ecr.eu-west-2.amazonaws.com/gchq-demo-app:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
        }
      ]

      environment = [
      
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/gchq-demo"
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "gchq-demo"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = "gchq-demo-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "gchq-demo-app"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.http]
}

###############################################################################
#                              CLOUDWATCH LOGS                                #
###############################################################################

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/gchq-demo"
  retention_in_days = 7
}

###############################################################################
#                 METRIC FILTER & ALARM FOR LOGIN ATTEMPTS                    #
###############################################################################

resource "aws_cloudwatch_log_metric_filter" "login_attempt_filter" {
  name           = "gchq-demo-login-attempt-filter"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
  pattern        = "LOGIN_ATTEMPT"

  metric_transformation {
    name      = "LoginAttemptCount"
    namespace = "gchq-demo"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "login_attempt_alarm" {
  alarm_name          = "gchq-demo-login-attempt-alarm"
  metric_name         = aws_cloudwatch_log_metric_filter.login_attempt_filter.metric_transformation[0].name
  namespace           = "gchq-demo"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Triggers if ≥2 login attempts in 1 minute"
  actions_enabled     = false
}

###############################################################################
#      AUTH0 ➜ EVENTBRIDGE ➜ CLOUDWATCH LOGS ➜ METRIC FILTER                 #
###############################################################################

# Fetch the current AWS account ID so we can construct the event source ARN
data "aws_caller_identity" "me" {}

# Get existing event bus
data "aws_cloudwatch_event_bus" "auth0_bus" {
  name = "aws.partner/auth0.com/dev-13zvx8spf52ydvnk-9e4aaad4-293a-4410-bf58-06092e009540/auth0.logs"
}

# Rule on that bus for failed-login and rate-limit events
resource "aws_cloudwatch_event_rule" "auth0_failed_logins" {
  name           = "auth0-failed-logins"
  event_bus_name = data.aws_cloudwatch_event_bus.auth0_bus.name
  event_pattern = jsonencode({
    source        = ["aws.partner/auth0.com/dev-13zvx8spf52ydvnk-9e4aaad4-293a-4410-bf58-06092e009540/auth0.logs"]
    "detail-type" = ["Auth0 log"]
    detail        = { type = ["f", "limit_violation"] }
  })
}

# Target = push those events into your existing log group
resource "aws_cloudwatch_event_target" "auth0_to_logs" {
  rule           = aws_cloudwatch_event_rule.auth0_failed_logins.name
  event_bus_name = data.aws_cloudwatch_event_bus.auth0_bus.name
  target_id      = "CWLogs"
  arn            = aws_cloudwatch_log_group.app_logs.arn
}

# Allow EventBridge to write to the log group
resource "aws_cloudwatch_log_resource_policy" "allow_eventbridge" {
  policy_name = "EventBridgeToLogs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "logs:PutLogEvents"
      Resource  = "${aws_cloudwatch_log_group.app_logs.arn}:*"
    }]
  })
}

# Single metric filter for all failed Auth0 login types
resource "aws_cloudwatch_log_metric_filter" "auth0_failed_filter" {
  name           = "auth0-failed-login-filter"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
  pattern        = "{ $.detail.type = \"f\" || $.detail.type = \"limit_violation\" }"

  metric_transformation {
    name      = "Auth0FailedLoginCount"
    namespace = "gchq-demo"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "auth0_failed_alarm" {
  alarm_name          = "auth0-failed-login-alarm"
  metric_name         = aws_cloudwatch_log_metric_filter.auth0_failed_filter.metric_transformation[0].name
  namespace           = "gchq-demo"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Triggers if ≥2 failed Auth0 logins in 5 mins"
  actions_enabled     = false
}

###############################################################################
#             APP-SPECIFIC FAILED LOGINS & ALARM                              #
###############################################################################

resource "aws_cloudwatch_log_metric_filter" "app_failed_login_filter" {
  name           = "app-login-failed-filter"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
  pattern        = "LOGIN_FAILED"

  metric_transformation {
    name      = "AppLoginFailedCount"
    namespace = "gchq-demo"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_failed_login_alarm" {
  alarm_name          = "app-login-failed-alarm"
  metric_name         = aws_cloudwatch_log_metric_filter.app_failed_login_filter.metric_transformation[0].name
  namespace           = "gchq-demo"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Triggers if ≥2 failed app logins in 5 mins"
  actions_enabled     = false
}

resource "aws_db_subnet_group" "demo" {
  name       = "gchq-demo-db-subnets"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "gchq-demo-db-subnets" }
}

resource "aws_security_group" "db_sg" {
  name   = "gchq-demo-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = ["82.33.26.17/32"]  # <--- YOUR PUBLIC IP
  }

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_password" "db_pass" {
  length  = 16
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier             = "gchq-demo-postgres"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "demouser"
  password               = random_password.db_pass.result
  db_subnet_group_name   = aws_db_subnet_group.demo.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true # fine for demo
  deletion_protection    = false
  tags                   = { Name = "gchq-demo-postgres" }
}

resource "aws_ssm_parameter" "db_url" {
  name   = "/gchq-demo/db-url"
  type   = "SecureString"
  key_id = "alias/aws/ssm"
  value  = "postgresql://${aws_db_instance.postgres.username}:${random_password.db_pass.result}@${aws_db_instance.postgres.address}:5432/postgres"
}

data "aws_iam_policy_document" "ecs_db_ssm" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [aws_ssm_parameter.db_url.arn]
  }
}

resource "aws_iam_policy" "ecs_db_ssm" {
  name   = "gchq-demo-ecs-db-ssm"
  policy = data.aws_iam_policy_document.ecs_db_ssm.json
}

resource "aws_iam_role_policy_attachment" "ecs_db_ssm_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = aws_iam_policy.ecs_db_ssm.arn
}
