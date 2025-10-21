output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "ecs_service_name" {
  value = aws_ecs_service.this.name
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.this.name
}
