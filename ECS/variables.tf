variable "region" {
  description = "AWS region"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "env" {
  description = "Environment (e.g., dev, stage, prod)"
  type        = string
}

variable "ecr_repo_url" {
  description = "ECR repo URL without tag"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU (e.g., 256, 512, 1024)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Fargate task memory (e.g., 512, 1024, 2048)"
  type        = string
  default     = "1024"
}

variable "container_port" {
  description = "Container (and host) port for the service"
  type        = number
  default     = 8080
}

variable "api_url" {
  description = "External API base URL"
  type        = string
  default     = "https://api.example.com"
}

variable "db_password_parameter_arn" {
  description = "ARN of SSM parameter with DB password"
  type        = string
}

# Optional permissions example
variable "extra_read_bucket" {
  description = "S3 bucket name to allow read access (optional)"
  type        = string
  default     = "my-readonly-bucket"
}

# --- Service wiring (assumes pre-existing infra) ---
variable "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the service"
  type        = list(string)
}

variable "service_security_group_id" {
  description = "Security group ID for the ECS service ENIs"
  type        = string
}

variable "alb_target_group_arn" {
  description = "Existing ALB target group ARN"
  type        = string
}

variable "desired_count" {
  description = "Number of tasks"
  type        = number
  default     = 2
}
