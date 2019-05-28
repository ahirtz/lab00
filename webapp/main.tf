provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 2.0"
}

data "terraform_remote_state" "rs-vpc" {
  backend = "s3"

  config = {
    region = "eu-west-1"
    bucket = "s3-terraform-bucket-499438738123"
    key    = "vpc/terraform.tfstate"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "tpl" {
  template = "${file("${path.module}/userdata.tpl")}"

  vars {
    username = "Antoine"
  }
}

resource "aws_security_group" "sg_allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"

  vpc_id = "${data.terraform_remote_state.rs-vpc.aws_vpc_main_id}"

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

resource "aws_security_group_rule" "sg_ssh_rule" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = ["176.67.91.153/32"]

  security_group_id = "${aws_security_group.sg_allow_all.id}"
}

resource "aws_instance" "web" {
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
}
