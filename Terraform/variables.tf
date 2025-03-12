variable "vpc_id" {
  description = "VPC ID where ECS will run"
  type        = string
}

variable "subnet_id1" {
  description = "Subnet ID for Fargate Containers"
  type        = string
}

variable "subnet_id2" {
  description = "Subnet ID 2 for Fargate Containers"
  type        = string
}

variable "subnet_id3" {
  description = "Subnet ID 3 for Fargate Containers"
  type        = string
}

variable "subnet_id4" {
  description = "Subnet ID for NAT Gateway"
  type        = string
}

variable "subnet_id5" {
  description = "Subnet ID for NAT Gateway"
  type        = string
}