resource "aws_launch_configuration" "webserver" {
  count         = var.ec2_enable_cluster ? 1 : 0
  name_prefix          = "${var.project}-webserver-"
  image_id      = data.aws_ami.ubuntu-18_04.id
  instance_type = var.ec2_instance_type

  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true

  security_groups = [
    aws_security_group.webserver.id
  ]

  user_data = templatefile("provision/server-init-cluster.sh", {
    packageJson = file("provision/webserver/package.json")
    appJs       = file("provision/webserver/app.js")
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "webserver" {
  count                = var.ec2_enable_cluster ? 1 : 0
  name                 = "${var.project}-webserver"
  max_size             = 6 
  min_size             = 1
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.webserver[0].name
  health_check_type    = "EC2"
  termination_policies = ["OldestLaunchConfiguration", "OldestInstance"]
  target_group_arns    = [aws_lb_target_group.webserver[0].arn]
  vpc_zone_identifier  = aws_subnet.public[*].id

  tag {
    key                 = "Name"
    value               = "${var.project}-webserver"
    propagate_at_launch = true
  }

  tag {
    key                 = "Company"
    value               = var.company
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "webserver" {
  count              = var.ec2_enable_cluster ? 1 : 0
  name               = "${var.project}-webserver"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.project}-webserver"
      "Type" = "ALB"
    }
  )
}

resource "aws_lb_target_group" "webserver" {
  count    = var.ec2_enable_cluster ? 1 : 0
  name     = "${var.project}-webserver"
  vpc_id = aws_vpc.this.id
  port     = var.ec2_server_port
  protocol = "HTTP"
}

resource "aws_lb_listener" "webserver" {
  count             = var.ec2_enable_cluster ? 1 : 0
  load_balancer_arn = aws_lb.webserver[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver[0].arn
  }
}

output "load_balancer_dns" {
  value = aws_lb.webserver[0].dns_name
}
