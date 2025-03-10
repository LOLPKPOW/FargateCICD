variable "vpc_id" {
  description = "VPC ID where ECS will run"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Fargate"
  type        = string
}
