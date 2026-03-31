# OIDC AWS Setup Guide

One-time setup to allow GitHub Actions to authenticate with AWS without storing
long-lived credentials. Uses OpenID Connect (OIDC) — GitHub generates a short-lived
JWT token per workflow run; AWS exchanges it for temporary credentials.

---

## Why OIDC instead of access keys?

| Static keys (`AWS_ACCESS_KEY_ID`) | OIDC |
|---|---|
| Stored as GitHub secrets indefinitely | Token generated per run, expires after 1h |
| Must be rotated manually | No rotation needed |
| Risk of leaking if secrets are exposed | Nothing to leak — no stored credentials |

---

## Step 1 — Create the OIDC Identity Provider in AWS

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --profile terraform-user
```

This only needs to be done **once per AWS account**.

Verify it was created:
```bash
aws iam list-open-id-connect-providers --profile terraform-user
```

---

## Step 2 — Create IAM roles (one per environment)

### Staging role

```bash
cat > /tmp/trust-policy-staging.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::429286308278:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:nareph/devops-pipeline-aws:environment:staging"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name github-actions-staging \
  --assume-role-policy-document file:///tmp/trust-policy-staging.json \
  --profile terraform-user
```

### Production role

```bash
cat > /tmp/trust-policy-production.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::429286308278:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:nareph/devops-pipeline-aws:environment:production"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name github-actions-production \
  --assume-role-policy-document file:///tmp/trust-policy-production.json \
  --profile terraform-user
```

> **Note:** The `sub` condition is scoped to the GitHub environment name (`staging` / `production`).
> This means only workflows running under that specific GitHub environment can assume the role.
> This is more secure than scoping to a branch alone.

---

## Step 3 — Attach permissions to the roles

Both roles need: EC2 (SSM), S3 (SSM bucket + Ansible), IAM (read instance profiles).

```bash
# Attach AWS managed policies
for ROLE in github-actions-staging github-actions-production; do
  aws iam attach-role-policy \
    --role-name $ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess \
    --profile terraform-user

  aws iam attach-role-policy \
    --role-name $ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess \
    --profile terraform-user
done

# Attach S3 access for Ansible SSM bucket
cat > /tmp/ansible-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::devops-pipeline-ansible-ssm-nareph",
      "arn:aws:s3:::devops-pipeline-ansible-ssm-nareph/*"
    ]
  }]
}
EOF

for ROLE in github-actions-staging github-actions-production; do
  aws iam put-role-policy \
    --role-name $ROLE \
    --policy-name ansible-ssm-s3 \
    --policy-document file:///tmp/ansible-s3-policy.json \
    --profile terraform-user
done
```

---

## Step 4 — Get the role ARNs

```bash
aws iam get-role --role-name github-actions-staging \
  --query 'Role.Arn' --output text --profile terraform-user

aws iam get-role --role-name github-actions-production \
  --query 'Role.Arn' --output text --profile terraform-user
```

---

## Step 5 — Add role ARNs as GitHub secrets

Go to **GitHub → Settings → Secrets and variables → Actions** and add:

| Secret name | Value |
|---|---|
| `AWS_ROLE_ARN_STAGING` | `arn:aws:iam::429286308278:role/github-actions-staging` |
| `AWS_ROLE_ARN_PRODUCTION` | `arn:aws:iam::429286308278:role/github-actions-production` |

> Remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets if they exist —
> they are no longer needed.

---

## Step 6 — Create GitHub environments

Go to **GitHub → Settings → Environments** and create:

- `staging` — no approval required (auto-deploys on push to main)
- `production` — add required reviewers (manual approval before deploy)

---

## Verify it works

After your first workflow run, confirm the role was assumed:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --region us-east-1 \
  --profile terraform-user
```
