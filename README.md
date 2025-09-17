# Terraform + Ansible — Bastion EC2 (Ubuntu 24.04 & Amazon Linux 2023) com SSM

Provisiona **duas EC2** (subnet pública):  
- 1x **Ubuntu 24.04** e 1x **Amazon Linux 2023**  
- **IAM Instance Profile** com `AmazonSSMManagedInstanceCore` (Session Manager)  
- **Security Group** e **Key Pair** **já existentes** (informados por ID/nome)

---

## Estrutura (resumo)

```
terraform/
├─ provider.tf
├─ main.tf
├─ sg.tf
├─ outputs.tf
└─ modules/
   ├─ iam_role/
   ├─ ubuntu_instance/
   └─ amazon_linux_instance/

ansible/
├─ ansible.cfg
├─ hosts
├─ vars.yaml
└─ roles/
   ├─ create_user/
   │  └─ tasks/
   │     ├─ main.yml        # roteia por SO
   │     ├─ ubuntu.yml      # cria user (sudo) + authorized_keys do ubuntu
   │     └─ ami.yml         # cria user (wheel) + authorized_keys do ec2-user
   └─ kubernetes/
      └─ tasks/
         ├─ main.yml        # roteia por SO
         ├─ ubuntu.yml      # instala AWS CLI v2, kubectl, eksctl, Helm
         └─ ami.yml         # instala kubectl, eksctl, Helm (AWS CLI só se faltar)
```

---

## Pré-requisitos

- Terraform **>= 1.3** | AWS Provider **~> 5.x**
- AWS CLI configurado (`aws configure`)
- VPC/Subnet pública/SG/Key Pair existentes
- **WSL** recomendado (rodar projetos em `/home/<user>`).  
  > Em diretórios **world-writable** (ex.: `/mnt/d/...`) o Ansible **ignora** `ansible.cfg`.

---

## AMIs (exemplos)

**Ubuntu 24.04 (por nome)**
```hcl
data "aws_ami" "ubuntu_24" {
  most_recent = true
  owners      = ["099720109477"]
  filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"] }
  filter { name = "virtualization-type", values = ["hvm"] }
}
```

**Amazon Linux 2023 (via SSM Parameter)**
```hcl
data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}
# usar: ami = data.aws_ssm_parameter.al2023_x86_64.value
```

---

## Terraform — como usar

```bash
cd terraform
terraform init -upgrade -reconfigure
terraform validate
terraform plan
terraform workspace new prd
terraform workspace select prd
terraform apply
```

Saídas úteis:
```bash
terraform output
# ubuntu_public_ip, amazon_linux_public_ip (entre outros)
```

SSH rápido (opcional — se porta 22 liberada):
```bash
ssh -i /home/<user>/.ssh/sua_chave.pem ubuntu@$(terraform output -raw ubuntu_public_ip)
ssh -i /home/<user>/.ssh/sua_chave.pem ec2-user@$(terraform output -raw amazon_linux_public_ip)
```
> Alternativa sem SSH exposto: **SSM Session Manager**.

---

## Ansible — pós-provisionamento

### `ansible.cfg`
> Garanta que você está **fora** de `/mnt/*`. Se preciso, coloque esta config em `~/.ansible.cfg`.

```ini
[defaults]
inventory = hosts
private_key_file = /home/<user>/.ssh/sua_chave.pem
host_key_checking = False
interpreter_python = auto_silent
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo

[ssh_connection]
pipelining = True
```

### `hosts` (exemplo)

```ini
[ubuntu]
ubuntu1 ansible_host=<IP_UBUNTU>

[ami]
ami1    ansible_host=<IP_AMI>

[ubuntu:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/home/<user>/.ssh/sua_chave.pem

[ami:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=/home/<user>/.ssh/sua_chave.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_become=true
ansible_become_method=sudo
```

### `vars.yaml`
```yaml
nome: messi
senha: 123456
```

### Roles — roteamento por SO

`roles/<role>/tasks/main.yml`
```yaml
---
# Ubuntu/Debian
- include_tasks: ubuntu.yml
  when: ansible_os_family == "Debian" or ansible_distribution == "Ubuntu"

# Amazon Linux (AL2/AL2023)
- include_tasks: ami.yml
  when:
    - ansible_os_family == "RedHat"
    - "'amazon' in (ansible_distribution | lower)"
```

**Role `create_user`**
- Ubuntu: instala `whois`, gera hash com `mkpasswd`, cria user em `sudo`, copia `/home/ubuntu/.ssh/authorized_keys`.
- AMI: instala `whois`, gera hash com `openssl passwd -6`, cria user em `wheel`, copia `/home/ec2-user/.ssh/authorized_keys`.

**Role `kubernetes`**
- Ubuntu: instala `curl`, `unzip`, `tar`, **AWS CLI v2**, `kubectl` (stable), `eksctl` (latest), `Helm` (script oficial).
- AMI 2023: **não instala `curl`** (já existe `curl-minimal`); instala `unzip`, `tar`, `gzip`, `ca-certificates`; `kubectl`, `eksctl`, `Helm`.  
  **AWS CLI v2**: instala **somente** se `aws --version` não existir.

### Playbooks

`playbook-ubuntu.yaml`
```yaml
---
- name: Criação usuario {{ nome }} (Ubuntu)
  hosts: ubuntu
  gather_facts: true
  remote_user: ubuntu
  vars_files: [vars.yaml]
  roles: [create_user]

- name: Instalação dos componentes K8s (Ubuntu)
  hosts: ubuntu
  gather_facts: true
  remote_user: "{{ nome }}"
  vars_files: [vars.yaml]
  roles: [kubernetes]
```

`playbook-ami.yaml`
```yaml
---
- name: Criação usuario {{ nome }} (AMI Linux)
  hosts: ami
  gather_facts: true
  remote_user: ec2-user
  vars_files: [vars.yaml]
  roles: [create_user]

- name: Instalação dos compoenentes Eks  (AMI Linux)
  hosts: ami
  gather_facts: true
  remote_user: "{{ nome }}"
  vars_files: [vars.yaml]
  roles: [kubernetes]
```

### Executar

```bash
cd ansible
ansible-playbook -i hosts playbook-ubuntu.yaml
ansible-playbook -i hosts playbook-ami.yaml
```

### Verificação rápida

```bash
# Usuário e grupos
ansible all -m command -a "id -nG {{ nome }}"

# Ferramentas (Ubuntu)
ansible ubuntu -b -m command -a 'aws --version'
ansible ubuntu -b -m command -a "kubectl version --client --output=yaml"
ansible ubuntu -b -m command -a "eksctl version"
ansible ubuntu -b -m command -a "helm version"

# Ferramentas (AMI)
ansible ami -b -m command -a 'aws --version || echo "AWS CLI não instalado (ok)"'
ansible ami -b -m command -a "kubectl version --client --output=yaml"
ansible ami -b -m command -a "eksctl version"
ansible ami -b -m command -a "helm version"
```

---

## Troubleshooting (curto)

- **Ansible ignora `ansible.cfg`**: você está em `/mnt/*` (world-writable). Mova para `/home/<user>/...` ou use `~/.ansible.cfg`.
- **AMI 2023 conflito de `curl`**: não instale `curl`; use `curl-minimal` padrão e instale só `unzip`, `tar`, `gzip`, `ca-certificates`.
- **Grupo `sudo` inexistente (AMI)**: use **`wheel`**.
- **Permissão da chave `.pem`**: `chmod 600 /home/<user>/.ssh/*.pem`.
- **“Skipping” no log**: normal (ramo do SO não aplicável). `include_tasks` reduz ruído.
- **Senha**: Ubuntu usa `mkpasswd` (pacote `whois`); AMI usa `openssl passwd -6`.
