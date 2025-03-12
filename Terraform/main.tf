provider "aws" {
  region = "us-east-2"
}

# Elastic IP for NAT Gateway
resource "aws_eip" "my_nat_eip" {}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecr_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Reference existing public subnet
data "aws_subnet" "existing_public_subnet" {
  id = var.subnet_id  # The subnet ID passed as a variable
}

# Create a new subnet for NAT Gateway
resource "aws_subnet" "nat_gateway_subnet" {
  vpc_id            = var.vpc_id
  cidr_block        = "172.31.49.0/24"  # New CIDR block for the NAT Gateway
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "nat-gateway-subnet"
  }
}

# Create NAT Gateway in the new subnet
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_nat_eip.id
  subnet_id     = aws_subnet.nat_gateway_subnet.id  # Place NAT Gateway in the new subnet
}

# Reference the Internet Gateway (IG)
data "aws_internet_gateway" "default_ig" {
  filter {
    name = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

# Attach the Internet Gateway to the NAT Gateway subnet (for outbound traffic)
resource "aws_route_table" "nat_gateway_route_table" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default_ig.id  # Route outbound traffic through the IG
  }
}

# Associate the route table with the NAT Gateway subnet
resource "aws_route_table_association" "nat_gateway_association" {
  subnet_id      = aws_subnet.nat_gateway_subnet.id
  route_table_id = aws_route_table.nat_gateway_route_table.id
}

# Private Subnet Route Table for NAT Gateway access
resource "aws_route_table" "private_route_table" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my_nat_gateway.id  # Route outbound traffic through NAT Gateway
  }
}

# Associate the route table with the private subnet (to route traffic through NAT Gateway)
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = var.subnet_id  # The private subnet where the ECS tasks run
  route_table_id = aws_route_table.private_route_table.id
}

# ECS Cluster
resource "aws_ecs_cluster" "apache_cluster" {
  name = "ApacheCluster"
}

# ECS Task Execution Role to Pull ECR Images
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Project Fargate Role
resource "aws_iam_role" "ecs_project_fargate_role" {
  name = "ECSProjectFargateRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_project_fargate_role_policy" {
  role       = aws_iam_role.ecs_project_fargate_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_project_fargate_policy_additional" {
  role       = aws_iam_role.ecs_project_fargate_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for ECS Tasks
resource "aws_security_group" "apache_sg" {
  name        = "apache_sg"
  description = "Allow HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow HTTP traffic to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "apache_alb" {
  name               = "apache-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [var.subnet_id4, var.subnet_id5]
}

# Target Group for ALB
resource "aws_lb_target_group" "apache_target_group" {
  name     = "apache-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "ip"
}

# ALB Listener to forward HTTP traffic to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.apache_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apache_target_group.arn
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "apache_task" {
  family                   = "apache-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "512"
  memory                   = "1024"

  container_definitions = jsonencode([{
    name      = "apache-container"
    image     = "975050212504.dkr.ecr.us-east-2.amazonaws.com/containers/pwoodproject:latest"
    cpu       = 512
    memory    = 1024
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

# ECS Service Definition
resource "aws_ecs_service" "apache_service" {
  name            = "apache-service"
  cluster         = aws_ecs_cluster.apache_cluster.id
  task_definition = aws_ecs_task_definition.apache_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.subnet_id, var.subnet_id2]
    security_groups  = [aws_security_group.apache_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.apache_target_group.arn
    container_name   = "apache-container"
    container_port   = 80
  }

  depends_on = [aws_lb.apache_alb, aws_lb_target_group.apache_target_group, aws_lb_listener.http]
}
