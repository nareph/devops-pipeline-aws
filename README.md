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
| Infrastructure as Code | Terraform — AWS VPC, EC2, ALB, S3, DynamoDB |
| Configuration Management | Ansible — roles, playbooks, Jinja2 templates |
| CI/CD Pipeline | GitHub Actions — test, build, deploy, switch, rollback |
| Deployment Strategy | Blue/Green — zero-downtime, automated healthcheck + rollback |
| State Management | Terraform remote state — S3 + DynamoDB lock |

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
         │  VPC + ALB + EC2x2 │
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
├── app/                        ← Rust API (Actix-web)
│   ├── src/
│   │   ├── main.rs
│   │   ├── routes/
│   │   │   ├── health.rs
│   │   │   └── api.rs
│   │   └── config.rs
│   ├── Cargo.toml
│   └── Dockerfile
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── ec2/
│   │   └── alb/
│   ├── environments/
│   │   ├── staging/
│   │   └── production/
│   └── backend.tf
├── ansible/
│   ├── inventory/
│   ├── roles/
│   │   ├── common/
│   │   ├── app_deploy/
│   │   └── nginx/
│   ├── playbooks/
│   └── ansible.cfg
├── scripts/
│   ├── switch-traffic.sh
│   ├── healthcheck.sh
│   └── rollback.sh
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── deploy-staging.yml
│       └── deploy-prod.yml
├── docs/
│   ├── architecture.png
│   ├── DEPLOYMENT.md
│   └── RUNBOOK.md
├── ROADMAP.md
└── README.md
```

---

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
- S3 + DynamoDB (free tier)

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