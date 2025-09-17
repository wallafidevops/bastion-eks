terraform {
  backend "s3" {
    bucket         = "rm-state-6189"
    key            = "bastion-eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
  }
}


# Configure the AWS Provider
provider "aws" {
  region = var.region
}

