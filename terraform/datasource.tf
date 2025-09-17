data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["iis-vpc"]
  }
}

data "aws_subnet" "public_us_east_1a" {
  filter {
    name   = "tag:Name"
    values = ["iis-subnet-public1-us-east-1a"]
  }
  vpc_id = data.aws_vpc.selected.id
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # ID do proprietário da Canonical
}


data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # ID oficial da Amazon
}
