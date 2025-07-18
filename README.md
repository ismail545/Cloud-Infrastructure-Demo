> **Disclaimer:**  
> This is a fictional demo security dashboard built to showcase my skills — styled as if created for a GCHQ team, with no real-world data or connection to GCHQ.


# Cloud-Infrastructure-Demo
Demo of a secure, cloud-native web app built with AWS (ECS Fargate, RDS, KMS &amp; SSM), Terraform, Flask, and Auth0. Showcases Infrastructure-as-Code, secrets management, authentication, logging/monitoring, and a simple CI/CD pipeline — built quickly to demonstrate skills for IT/Infrastructure Specialist roles.

⸻


> A two–day proof-of-concept that shows I can design, secure and automate
> cloud infrastructure – end-to-end 

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



⸻


<details>
  <summary><strong>Architecture diagram (click to expand)</strong></summary>


![image](https://github.com/user-attachments/assets/b2de6aab-403e-44b2-b39d-ade03b61a1c6)


</details>



⸻

## 🚀 Quick start

### Prerequisites
- **Terraform ≥ 1.1**
- **Docker ≥ 24**
- **AWS CLI** logged into your account (`aws configure`)

---

### 1. Clone and configure secrets
```bash
git clone https://github.com/ismail545/Cloud-Infrastructure-Demo.git
cd Cloud-Infrastructure-Demo

# Set secrets as env vars so Terraform can pick them up
export TF_VAR_FLASK_SECRET="CHANGE_ME_32_BYTES"
export TF_VAR_OIDC_CLIENT_ID="your-client-id"
export TF_VAR_OIDC_CLIENT_SECRET="your-client-secret"
```

### 2. Build & push container to your ECR
```bash
docker build -t cloud-demo-app:latest .
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin <account>.dkr.ecr.eu-west-2.amazonaws.com
docker tag cloud-demo-app:latest <account>.dkr.ecr.eu-west-2.amazonaws.com/cloud-demo-app:latest
docker push <account>.dkr.ecr.eu-west-2.amazonaws.com/cloud-demo-app:latest
```
### 3. Provision infra
```bash
cd infra
terraform init
terraform apply -auto-approve
```
#### After terraform finishes, visit the ALB output URL
#### log in via Auth0 and hit /test-login-failure to test failed login metric


⸻

🗄️ Repository layout

```
├── app.py                    # Flask demo app
├── Dockerfile                # Container build config
├── infra/                    # Terraform IaC
│   ├── main.tf               # VPC, ECS, RDS, CloudWatch, KMS …
│   ├── variables.tf          # Sensitive vars
│   └── outputs.tf            # Export ALB URL, DB address, etc.
├── .github/workflows/
│   └── deploy.yml            # GitHub Actions CI/CD pipeline
├── README.md                 # Project overview
```

⸻

## 🔒 Security Notes

- **Secrets**  
  - **Build-time:** GitHub Actions secrets  
  - **Run-time:** AWS SSM + KMS (ECS role can only decrypt its own secret)
- **Least privilege:** ECS task role restricted to `ssm:GetParameter` and `kms:Decrypt`  
- **No hardcoded credentials:** CI/CD pipeline assumes short-lived AWS credentials only  
- **Logging & detection:** Failed logins emit `LOGIN_FAILED` events to CloudWatch; metric filter raises alarm if ≥2 events in 5 mins
⸻

## 🛣️ Roadmap & Future Improvements

| Idea                                | Reason                                              |
|-------------------------------------|-----------------------------------------------------|
| scan_logs.py post-deploy check      | Parse CloudWatch logs for suspicious patterns       |
| ACM + HTTPS listener                 | End-to-end encryption with trusted certificates     |
| GitHub Actions → OIDC federation     | Remove static AWS credentials entirely             |
| Snyk/Trivy container scan            | Shift-left security on image build                 |
| AWS CodePipeline alternative demo    | Show you can adapt to other tools too               |


⸻

Over ~2 days I built, containerised, secured, deployed and instrumented this demo — including alarms and CI/CD — showcasing my ability to deliver similar solutions at scale.

Thanks for reviewing — I look forward to discussing it further!
— Ismail Kamran

