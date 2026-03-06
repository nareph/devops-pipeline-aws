# ROADMAP — devops-pipeline-aws

> Apprentissage pas à pas. Chaque phase a une documentation à lire,
> des objectifs clairs, et un livrable à valider avant de passer à la suivante.
>
> **Règle :** lire la doc → coder soi-même → soumettre pour review → phase suivante.

---

## Vue d'ensemble

| Phase | Sujet | Durée estimée | Statut |
|-------|-------|---------------|--------|
| 0 | Setup & Git workflow | 1 jour | ⬜ À faire |
| 1 | Rust application + Docker | 2-3 jours | ⬜ À faire |
| 2 | Terraform — AWS infrastructure | 5-7 jours | ⬜ À faire |
| 3 | Ansible — configuration & déploiement | 4-5 jours | ⬜ À faire |
| 4 | GitHub Actions — pipeline CI/CD | 3-4 jours | ⬜ À faire |
| 5 | Blue/Green switch & rollback | 2-3 jours | ⬜ À faire |
| 6 | Documentation & polish | 1-2 jours | ⬜ À faire |

---

## Phase 0 — Setup & Git workflow
**Objectif :** repo propre, structure de base, conventions établies.

### Documentation à lire
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — convention de messages de commit
- [GitHub: About branches](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-branches)
- [gitignore.io](https://www.toptal.com/developers/gitignore) — générer un `.gitignore`

### À faire
- [ ] Créer le repo public `devops-pipeline-aws` sur GitHub
- [ ] Initialiser avec ce `README.md` et ce `ROADMAP.md`
- [ ] Créer les dossiers vides avec `.gitkeep` : `app/`, `terraform/`, `ansible/`, `scripts/`, `docs/`, `.github/workflows/`
- [ ] Créer un `.gitignore` (Rust + Terraform + Ansible + secrets)
- [ ] Créer la branche `develop` — tout le travail se fait sur `develop`, merge sur `main` quand une phase est complète
- [ ] Écrire les conventions dans `docs/CONTRIBUTING.md` : format des commits, nommage des branches

### Livrable
```
devops-pipeline-aws/
├── app/.gitkeep
├── terraform/.gitkeep
├── ansible/.gitkeep
├── scripts/.gitkeep
├── docs/
│   └── CONTRIBUTING.md
├── .github/workflows/.gitkeep
├── .gitignore
├── README.md
└── ROADMAP.md
```

### Critères de validation
- [ ] Repo public visible sur GitHub
- [ ] Branche `develop` créée
- [ ] `.gitignore` couvre : `target/`, `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `.env`, `*.pem`, `inventory/*.ini` (sauf exemples)

---

## Phase 1 — Rust application + Docker
**Objectif :** API Rust minimale conteneurisée, image publiée sur GHCR.

### Documentation à lire

**Rust / Actix-web**
- [Actix-web — Getting Started](https://actix.rs/docs/getting-started/)
- [Actix-web — Application](https://actix.rs/docs/application/)
- [Actix-web — Handlers](https://actix.rs/docs/handlers/)
- [serde_json — crate docs](https://docs.rs/serde_json/latest/serde_json/) — pour les réponses JSON

**Docker**
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/) — **important** pour réduire la taille de l'image Rust
- [Docker — Environment variables](https://docs.docker.com/engine/reference/commandline/run/#env)

**GHCR (GitHub Container Registry)**
- [Working with GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Structure attendue
```
app/
├── src/
│   ├── main.rs
│   ├── config.rs          ← lit les variables d'environnement
│   └── routes/
│       ├── mod.rs
│       ├── health.rs      ← GET /health
│       └── api.rs         ← GET /api/info (optionnel)
├── Cargo.toml
└── Dockerfile
```

### Endpoints à implémenter
```
GET /health
→ 200 OK
→ { "status": "ok", "version": "0.1.0", "slot": "blue", "timestamp": "..." }

GET /api/info
→ 200 OK
→ { "app": "devops-pipeline-aws", "slot": "blue" }
```

### Variables d'environnement
```
PORT=8080           (défaut: 8080)
DEPLOYMENT_SLOT=blue|green   (défaut: "local")
APP_VERSION=0.1.0
```

### Dockerfile — contraintes
- Utiliser un **multi-stage build** obligatoirement
- Stage 1 (`builder`) : image `rust:alpine` — compile le binaire
- Stage 2 (`runtime`) : image `alpine` — copie uniquement le binaire
- Image finale doit faire **< 20MB**

### Commandes de test local
```bash
# Build
docker build -t rust-api:local ./app

# Run blue
docker run -p 8080:8080 -e DEPLOYMENT_SLOT=blue rust-api:local

# Run green (autre terminal, autre port)
docker run -p 8081:8080 -e DEPLOYMENT_SLOT=green rust-api:local

# Test
curl http://localhost:8080/health
curl http://localhost:8081/health
# → les deux doivent répondre avec slot différent
```

### Livrable
- Code Rust qui compile et tourne
- `docker build` sans erreur
- Les deux endpoints répondent correctement
- Image publiée manuellement sur GHCR : `ghcr.io/nareph/devops-pipeline-aws:latest`

### Critères de validation
- [ ] `cargo test` passe (au moins 1 test unitaire sur `/health`)
- [ ] Image Docker multi-stage, taille < 20MB
- [ ] `DEPLOYMENT_SLOT` est bien lu depuis les variables d'environnement
- [ ] Image visible sur `ghcr.io/nareph/devops-pipeline-aws`

---

## Phase 2 — Terraform (AWS infrastructure)
**Objectif :** provisionner toute l'infra AWS depuis du code, state stocké dans S3.

### Documentation à lire

**Terraform — Core concepts**
- [Terraform — Introduction](https://developer.hashicorp.com/terraform/intro)
- [Terraform — Core Workflow](https://developer.hashicorp.com/terraform/intro/core-workflow) — `init` → `plan` → `apply`
- [Terraform — Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Terraform — Outputs](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Terraform — Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Terraform — Remote State (S3 backend)](https://developer.hashicorp.com/terraform/language/settings/backends/s3)

**AWS Provider**
- [AWS Provider — Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Resource: aws_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
- [Resource: aws_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)
- [Resource: aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
- [Resource: aws_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)
- [Resource: aws_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
- [Resource: aws_lb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)
- [Resource: aws_lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)

**AWS — Concepts à comprendre avant de coder**
- [VPC — What is a VPC?](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [ALB — How Application Load Balancers work](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [EC2 — Instance types](https://aws.amazon.com/ec2/instance-types/) — on utilisera `t3.micro`

### Ordre de création (important — respecter les dépendances)
```
1. S3 bucket + DynamoDB table  ← pour stocker le state Terraform
2. VPC
3. Subnets (2 public, dans 2 AZ différentes)
4. Internet Gateway
5. Route Table + associations
6. Security Groups (ALB, EC2, SSH)
7. Key Pair SSH
8. EC2 x2 (blue + green)
9. ALB
10. Target Groups x2 (blue + green)
11. ALB Listener → pointe sur blue par défaut
12. Target Group Attachments
```

### Structure attendue
```
terraform/
├── backend.tf                    ← S3 remote state config
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── alb/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── staging/
        ├── main.tf               ← appelle les modules
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars      ← NE PAS commiter les vraies valeurs
```

### Outputs importants à exporter
```hcl
# Ces outputs seront utilisés par Ansible et les scripts
output "blue_instance_ip"    { value = ... }
output "green_instance_ip"   { value = ... }
output "alb_dns_name"        { value = ... }
output "blue_target_group_arn"  { value = ... }
output "green_target_group_arn" { value = ... }
output "alb_listener_arn"    { value = ... }
```

### Commandes à maîtriser
```bash
terraform init        # initialise, télécharge providers
terraform fmt         # formate le code
terraform validate    # vérifie la syntaxe
terraform plan        # prévisualise les changements
terraform apply       # applique
terraform output      # affiche les outputs
terraform destroy     # supprime tout (important : faire après chaque session)
```

### Critères de validation
- [ ] `terraform validate` passe sans erreur
- [ ] `terraform plan` montre exactement les ressources attendues
- [ ] `terraform apply` crée l'infra sans erreur
- [ ] Les 2 EC2 sont accessibles en SSH
- [ ] L'ALB répond sur son DNS (même si les EC2 ne servent pas encore l'app)
- [ ] `terraform output` affiche les 6 valeurs listées ci-dessus
- [ ] State stocké dans S3 (vérifier dans la console AWS)
- [ ] `terraform destroy` nettoie tout proprement

---

## Phase 3 — Ansible (configuration & déploiement)
**Objectif :** configurer les serveurs et déployer l'app via des playbooks.

### Documentation à lire

**Ansible — Core concepts**
- [Ansible — Introduction](https://docs.ansible.com/ansible/latest/getting_started/index.html)
- [Ansible — Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html)
- [Ansible — Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html)
- [Ansible — Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Ansible — Variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html)
- [Ansible — Templates (Jinja2)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html)

**Modules Ansible à connaître**
- [ansible.builtin.apt](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html) — installer des paquets
- [community.docker.docker_image](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_image_module.html)
- [community.docker.docker_container](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html)
- [ansible.builtin.template](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
- [ansible.builtin.systemd](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_module.html)

### Structure attendue
```
ansible/
├── ansible.cfg                   ← config globale (inventory path, remote_user, etc.)
├── inventory/
│   ├── blue.ini                  ← IP du serveur blue (depuis terraform output)
│   ├── green.ini                 ← IP du serveur green
│   └── example.ini               ← exemple commité (sans vraies IPs)
├── roles/
│   ├── common/
│   │   └── tasks/
│   │       └── main.yml          ← installe Docker, curl, jq
│   ├── app_deploy/
│   │   ├── tasks/
│   │   │   └── main.yml          ← pull image, stop ancien container, start nouveau
│   │   ├── templates/
│   │   │   └── docker-compose.j2 ← template docker-compose avec variables
│   │   └── defaults/
│   │       └── main.yml          ← valeurs par défaut des variables
│   └── nginx/
│       ├── tasks/
│       │   └── main.yml          ← installe nginx, configure reverse proxy
│       └── templates/
│           └── nginx.conf.j2     ← template nginx avec le port de l'app
└── playbooks/
    ├── provision.yml             ← setup initial (common + nginx)
    ├── deploy-blue.yml           ← déploie sur blue
    ├── deploy-green.yml          ← déploie sur green
    └── rollback.yml              ← revert vers l'image précédente
```

### Playbooks à écrire (dans cet ordre)
```
1. provision.yml    → installe Docker et Nginx sur les 2 serveurs
2. deploy-blue.yml  → déploie l'image sur blue seulement
3. deploy-green.yml → déploie l'image sur green seulement
4. rollback.yml     → redéploie le tag précédent
```

### Commandes à maîtriser
```bash
# Tester la connexion
ansible all -i inventory/blue.ini -m ping

# Vérifier la syntaxe d'un playbook
ansible-playbook playbooks/provision.yml --syntax-check

# Dry-run (sans modifier)
ansible-playbook playbooks/provision.yml --check

# Exécution réelle
ansible-playbook playbooks/provision.yml -i inventory/blue.ini

# Passer des variables
ansible-playbook playbooks/deploy-blue.yml \
  -i inventory/blue.ini \
  -e "image_tag=abc123"

# Voir les facts d'un serveur
ansible blue -i inventory/blue.ini -m setup
```

### Critères de validation
- [ ] `ansible all -m ping` répond `pong` sur les 2 serveurs
- [ ] `provision.yml` installe Docker et Nginx sans erreur
- [ ] `deploy-blue.yml` déploie l'app sur le serveur blue
- [ ] `curl http://<blue-ip>/health` retourne `{"slot":"blue",...}`
- [ ] `deploy-green.yml` déploie sur green
- [ ] `curl http://<green-ip>/health` retourne `{"slot":"green",...}`
- [ ] `rollback.yml` fonctionne et revient au tag précédent

---

## Phase 4 — GitHub Actions (pipeline CI/CD)
**Objectif :** automatiser test → build → deploy via GitHub Actions.

### Documentation à lire

**GitHub Actions — Core concepts**
- [GitHub Actions — Understanding GitHub Actions](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions)
- [GitHub Actions — Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions — Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- [GitHub Actions — Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- [GitHub Actions — Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Actions — Manual triggers (workflow_dispatch)](https://docs.github.com/en/actions/using-workflows/manually-running-a-workflow)

**Actions utiles**
- [actions/checkout](https://github.com/actions/checkout)
- [docker/build-push-action](https://github.com/docker/build-push-action)
- [docker/login-action](https://github.com/docker/login-action)

### Workflows à créer (dans cet ordre)
```
1. ci.yml           → déclenché sur chaque push
                      jobs: test (cargo test) + lint (cargo clippy) + build Docker

2. deploy-staging.yml → déclenché sur push sur main
                        jobs: build + push GHCR + deploy ansible sur staging

3. deploy-prod.yml  → déclenché manuellement (workflow_dispatch)
                      input: target_slot (blue ou green)
                      jobs: build + push + ansible deploy + healthcheck + switch ALB
```

### Secrets à configurer dans GitHub
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
BLUE_SERVER_IP
GREEN_SERVER_IP
SSH_PRIVATE_KEY          ← clé SSH pour Ansible
GHCR_TOKEN               ← GitHub token avec write:packages
ALB_LISTENER_ARN
BLUE_TARGET_GROUP_ARN
GREEN_TARGET_GROUP_ARN
```

### Critères de validation
- [ ] `ci.yml` se déclenche sur chaque push et passe (tests + build)
- [ ] L'image Docker est poussée sur GHCR avec le tag du commit SHA
- [ ] `deploy-staging.yml` déploie automatiquement sur le serveur staging
- [ ] `deploy-prod.yml` se déclenche manuellement avec le choix du slot
- [ ] Les secrets ne sont jamais visibles dans les logs

---

## Phase 5 — Blue/Green switch & rollback
**Objectif :** implémenter le switch de trafic ALB et le rollback automatique.

### Documentation à lire

**AWS CLI — ALB**
- [AWS CLI — elbv2 modify-listener](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/modify-listener.html)
- [AWS CLI — elbv2 describe-target-health](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/describe-target-health.html)
- [ALB — Blue/Green deployments concept](https://docs.aws.amazon.com/whitepapers/latest/overview-deployment-options/bluegreen-deployments.html)

### Scripts à écrire
```bash
scripts/
├── healthcheck.sh    ← attend que /health répond 200 sur le slot cible
├── switch-traffic.sh ← modifie l'ALB listener pour pointer sur le nouveau slot
└── rollback.sh       ← repointe l'ALB vers l'ancien slot immédiatement
```

### Logique du switch (à implémenter vous-même)
```
1. Déployer sur le slot INACTIF (ex: green)
2. healthcheck.sh green → boucle jusqu'à 200 OK (timeout 5 min)
3. Si timeout → rollback.sh → exit 1
4. Si 200 OK → switch-traffic.sh green → ALB pointe sur green
5. Attendre 10 secondes
6. Vérifier que l'ALB répond correctement
7. Si échec → rollback.sh → exit 1
```

### Critères de validation
- [ ] `healthcheck.sh` retourne 0 si l'app répond, 1 après timeout
- [ ] `switch-traffic.sh blue` → tout le trafic va sur blue
- [ ] `switch-traffic.sh green` → tout le trafic va sur green
- [ ] `rollback.sh` revient au slot précédent en < 30 secondes
- [ ] Le pipeline complet deploy-prod fonctionne de bout en bout

---

## Phase 6 — Documentation & polish
**Objectif :** repo présentable pour un recruteur, documentation complète.

### À faire
- [ ] `docs/architecture.png` — diagram avec [Excalidraw](https://excalidraw.com/) ou [draw.io](https://app.diagrams.net/)
- [ ] `docs/DEPLOYMENT.md` — comment déployer pas à pas (pour un nouvel arrivant)
- [ ] `docs/RUNBOOK.md` — que faire en cas d'incident (rollback manuel, debug)
- [ ] Mettre à jour le `README.md` avec les badges CI qui passent au vert
- [ ] Mettre à jour la table de progression dans ce `ROADMAP.md`
- [ ] Ajouter des commentaires dans le code Terraform et Ansible là où c'est utile

### Critères de validation
- [ ] Un développeur qui ne connaît pas le projet peut le déployer en suivant `DEPLOYMENT.md`
- [ ] Le badge CI est vert sur le README
- [ ] Toutes les phases de ce ROADMAP sont cochées ✅

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

Types : `feat` · `fix` · `docs` · `refactor` · `test` · `chore`

---

## Comment soumettre votre travail pour review

À la fin de chaque phase :
1. Ouvrez une Pull Request de `develop` vers `main`
2. Titre : `Phase X — [nom de la phase]`
3. Description : ce que vous avez fait, les difficultés rencontrées, les questions
4. Partagez le lien de la PR pour review

---

*Last updated: 2026-03*