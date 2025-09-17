# main.tf (root)
module "iam" {
  source = "./modules/iam_role"
  iam_name = terraform.workspace
}

module "ubuntu_instance" {
  source               = "./modules/ubuntu_instance"
  vpc_id               = data.aws_vpc.selected.id
  subnet_id            = data.aws_subnet.public_us_east_1a.id
  sg_id                = aws_security_group.ec2_security_group.id
  instance_type        = "t2.micro"
  ami                  = data.aws_ami.ubuntu.id
  iam_instance_profile = module.iam.iam_instance_profile_name
  key_name             = "ansible_2"
}

module "amazon_linux_instance" {
  source               = "./modules/amazon_linux_instance"
  vpc_id               = data.aws_vpc.selected.id
  subnet_id            = data.aws_subnet.public_us_east_1a.id
  sg_id                = aws_security_group.ec2_security_group.id
  instance_type        = "t2.micro"
  ami                  = data.aws_ami.amazon_linux_2023.id
  iam_instance_profile = module.iam.iam_instance_profile_name
  key_name             = "ansible_2"
}
