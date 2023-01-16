# ECR repository for application container images
resource "aws_ecr_repository" "app_container_repo" {
  name                 = var.service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.service_name}-ecsTaskRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.service_name}-ecsTaskExecutionRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
 
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "service" {
 name                               = "${var.service_name}"
 cluster                            = local.ecs_cluster
 task_definition                    = aws_ecs_task_definition.task_def.arn
 desired_count                      = 2
 deployment_minimum_healthy_percent = 50
 deployment_maximum_percent         = 200
 launch_type                        = "FARGATE"
 scheduling_strategy                = "REPLICA"
 
 network_configuration {
   security_groups  = [local.sg]
   subnets          = local.subnets
   assign_public_ip = false
 }
 
 load_balancer {
   target_group_arn = aws_lb_target_group.alb_ecs_tg.arn
   container_name   = var.service_name
   container_port   = var.container_port
 }
 
 lifecycle {
   ignore_changes = [task_definition, desired_count]
 }
}

resource "aws_ecs_task_definition" "task_def" {
  family                   = "${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name        = "${var.service_name}"
    image       = "${var.container_image}"
    essential   = true
    portMappings = [{
      protocol      = "tcp"
      containerPort = "${var.container_port}"
      hostPort      = "${var.container_port}"
    }]
    logConfiguration: {
      logDriver: "awslogs"
      options: {
        awslogs-group: "${aws_cloudwatch_log_group.log-group.id}"
        awslogs-region: "${var.aws_region}"
        awslogs-stream-prefix: "ecs"
      }
    }
  }])

  tags = {
    project     = var.project
    environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "log-group" {
  name = "${var.service_name}-logs"
}


# Create the ALB target group for ECS.
resource "aws_lb_target_group" "alb_ecs_tg" {
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc
}

resource "aws_lb_listener_rule" "listener_rule" {
  listener_arn      = local.alb_listener

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ecs_tg.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}