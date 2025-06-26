# GCHQ-Infrastructure-Demo
Demo of a secure, cloud-native web app built with AWS (ECS Fargate, RDS, KMS &amp; SSM), Terraform, Flask, and Auth0. Showcases Infrastructure-as-Code, secrets management, authentication, logging/monitoring, and a simple CI/CD pipeline — built quickly to demonstrate skills for the GCHQ Infrastructure Engineering Specialist role.

Below is a complete README.md you can drop straight into the root of your repository.
Feel free to tweak wording or add screenshots/diagrams, but it already hits the usual “wow”-points reviewers look for.

⸻


# GCHQ-Infrastructure-Demo 🚀  

> A two–day proof-of-concept that shows I can design, secure and automate
> cloud infrastructure – end-to-end – the way an Infrastructure Engineering
> Specialist at **GCHQ** would expect.

---

## ✨ What you’ll see

| Capability | Where | Why it matters |
|------------|-------|----------------|
| **Cloud-native infra as code** | `infra/` (Terraform 1.7) | Repeatable, reviewable, version-controlled deployments. |
| **Containerised web app** | `Dockerfile`, `app.py` | Fast, portable releases packaged for ECS Fargate. |
| **OpenID Connect login (Auth0)** | `app.py` | Modern, standards-based authentication. |
| **KMS-encrypted secret retrieval** | `app.py`, `infra/` | No hard-coded secrets – pulled securely from AWS SSM with KMS. |
| **Security telemetry → CloudWatch** | Logging + metric filters + alarms | Detect failed-login bursts; raises an alarm after 2 batches/5 min. |
| **Automated CI/CD** | `.github/workflows/deploy.yml` | Build container, push to ECR, run `terraform plan` + `apply` on every push to **main**. |
| **PostgreSQL demo data** | RDS Postgres (Terraform) | Shows I can provision, secure & query managed databases. |

<details>
<summary>Architecture diagram (click to expand)</summary>

┌─────────────┐               ┌──────────────────┐
│   Browser   │──HTTPS──────▶ │     Auth0 IdP    │
└─────────────┘               └──────────────────┘
▲                               │ OIDC
│                               ▼
┌──────────────────────── AWS ──────────────────────────┐
│  ┌──────────────────────────────────────────────────┐ │
│  │  Application Load Balancer (public)             │ │
│  │  gchq-demo-alb                                   │ │
│  └─────────────┬────────────────────────────────────┘ │
│                ▼                                      │
│     ECS Fargate service (gchq-demo-service)           │
│     • Flask app container                             │
│     • IAM task role (decrypt + SSM read only)         │
│                │                                      │
│                ▼                                      │
│     CloudWatch Logs  ──► Metric Filter ──► Alarm      │
│                │                                      │
│                ▼                                      │
│     RDS Postgres  ── demo alerts table                │
│                                                      │
└────────────────────────────────────────────────────────┘

</details>

---

## 🚀 Quick start

> **Prereqs:** Terraform ≥ 1.1, Docker ≥ 24, AWS CLI logged in to your account.

```bash
# 1. Clone and configure secrets
git clone https://github.com/ismail545/GCHQ-Infrastructure-Demo.git
cd GCHQ-Infrastructure-Demo

# local only – set once, or use TF_VAR_*
export TF_VAR_FLASK_SECRET="CHANGE_ME_32_BYTES"
export TF_VAR_OIDC_CLIENT_ID="..."
export TF_VAR_OIDC_CLIENT_SECRET="..."

# 2. Build & push container (one-liner)
docker build -t gchq-demo-app:latest .
aws ecr get-login-password --region eu-west-2 \
  | docker login --username AWS --password-stdin <account>.dkr.ecr.eu-west-2.amazonaws.com
docker tag gchq-demo-app:latest <account>.dkr.ecr.eu-west-2.amazonaws.com/gchq-demo-app:latest
docker push <account>.dkr.ecr.eu-west-2.amazonaws.com/gchq-demo-app:latest

# 3. Provision infrastructure
cd infra
terraform init
terraform apply -auto-approve

When terraform apply finishes you’ll get an ALB DNS name – open it and log in via Auth0.
Hit /test-login-failure to simulate a bad login; watch the CloudWatch metric spike. 🎉

⸻

🗄️ Repository layout

.
├── app.py                    # Flask demo application
├── Dockerfile                # Container definition
├── infra/                    # All Terraform modules
│   ├── main.tf               # VPC, ECS, RDS, CloudWatch, KMS …
│   ├── variables.tf          # Sensitive variables (no hard-codes)
│   └── outputs.tf
├── .github/
│   └── workflows/
│       └── deploy.yml        # CI/CD pipeline
└── README.md                 # You are here

```
⸻

🔒 Security notes
	•	Secrets
	•	Stored in GitHub Actions → Secrets (build stage)
	•	Stored in AWS SSM Parameter Store + KMS (runtime)
	•	Least privilege IAM – the ECS task can only decrypt its own secret and read one SSM parameter.
	•	Logging & detection – every LOGIN_FAILED line increments a metric; alarm after two batches.
	•	No hard-coded AWS creds – pipeline uses short-lived federated credentials.

⸻

🛣️ Roadmap (future improvements)

Idea	Reason
scan_logs.py security check	Parse CloudWatch logs after deploy; fail pipeline if suspicious burst > N.
ACM certificate + HTTPS listener	End-to-end TLS on the ALB.
GitHub Actions → OIDC federation	Remove static AWS keys entirely.
Snyk / trivy container scan	Show secure supply chain.
Jenkins / AWS CodePipeline flavour	Demonstrate tool-agnostic CI/CD expertise.


⸻

🗣️ Why this project matters


GCHQ’s mission relies on engineers who can translate security principles into fully-automated, reliable solutions.
Over a focused ~2 days I built, containerised, secured, deployed and instrumented this demo—including alarms and CI/CD—showing the approach I’d bring to larger, mission-critical systems.”

Thanks for reviewing – looking forward to discussing it!
Ismail Kamran 
