# ☁️ Greenhouse Infrastructure as Code (`terraform`)

This repository provisions **all AWS resources** for the SEP4 Greenhouse project in a *repeatable* and *cost‑aware* way.  It ships two operating modes:

* **Local development** — Cloud services are emulated with **LocalStack Pro** so you can spin up the entire stack on your laptop for free.
* **Production AWS** — When GitHub Actions is wired with real AWS credentials a single `terraform apply` stands up the same architecture in the cloud.

> **At a glance**
>
> | Layer       | Service                                           | Notes                                           |
> | ----------- | ------------------------------------------------- | ----------------------------------------------- |
> | **Network** | VPC, subnets, security groups                     | 2 AZ public & private                           |
> | **Data**    | RDS Postgres 15                                   | Secrets stored in AWS Secrets Manager           |
> | **Storage** | S3 buckets (telemetry, ML artifacts, static site) |                                                 |
> | **Compute** |  ECS Fargate back‑end API (ASP.NET Core)          | Behind an ALB                                   |
> | &           | Lambda (ML service)                               | Zip + layers, hourly retrain rule (EventBridge) |
> | **Edge**    | API Gateway HTTP API                              | `/v1/predict → Lambda` proxy                    |
> | &           | CloudFront CDN                                    | Serves React web app from S3 bucket             |

---

## Table of Contents

1. [Directory Layout](#directory-layout)
2. [Prerequisites](#prerequisites)
3. [Local Deployment (LocalStack)](#local-deployment-localstack)
4. [AWS Deployment](#aws-deployment)
5. [Module Overview](#module-overview)
6. [Variables](#variables)
7. [Outputs](#outputs)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Troubleshooting](#troubleshooting)

---

## Directory Layout

```
terraform/
├── modules/
│   ├── network/        # VPC, subnets
│   ├── rds/            # Postgres + Secrets Manager
│   ├── ecs-api/        # ECR, ECS cluster, service, task def
│   ├── lambda-ml/      # Lambda ZIP + layers + schedule
│   ├── s3-telemetry/   # Raw sensor CSV bucket
│   └── static-site/    # Web bucket + CloudFront
├── envs/               # optional *.tfvars files per environment
├── *.tf                # root config (main.tf, variables.tf, …)
└── .github/workflows/  # CD stub (commented until creds present)
```

---

## Prerequisites

* **Terraform ≥ 1.4** (`brew install terraform` or scoop/choco)
* **Docker Compose v2** (for LocalStack & Postgres via *dev‑env* repo)
* *Optional* AWS CLI v2 if you plan to inspect resources manually.

---

## Local Deployment (LocalStack)

1. **Start the emulators & database**

   ```bash
   cd path/to/your/dev-env/repo
   docker‑compose up -d localstack db
   ```

2. **Plan & apply**
From the root of this repository (the terraform/ directory), run:
   ```bash
   tflocal init -reconfigure
   tflocal apply -auto-approve -var "use_localstack=true"
   ```

   After a few minutes you should see outputs similar to:

   ```text
   Outputs:
   api_endpoint       = "greenhouse-api-alb.elb.localhost.localstack.cloud"
   website_url        = "6c8afb79.cloudfront.localhost.localstack.cloud"
   ml_lambda_arn      = "arn:aws:lambda:us-east-1:000000000000:function:greenhouse-ml"
   …
   ```

3. **Seed environment variables for LocalStack**

   ```bash
   export AWS_REGION=us-east-1
   export AWS_ACCESS_KEY_ID=test
   export AWS_SECRET_ACCESS_KEY=test
   export AWS_ENDPOINT_URL=http://localhost:4566
   alias tflocal='AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
                 terraform'
   ```

4. **Push the API image to LocalStack ECR**

   ```bash
   awslocal ecr get-login-password | \
     docker login --username AWS --password-stdin \
     000000000000.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566

   cd ../api
   docker build -t greenhouse-api:latest .
   docker tag greenhouse-api:latest \
     000000000000.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566/greenhouse-api:latest
   docker push 000000000000.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566/greenhouse-api:latest

   # kick rolling update
   awslocal ecs update-service \
     --cluster greenhouse-cluster \
     --service greenhouse-api \
     --force-new-deployment
   ```

5. **Deploy the React front‑end**

   ```bash
   cd ../web
   pnpm install && pnpm build
   awslocal s3 sync dist/ s3://greenhouse-web-site/ --delete
   DIST_ID=$(tflocal output -raw cdn_distribution_id)
   awslocal cloudfront create-invalidation \
     --distribution-id "$DIST_ID" --paths "/*"
   ```

That’s it — browse the `website_url` output and you should see the app served by CloudFront via LocalStack.

---

## AWS Deployment

With real AWS credentials and SSH secrets configured:

```bash
terraform init
terraform apply -auto-approve
```

The GitHub Actions workflow **terraform‑cd.yml** is ready to execute the same steps on every push to `main` once you uncomment the AWS steps and add credentials to the repo secrets.

---

## Module Overview

| Module           | Purpose                                                                                        | Key Resources                                                             |
| ---------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| **network**      | Baseline VPC (10.0.0.0/16), 2×public & 2×private subnets                                       | `aws_vpc`, `aws_subnet`                                                   |
| **rds**          | Postgres 15 in private subnets with random password in Secrets Manager                         | `aws_db_instance`, `aws_secretsmanager_secret`                            |
| **s3‑telemetry** | Raw CSV uploads from IoT device                                                                | `aws_s3_bucket`                                                           |
| **lambda‑ml**    | ML inference + training Lambda, layers, CloudWatch schedule                                    | `aws_lambda_function`, `aws_lambda_layer_version`                         |
| **ecs‑api**      | Fargate service for ASP.NET Core API. Pulls image from ECR and registers with ALB target group | `aws_ecr_repository`, `aws_ecs_service`, `aws_lb_target_group_attachment` |
| **static‑site**  | Public React front‑end via S3 (+ CloudFront CDN)                                               | `aws_s3_bucket`, `aws_cloudfront_distribution`                            |

---

## Variables (root `variables.tf` excerpt)

* `aws_region` — default `us-east-1`
* `use_localstack` — *bool* toggle (default `false`)
* `telemetry_bucket`, `site_bucket`, `ml_artifact_bucket` — S3 bucket names
* `mal_release_*` — GitHub release coordinates for ML zip & layers
* `db_*` — Postgres name & username (password auto‑generated)

See `variables.tf` for full list & defaults.

---

## Outputs

| Name            | Description                               |
| --------------- | ----------------------------------------- |
| `api_endpoint`  | DNS name of the Application Load Balancer |
| `website_url`   | CloudFront domain hosting React app       |
| `ml_lambda_arn` | ARN of the ML Lambda function             |
| `db_secret_arn` | Secrets Manager ARN containing RDS creds  |

---

## CI/CD Pipeline

A stubbed GitHub workflow **terraform‑cd.yml** is included.  Uncomment the steps and add ➡️ `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` repo secrets to enable *push‑to‑prod*:");
