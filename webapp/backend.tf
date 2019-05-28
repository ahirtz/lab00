terraform {
  backend "s3" {
    region         = "eu-west-1"
    key            = "webapp/terraform.tfstate"
    bucket         = "s3-terraform-bucket-499438738123"
    dynamodb_table = "terraform-state-lock-499438738123"
  }
}
