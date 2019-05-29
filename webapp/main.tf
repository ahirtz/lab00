resource "aws_security_group" "sg_allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"

  vpc_id = "${data.terraform_remote_state.rs-vpc.aws_vpc_main_id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "sg_ssh_rule" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  vpc_id = "${data.terraform_remote_state.rs-vpc.aws_vpc_main_id}"
}

/* resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"

  key_name               = "webapp"
  vpc_security_group_ids = ["${aws_security_group.sg_allow_all.id}"]

  user_data                   = "${data.template_file.tpl.rendered}"
  subnet_id                   = "${data.terraform_remote_state.rs-vpc.aws_subnets_ids[0]}"
  associate_public_ip_address = true

  tags {
    Name = "HelloWorld"
  }
} */

resource "aws_launch_configuration" "as_conf" {
  name_prefix     = "web_config"
  image_id        = "${data.aws_ami.ubuntu.id}"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.sg_allow_all.id}","${aws_security_group.sg_ssh_rule.id}"]

  user_data = "${data.template_file.tpl.rendered}"

  # key_name        = "YYYY"

  lifecycle {
    create_before_destroy = "true"
  }
}

resource "aws_elb" "elb" {
  name            = "web-elb"
  subnets         = ["${data.terraform_remote_state.rs-vpc.aws_subnets_ids[0]}", "${data.terraform_remote_state.rs-vpc.aws_subnets_ids[1]}"]
  security_groups = ["${aws_security_group.sg_allow_all.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 8080
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    target              = "HTTP:8080/"
    interval            = 5
  }
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = ["${data.terraform_remote_state.rs-vpc.aws_subnets_ids[0]}", "${data.terraform_remote_state.rs-vpc.aws_subnets_ids[1]}"]

  name                      = "asg-${aws_launch_configuration.as_conf.name}"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.as_conf.name}"
  load_balancers            = ["${aws_elb.elb.id}"]

  tags = [
    {
      key                 = "Name"
      value               = "autoscaledserver"
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = "true"
  }
}
