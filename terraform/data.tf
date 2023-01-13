data "aws_vpc" "vpc" {
  tags  = {
    workload = "workload1"
  }
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_resourcegroupstaggingapi_resources" "ecs_cluster" {
  resource_type_filters = ["ecs:cluster"]
  
  tag_filter {
    key    = "workload"
    values = ["workload1"]
  }
}

data "aws_resourcegroupstaggingapi_resources" "alb" {
  resource_type_filters = ["elasticloadbalancing:loadbalancer"]
  
  tag_filter {
    key    = "workload"
    values = ["workload1"]
  }
}

data "aws_security_group" "ecs" {
  tags  = {
    workload = "workload1"
  }
}

data "aws_lb_listener" "alb_listener" {
    load_balancer_arn = data.aws_resourcegroupstaggingapi_resources.alb.resource_tag_mapping_list[0].resource_arn
    port              = 80
}

locals {
    ecs_cluster  = data.aws_resourcegroupstaggingapi_resources.ecs_cluster.resource_tag_mapping_list[0].resource_arn
    alb          = data.aws_resourcegroupstaggingapi_resources.alb.resource_tag_mapping_list[0].resource_arn
    vpc          = data.aws_vpc.vpc.id
    subnets      = data.aws_subnets.subnets.ids
    sg           = data.aws_security_group.ecs.id
    alb_listener = data.aws_lb_listener.alb_listener.arn
}