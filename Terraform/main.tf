provider "aws" {
  region = "us-east-2"
}

# Create a new VPC
resource "aws_vpc" "new_vpc" {
  cidr_block = var.vpc_id
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "new-vpc"
  }
}

# Create subnets for ECS containers (private subnets)
resource "aws_subnet" "container_subnet_1" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = var.subnet_id1
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = false
  tags = {
    Name = "container-subnet-1"
  }
}

resource "aws_subnet" "container_subnet_2" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = var.subnet_id2
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = false
  tags = {
    Name = "container-subnet-2"
  }
}

resource "aws_subnet" "container_subnet_3" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = var.subnet_id3
  availability_zone = "us-east-2c"
  map_public_ip_on_launch = false
  tags = {
    Name = "container-subnet-3"
  }
}

# Create 2 public subnets for NAT Gateway and ALB
resource "aws_subnet" "public_subnet1" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = var.subnet_id4
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id            = aws_vpc.new_vpc.id
  cidr_block        = var.subnet_id5
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "my_nat_eip" {}

# Create a NAT Gateway in the public subnet
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id
}

# Create the Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.new_vpc.id
}

# Route table for the public subnet to route traffic through the Internet Gateway
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.new_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# Associate the public subnet with the route table
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Route table for the container subnets to route traffic through the NAT Gateway
resource "aws_route_table" "container_route_table" {
  vpc_id = aws_vpc.new_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my_nat_gateway.id
  }
}

# Associate the container subnets with the NAT Gateway route table
resource "aws_route_table_association" "container_subnet_1_association" {
  subnet_id      = aws_subnet.container_subnet_1.id
  route_table_id = aws_route_table.container_route_table.id
}

resource "aws_route_table_association" "container_subnet_2_association" {
  subnet_id      = aws_subnet.container_subnet_2.id
  route_table_id = aws_route_table.container_route_table.id
}

resource "aws_route_table_association" "container_subnet_3_association" {
  subnet_id      = aws_subnet.container_subnet_3.id
  route_table_id = aws_route_table.container_route_table.id
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

# Attach ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow HTTP traffic to the ALB"
  vpc_id      = aws_vpc.new_vpc.id

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

# ECS Security Group for the containers
resource "aws_security_group" "apache_sg" {
  name        = "apache_sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.new_vpc.id

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
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id, aws_subnet.public_subnet3.id]
}

# Target Group for ALB to forward traffic on port 80
resource "aws_lb_target_group" "apache_target_group" {
  name     = "apache-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.new_vpc.id

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
  requires_compatibilities = ["FARGATE"] # Use Fargate
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "512"
  memory                   = "1024"

  # Exposed port 80 for the container
  container_definitions = jsonencode([{
    name      = "apache-container"
    image     = var.docker_image
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

  # Specify which subnets can hold the containers
  network_configuration {
    subnets          = [
      aws_subnet.container_subnet_1.id,
      aws_subnet.container_subnet_2.id,
      aws_subnet.container_subnet_3.id
    ]
    security_groups  = [aws_security_group.apache_sg.id]
    assign_public_ip = false
  }

  # Target Group for the Load Balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.apache_target_group.arn
    container_name   = "apache-container"
    container_port   = 80
  }

  depends_on = [aws_lb.apache_alb, aws_lb_target_group.apache_target_group, aws_lb_listener.http] # Don't create until specified resources complete
}
