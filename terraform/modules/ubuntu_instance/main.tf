resource "aws_instance" "ubuntu_24_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [var.sg_id]
  iam_instance_profile   = var.iam_instance_profile
  associate_public_ip_address = true

  # provisioner "local-exec" {
  #   command = "sleep 30; ssh-keyscan ${self.public_ip} >> ~/.ssh/known_hosts"  # Aguarda a instância iniciar antes de executar o playbook Ansible
  # }



  tags = {
    Name = "ubuntu-bastion-instance"
  }
}


