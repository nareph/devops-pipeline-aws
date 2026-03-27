# devops-pipeline-aws

> Production-grade blue/green deployment pipeline for a Rust microservice.
> Terraform (AWS) · Ansible · GitHub Actions · Zero-downtime · Automated rollback.

![CI](https://github.com/nareph/devops-pipeline-aws/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Status](https://img.shields.io/badge/status-in--progress-orange)

---

## What this project demonstrates

| Skill | Technology |
|-------|-----------|
| Application | Rust (Actix-web) — REST API with `/health` endpoint |
| Containerization | Docker multi-stage build |
| Infrastructure as Code | Terraform — AWS VPC, Security Groups, EC2, ALB, S3 |
| Configuration Management | Ansible — roles, playbooks, Jinja2 templates |
| CI/CD Pipeline | GitHub Actions — test, build, deploy, switch, rollback |
| Deployment Strategy | Blue/Green — zero-downtime, automated healthcheck + rollback |
| State Management | Terraform remote state — S3 with `use_lockfile` (native S3 locking) |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    GitHub Actions                    │
│  push → test → build Docker → deploy → switch ALB   │
└──────────────────┬──────────────────────────────────┘
                   │
         ┌─────────▼──────────┐
         │   Terraform (AWS)  │
         │  VPC+SG+ ALB+EC2x2 │
         └─────────┬──────────┘
                   │
        ┌──────────▼───────────┐
        │   Ansible Playbooks  │
        │  provision + deploy  │
        └──────┬───────┬───────┘
               │       │
        ┌──────▼─┐  ┌──▼─────┐
        │  BLUE  │  │ GREEN  │
        │  EC2   │  │  EC2   │
        │ :8080  │  │ :8080  │
        └──────┬─┘  └──┬─────┘
               │       │
        ┌──────▼───────▼──────┐
        │   AWS ALB (port 80) │
        │  target group switch│
        └─────────────────────┘
```


**Deployment flow:**
1. Developer pushes to `main`
2. CI runs tests + builds Docker image + pushes to GHCR
3. Manual trigger: choose slot (`blue` or `green`)
4. Ansible deploys new image to **inactive** slot
5. Healthcheck passes → ALB switches 100% traffic to new slot
6. Old slot stays warm → rollback in < 30s if anything fails

---

## Project structure

```
devops-pipeline-aws/
├── app/ ← Rust API (Actix-web)
│ ├── src/
│ │ ├── main.rs
│ │ ├── routes/
│ │ │ ├── health.rs
│ │ │ └── api.rs
│ │ └── config.rs
│ ├── Cargo.toml
│ └── Dockerfile
├── terraform/
│ ├── modules/
│ │ ├── vpc/
│ │ │ ├── main.tf
│ │ │ ├── variables.tf
│ │ │ └── outputs.tf
│ │ ├── security-groups/
│ │ │ ├── main.tf
│ │ │ ├── variables.tf
│ │ │ └── outputs.tf
│ │ ├── ec2/
│ │ │ ├── main.tf
│ │ │ ├── variables.tf
│ │ │ └── outputs.tf
│ │ └── alb/
│ │ ├── main.tf
│ │ ├── variables.tf
│ │ └── outputs.tf
│ └── environments/
│ ├── staging/
│ │ ├── backend.tf
│ │ ├── main.tf
│ │ ├── variables.tf
│ │ ├── outputs.tf
│ │ └── terraform.tfvars
│ └── production/
│ ├── backend.tf
│ ├── main.tf
│ ├── variables.tf
│ ├── outputs.tf
│ └── terraform.tfvars
├── ansible/
│ ├── inventory/
│ ├── roles/
│ │ ├── common/
│ │ ├── app_deploy/
│ │ └── nginx/
│ ├── playbooks/
│ └── ansible.cfg
├── scripts/
│ ├── switch-traffic.sh
│ ├── healthcheck.sh
│ └── rollback.sh
├── .github/
│ └── workflows/
│ ├── ci.yml
│ ├── deploy-staging.yml
│ └── deploy-prod.yml
├── docs/
│ ├── architecture.png
│ ├── DEPLOYMENT.md
│ └── RUNBOOK.md
├── ROADMAP.md
└── README.md
```

---


---

## Prerequisites & Manual Steps

### AWS — One-time setup

**1. Créer l'utilisateur IAM `terraform-user`**

Permissions requises : `AmazonEC2FullAccess`, `AmazonS3FullAccess`, `AmazonDynamoDBFullAccess`, `ElasticLoadBalancingFullAccess`, `AmazonVPCFullAccess`

Générer Access Key + Secret Key → configurer le profil AWS :

```bash
aws configure --profile terraform-user
# AWS Access Key ID: ...
# AWS Secret Access Key: ...
# Default region: us-east-1
# Default output format: json

**2. Créer le bucket S3 pour le Terraform state**
```bash
aws s3 mb s3://devops-pipeline-tfstate-nareph-20260324 \
  --region us-east-1 --profile terraform-user

aws s3api put-bucket-versioning \
  --bucket devops-pipeline-tfstate-nareph-20260324 \
  --versioning-configuration Status=Enabled \
  --region us-east-1 --profile terraform-user
```

**3. Créer la clé SSH**
```bash
aws ec2 create-key-pair \
  --key-name devops-staging-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/devops-staging-key.pem \
  --profile terraform-user

chmod 400 ~/.ssh/devops-staging-key.pem
```
**4. Configurer votre IP pour SSH**

Trouver votre IP publique :
```bash
curl -s https://checkip.amazonaws.com
```
Créer le fichier terraform/environments/staging/terraform.tfvars (ne pas committer) :
```bash
aws_region     = "us-east-1"
aws_profile    = "terraform-user"
environment    = "staging"
instance_type  = "t3.micro"
key_name       = "devops-staging-key"
my_ip          = "VOTRE_IP/32"  # ← remplacer par votre IP
```

### Terraform — déploiement
```bash
# Important : exporter le profil AWS avant terraform init
# car le backend S3 est initialisé avant le chargement des variables
export AWS_PROFILE=terraform-user

cd terraform/environments/staging
terraform init
terraform plan
terraform apply

# Détruire quand vous avez terminé (évite les frais AWS)
terraform destroy
```

### Vérification post-déploiement
```bash
# Tester l'accès SSH
ssh -i ~/.ssh/devops-staging-key.pem ubuntu@$(terraform output -raw blue_public_ip)

# Tester l'ALB (doit retourner 502 - normal car app non déployée)
curl $(terraform output -raw alb_dns_name)/health
```

### Ansible — Configuration & Deployment

**1. Activer l'environnement Python**

```bash
cd ~/projets/devops-pipeline-aws
python3 -m venv .venv
source .venv/bin/activate
pip install ansible ansible-lint
```

**2. Configurer l'inventaire**

```bash
cd ansible

# Récupérer les IPs depuis Terraform
BLUE_IP=$(cd ../terraform/environments/staging && terraform output -raw blue_public_ip)
GREEN_IP=$(cd ../terraform/environments/staging && terraform output -raw green_public_ip)
ALB_DNS=$(cd ../terraform/environments/staging && terraform output -raw alb_dns_name)

# Créer l'inventaire staging
cat > inventory/staging.ini << EOF
[blue]
blue_01 ansible_host=${BLUE_IP}

[green]
green_01 ansible_host=${GREEN_IP}

[staging:children]
blue
green

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/devops-staging-key.pem
EOF
```
**3. Provisionner les serveurs (installer Docker)**
```bash
ansible-playbook -i inventory/staging.ini playbooks/provision.yml
```
**4. Déployer l'application**
```bash
# Déployer sur Blue (premier déploiement)
ansible-playbook -i inventory/staging.ini playbooks/deploy-blue.yml

# Vérifier que l'application répond VIA L'ALB (pas directement)
# Note: L'accès direct aux EC2 est bloqué par le Security Group
curl http://${ALB_DNS}/health

# Déployer sur Green
ansible-playbook -i inventory/staging.ini playbooks/deploy-green.yml
```

**5. Blue/Green Switch**
```bash
# Basculer le trafic vers Green
ansible-playbook -i inventory/staging.ini playbooks/switch-traffic.yml -e "target_slot=green"

# Vérifier via l'ALB que le slot a bien changé
curl http://${ALB_DNS}/health

# Rollback vers Blue si nécessaire
ansible-playbook -i inventory/staging.ini playbooks/rollback.yml
```
## Quick start (local)

```bash
# 1. Clone
git clone https://github.com/nareph/devops-pipeline-aws
cd devops-pipeline-aws

# 2. Run app locally
cd app && cargo run

# 3. Test health endpoint
curl http://localhost:8080/health
```

---

## Cost

Running on AWS Free Tier: **~$0/month**
- 2x EC2 `t3.micro` (750h free/month)
- ALB (~$0.008/LCU-hour, minimal traffic)
- S3 (state bucket) 5GB, 20k GET requests
- VPC, Subnets, IGW, Route Tables	Free

> **Destroy infra when not in use:** `terraform destroy`

---

## Roadmap

See [ROADMAP.md](./ROADMAP.md) for the detailed step-by-step learning path.

**Progress:**
- [ ] Phase 0 — Project setup & Git workflow
- [ ] Phase 1 — Rust application + Docker
- [ ] Phase 2 — Terraform (AWS infrastructure)
- [ ] Phase 3 — Ansible (configuration & deployment)
- [ ] Phase 4 — GitHub Actions (CI/CD pipeline)
- [ ] Phase 5 — Blue/Green switch & rollback
- [ ] Phase 6 — Documentation & polish

---

## License

MIT © [Nareph Frank Menadjou](https://github.com/nareph)
