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
  region = var.region
}

locals {
  name_prefix = "${var.app_name}-${var.env}" # e.g., myapp-prod
  cw_log_group = "/ecs/${local.name_prefix}"
}

# -------------------------
# CloudWatch Log Group
# -------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = local.cw_log_group
  retention_in_days = 30
}

# -------------------------
# IAM: Execution role (pulls image, writes logs)
# -------------------------
data "aws_iam_policy_document" "ecs_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume_role.json
}

# AWS managed policy for ECR pull + CW logs
resource "aws_iam_role_policy_attachment" "execution_ecr" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Optional: extra permissions for execution (e.g., pull from private registry, KMS for log encryption)
# resource "aws_iam_role_policy" "execution_extra" { ... }

# -------------------------
# IAM: Task role (what the CONTAINER can do at runtime)
# -------------------------
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Example: minimal inline policy (read a specific SSM parameter & S3 bucket)
data "aws_iam_policy_document" "task_inline" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [var.db_password_parameter_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.extra_read_bucket}",
      "arn:aws:s3:::${var.extra_read_bucket}/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_inline" {
  name   = "${local.name_prefix}-task-inline"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_inline.json
}

# -------------------------
# ECS Task Definition
# -------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu        # e.g., "512"
  memory                   = var.task_memory     # e.g., "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64" # or "ARM64" if using Graviton images
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.ecr_repo_url}:${var.image_tag}" # e.g., 123456789012.dkr.ecr.eu-west-1.amazonaws.com/myapp:1.2.3
      essential = true

      portMappings = [{
        containerPort = var.container_port      # e.g., 8080
        hostPort      = var.container_port      # Fargate: usually same as containerPort
        protocol      = "tcp"
      }]

      environment = [
        { name = "NODE_ENV", value = var.env },
        { name = "API_URL",  value = var.api_url }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = var.db_password_parameter_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.cw_log_group
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = "${local.name_prefix}-svc"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.service_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [task_definition] # Let rolling deploys happen with new revisions
  }
}
