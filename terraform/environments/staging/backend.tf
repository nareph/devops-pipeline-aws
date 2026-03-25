terraform {
  backend "s3" {
    # Nom du bucket
    bucket = "devops-pipeline-tfstate-nareph-20260324"

    # Clé unique pour cet environnement
    key = "environments/staging/terraform.tfstate"

    # Région où se trouve le bucket
    region = "us-east-1"

    # Active le locking via fichier .tflock
    use_lockfile = true

    # Chiffrement côté serveur
    encrypt = true
  }
}
