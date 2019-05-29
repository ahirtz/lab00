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
    values = ["my_pretty_ami_name *"]
  }

  owners = ["499438738123"] # Canonical
}

data "template_file" "tpl" {
  template = "${file("${path.module}/userdata.tpl")}"

  vars {
    username = "Antoine"
  }
}
