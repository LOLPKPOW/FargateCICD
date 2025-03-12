# Define the ECS Auto-Scaling Target (Sets the cluster and service to scale)
resource "aws_appautoscaling_target" "ecs_service_target" {
  max_capacity       = 10  # Maximum number of tasks
  min_capacity       = 1   # Minimum number of tasks
  resource_id        = "service/${aws_ecs_cluster.apache_cluster.name}/${aws_ecs_service.apache_service.name}" # Uses the name of the cluster and service created in template
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Define Scale-Up Policy (scale out when CPU utilization is high)
resource "aws_appautoscaling_policy" "ecs_service_scale_up" {
  name                  = "scale-up"
  policy_type           = "TargetTrackingScaling"
  resource_id           = "service/${aws_ecs_cluster.apache_cluster.name}/${aws_ecs_service.apache_service.name}"
  scalable_dimension    = "ecs:service:DesiredCount"
  service_namespace     = "ecs"

  target_tracking_scaling_policy_configuration {
    target_value       = 60  # Target CPU usage percentage for scaling out
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60 # Time before scaling in/out
    scale_out_cooldown = 60
  }

  depends_on = [aws_appautoscaling_target.ecs_service_target]  # Ensure the target is created before the policy
}

# Define Scale-Down Policy (scale in when CPU utilization is low)
resource "aws_appautoscaling_policy" "ecs_service_scale_down" {
  name                  = "scale-down"
  policy_type           = "TargetTrackingScaling"
  resource_id           = "service/${aws_ecs_cluster.apache_cluster.name}/${aws_ecs_service.apache_service.name}"
  scalable_dimension    = "ecs:service:DesiredCount"
  service_namespace     = "ecs"

  target_tracking_scaling_policy_configuration {
    target_value       = 20  # Target CPU usage percentage for scaling in
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }

  depends_on = [aws_appautoscaling_target.ecs_service_target]  # Makes sure that targets are created before creating auto scaling policy
}
