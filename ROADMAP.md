# ROADMAP — devops-pipeline-aws

> Apprentissage pas à pas. Chaque phase a une documentation à lire,
> des objectifs clairs, et un livrable à valider avant de passer à la suivante.
>
> **Règle :** lire la doc → coder soi-même → soumettre pour review → phase suivante.

---

## Vue d'ensemble

| Phase | Sujet | Durée estimée | Statut |
|-------|-------|---------------|--------|
| 0 | Setup & Git workflow | 1 jour | ✅ Complété |
| 1 | Rust application + Docker | 2-3 jours | ✅ Complété |
| 2 | Terraform — AWS infrastructure | 5-7 jours | ✅ Complété |
| 3 | Ansible — configuration & déploiement | 4-5 jours | ✅ Complété |
| 4 | GitHub Actions — pipeline CI/CD | 3-4 jours | ✅ Complété |
| 5 | Blue/Green switch & rollback | 2-3 jours | ✅ Complété |
| 6 | Documentation & polish | 1-2 jours | ✅ Complété |

---

## Phase 0 — Setup & Git workflow ✅
**Objectif :** repo propre, structure de base, conventions établies.

### Documentation à lire
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — convention de messages de commit
- [GitHub: About branches](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-branches)
- [gitignore.io](https://www.toptal.com/developers/gitignore) — générer un `.gitignore`

### Réalisé
- [x] Repo public `devops-pipeline-aws` créé sur GitHub
- [x] README.md et ROADMAP.md initialisés
- [x] Structure de dossiers créée avec `.gitkeep`
- [x] `.gitignore` couvrant Rust, Terraform, Ansible, secrets
- [x] Branche `develop` créée — travail sur `develop`, merge sur `main` par phase
- [x] Hooks Git via pre-commit framework (conventional commits, secret detection, protection main)

### Livrables
```
devops-pipeline-aws/
├── app/.gitkeep
├── terraform/.gitkeep
├── ansible/.gitkeep
├── scripts/.gitkeep
├── docs/
├── .github/workflows/.gitkeep
├── .gitignore
├── .pre-commit-config.yaml
├── README.md
└── ROADMAP.md
```

---

## Phase 1 — Rust application + Docker ✅
**Objectif :** API Rust minimale conteneurisée, image publiée sur GHCR via CI.

### Documentation lue
- [Actix-web — Getting Started](https://actix.rs/docs/getting-started/)
- [Actix-web — Handlers](https://actix.rs/docs/handlers/)
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Working with GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Réalisé
- [x] API Actix-web avec `GET /health` et `GET /api/info`
- [x] `config.rs` lit `PORT`, `DEPLOYMENT_SLOT`, `APP_VERSION` depuis l'environnement
- [x] Pattern `build_*` séparé des handlers pour tests unitaires purs
- [x] 5 tests passent (unitaires + intégration + cohérence)
- [x] Dockerfile multi-stage `rust:alpine` → `alpine:3.21`, image **13.5 MB**
- [x] Cache des dépendances Docker (dummy `main.rs` trick)
- [x] Utilisateur non-root (`appuser/appgroup`)
- [x] Labels OCI (`source`, `description`, `license`)
- [x] Script `scripts/test-blue-green.sh` — test local des deux slots
- [x] Workflow `publish-docker-image.yml` — build multi-arch (`amd64`+`arm64`), push GHCR via `GITHUB_TOKEN`, attestation supply chain
- [x] Tags GHCR : `develop`, `latest` (main), `sha-XXXXXXX`

### Commandes utiles
```bash
# Test local
cd app && cargo test
cd app && cargo run

# Test blue/green local
./scripts/test-blue-green.sh

# Vérifier l'image GHCR
docker pull ghcr.io/nareph/devops-pipeline-aws:latest
```

---

## Phase 2 — Terraform (AWS infrastructure) ✅
**Objectif :** provisionner toute l'infra AWS depuis du code, state stocké dans S3.

### Documentation lue
- [Terraform — Core Workflow](https://developer.hashicorp.com/terraform/intro/core-workflow)
- [Terraform — Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Terraform — Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Terraform — S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Réalisé
- [x] Bucket S3 avec versioning pour Terraform state (créé manuellement — one-time)
- [x] `use_lockfile = true` — locking natif S3 (DynamoDB déprécié depuis Terraform 1.10)
- [x] Module `vpc` — VPC `10.0.0.0/16`, 2 subnets publics + 2 privés, IGW, route tables
- [x] Module `security-groups` — SG ALB (HTTP/HTTPS) + SG EC2 (port 8080 depuis ALB uniquement)
- [x] Module `ec2` — instances blue + green, Ubuntu 24.04 AMI dynamique, `t3.micro`
- [x] Module `alb` — blue/green target groups, healthcheck sur `/health:8080`, listener HTTP
- [x] Connexion via AWS SSM (pas de SSH, pas de ports ouverts)
- [x] `terraform.tfvars.example` commité, vraies valeurs dans `.gitignore`
- [x] **28 ressources créées et détruites avec succès**

### Outputs disponibles
```bash
cd terraform/environments/staging
terraform output alb_dns_name
terraform output blue_public_ip
terraform output green_public_ip
terraform output alb_listener_arn
terraform output blue_target_group_arn
terraform output green_target_group_arn
```

### Notes importantes
> **DynamoDB locking déprécié** depuis Terraform 1.10 — on utilise `use_lockfile = true`
> dans le backend S3 à la place.
>
> **`export AWS_PROFILE=terraform-user`** doit être fait avant `terraform init`
> car le backend S3 est initialisé avant le chargement des variables.

---

## Phase 3 — Ansible (configuration & déploiement) ✅
**Objectif :** configurer les serveurs et déployer l'app via des playbooks.

### Documentation lue
- [Ansible — Introduction](https://docs.ansible.com/ansible/latest/getting_started/index.html)
- [Ansible — Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html)
- [Ansible — Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html)
- [Ansible — Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [amazon.aws.aws_ec2 inventory plugin](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)

### Réalisé
- [x] Connexion via **AWS SSM Session Manager** — zéro SSH, zéro port ouvert
- [x] Inventaire dynamique `staging.aws_ec2.yml` — groupes `slot_blue` / `slot_green` via tag `Color`
- [x] Role `common` — installe Docker via script officiel
- [x] Role `app_deploy` — pull GHCR, stop ancien container, start nouveau avec `DEPLOYMENT_SLOT`
- [x] `provision.yml` — setup initial Docker sur tous les serveurs
- [x] `deploy-blue.yml` / `deploy-green.yml` — déploiement slot-spécifique
- [x] `switch-traffic.yml` — vérification `describe-target-health` avant switch ALB, détection du slot déjà actif
- [x] `rollback.yml` — détection automatique du slot actif, vérification healthcheck, bascule vers l'ancien slot
- [x] `ansible.cfg` — `interpreter_python = auto_silent`, `remote_tmp = /tmp/.ansible/tmp`

### Commandes utiles
```bash
cd ansible

# Tester l'inventaire dynamique
ansible-inventory -i inventory/staging.aws_ec2.yml --list

# Provisionner
ansible-playbook -i inventory/staging.aws_ec2.yml playbooks/provision.yml

# Déployer
ansible-playbook -i inventory/staging.aws_ec2.yml playbooks/deploy-blue.yml --limit slot_blue
ansible-playbook -i inventory/staging.aws_ec2.yml playbooks/deploy-green.yml --limit slot_green

# Switch et rollback
ansible-playbook -i inventory/staging.aws_ec2.yml playbooks/switch-traffic.yml -e "target_slot=green"
ansible-playbook -i inventory/staging.aws_ec2.yml playbooks/rollback.yml
```

---

## Phase 4 — GitHub Actions (pipeline CI/CD) ✅
**Objectif :** automatiser test → build → deploy via GitHub Actions avec OIDC.

### Documentation lue
- [GitHub Actions — Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions — Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Actions — OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [GitHub Actions — workflow_dispatch](https://docs.github.com/en/actions/using-workflows/manually-running-a-workflow)

### Réalisé
- [x] `ci.yml` — `cargo test` + `cargo clippy -D warnings` + `cargo fmt --check` sur `app/**`
- [x] `publish-docker-image.yml` — build multi-arch, push GHCR, attestation (voir Phase 1)
- [x] `deploy-staging.yml` — déclenché après `publish` sur `main` via `workflow_run`, OIDC auth, Ansible SSM, healthcheck ALB post-deploy, vérification infra avant déploiement
- [x] `deploy-prod.yml` — `workflow_dispatch` avec `target_slot` + `image_tag`, `environment: production` (approbation manuelle), deploy → healthcheck → switch-traffic → verify → **rollback auto sur `if: failure()`**
- [x] Authentification **OIDC** — pas de secrets AWS long-lived stockés dans GitHub
- [x] Cache Cargo avec `hashFiles('**/Cargo.lock')`

### Secrets GitHub à configurer
```
AWS_ROLE_ARN_STAGING      ← ARN du rôle IAM pour staging (OIDC)
AWS_ROLE_ARN_PRODUCTION   ← ARN du rôle IAM pour production (OIDC)
```

### Philosophie infra
> Le CI/CD déploie l'**application** mais ne gère pas l'infrastructure.
> Terraform est géré manuellement en local.
> Si `terraform destroy` est exécuté, le workflow échoue proprement à l'étape
> "Verify infrastructure exists" avec un message clair.

---

## Phase 5 — Blue/Green switch & rollback ✅
**Objectif :** switch de trafic ALB zero-downtime avec rollback automatique.

### Réalisé
- [x] `switch-traffic.yml` — vérification `describe-target-health` avant switch, détection slot déjà actif, switch ALB, vérification post-switch
- [x] `rollback.yml` — détection automatique du slot actif via `/health`, vérification healthcheck du slot de rollback, bascule en < 30s
- [x] Rollback automatique dans `deploy-prod.yml` via `if: failure()`
- [x] Healthcheck via `aws elbv2 describe-target-health` (pas d'accès direct EC2 — SG bloque le port 8080)

### Flux complet de déploiement production
```
1. workflow_dispatch → choisir slot (blue/green) + image_tag
2. Approbation manuelle (environment: production)
3. Deploy Ansible sur le slot INACTIF
4. describe-target-health → attendre "healthy" (200s max)
5. switch-traffic.yml → ALB pointe sur le nouveau slot
6. Vérification via ALB /health → slot attendu
7. ✅ Succès — ancien slot reste warm
8. ❌ Échec → rollback.yml automatique
```

---

## Phase 6 — Documentation & polish ✅
**Objectif :** repo présentable pour un recruteur, documentation complète.

### Réalisé
- [x] `README.md` complet — architecture, project structure, prerequisites, Terraform deploy, Ansible deploy, infrastructure lifecycle, troubleshooting, cost table
- [x] Diagrammes dans `docs/` — architecture AWS, VPC, CI/CD pipeline, SSM Session Manager
- [x] Section **Troubleshooting** — erreurs SSM communes documentées
- [x] Section **Infrastructure lifecycle** — comportement attendu si `terraform destroy`
- [x] `ROADMAP.md` mis à jour — toutes les phases cochées

---

## Conventions de commit

Format : `type(scope): description`
```
feat(app): add /health endpoint with deployment slot
feat(terraform): add VPC module with public subnets
feat(ansible): add app_deploy role with docker container
feat(ci): add GitHub Actions CI workflow
fix(ansible): fix nginx template port variable
docs: update README with architecture diagram
```

Types : `feat` · `fix` · `docs` · `refactor` · `test` · `chore` · `ci`

---

## Stack complète

| Couche | Technologie | Détail |
|--------|-------------|--------|
| Application | Rust + Actix-web | REST API, multi-stage Docker 13.5MB |
| Registry | GHCR | Multi-arch amd64+arm64, attestation supply chain |
| Infrastructure | Terraform + AWS | VPC, EC2, ALB, S3 state, SSM |
| Configuration | Ansible | Inventaire dynamique EC2, roles, SSM connection |
| CI/CD | GitHub Actions | OIDC, workflow_run chaining, rollback auto |
| Déploiement | Blue/Green | Zero-downtime, healthcheck ALB, rollback < 30s |

---

*Last updated: 2026-03-31 — Projet complété*
