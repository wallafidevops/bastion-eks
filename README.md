# Terraform — EC2 Bastion (Ubuntu 24.04 + Amazon Linux 2023) com SSM

Provisiona **duas EC2** em subnet pública:
- 1x **Ubuntu 24.04** e 1x **Amazon Linux 2023**
- **IAM Instance Profile** com `AmazonSSMManagedInstanceCore` (acesso via Session Manager)
- **Security Group** e **Key Pair** existentes (passados por ID/nome)

## Estrutura (resumo)
```
.
├─ provider.tf          # versão Terraform + provider AWS
├─ main.tf              # módulos iam_role, ubuntu_instance, amazon_linux_instance
├─ outputs.tf           # IDs e IPs públicos
└─ modules/
   ├─ iam_role/         # role + instance profile (SSM)
   ├─ ubuntu_instance/  # aws_instance + outputs
   └─ amazon_linux_instance/
```

## Pré‑requisitos
- Terraform **>= 1.3** e AWS Provider **~> 5.x**
- AWS CLI configurado (`aws configure`)
- VPC, Subnet pública, Security Group e Key Pair existentes
- Preferível rodar no **WSL (ext4)**; se usar PowerShell/NTFS, rode `terraform init -reconfigure`

## AMIs
- **Ubuntu 24.04** (filtro por nome):
  ```hcl
  data "aws_ami" "ubuntu_24" {
    most_recent = true
    owners      = ["099720109477"]
    filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"] }
    filter { name = "virtualization-type", values = ["hvm"] }
  }
  ```
- **Amazon Linux 2023** (recomendado via SSM):
  ```hcl
  data "aws_ssm_parameter" "al2023_x86_64" {
    name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
  }
  # usar: ami = data.aws_ssm_parameter.al2023_x86_64.value
  ```

## Como usar
```bash
terraform init -upgrade -reconfigure
terraform validate
terraform plan
terraform apply
```
Saídas úteis:
```bash
terraform output
# ubuntu_instance_id, ubuntu_public_ip, amazon_linux_instance_id, amazon_linux_public_ip
```

## SSH rápido (via WSL)
```bash
ssh -i /home/wallafi/.ssh/sua_chave.pem ubuntu@$(terraform output -raw ubuntu_public_ip)
ssh -i /home/wallafi/.ssh/sua_chave.pem ec2-user@$(terraform output -raw amazon_linux_public_ip)
```
> Alternativa: usar **SSM Session Manager** (sem SSH exposto).

## Dicas / Troubleshooting
- **Plugin/schema travado**: apague `.terraform/` e `.terraform.lock.hcl` → `terraform init -upgrade -reconfigure`
- **groupName + subnet**: em VPC use **`vpc_security_group_ids`** (IDs), *não* `security_groups` (nomes)
- **local-exec no Windows**: use `interpreter = ["PowerShell","-Command"]` ou chame o **WSL** (`["wsl","bash","-lc"]`)
- **AL2023 sem resultados**: use o **SSM Parameter** acima (mais robusto por região)
