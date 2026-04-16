# CI/CD Pipeline Runbook
**Stack:** Node.js · Express · Jest · Docker · Jenkins LTS · Terraform · Ansible · GitHub · EC2 (Amazon Linux 2)

---

## 1. Repository Layout

```
cicd-pipeline/
├── app/index.js                              # Express app
├── tests/app.test.js                         # Jest + Supertest unit tests
├── Dockerfile                                # Multi-stage: test → production
├── Jenkinsfile                               # 6-stage declarative pipeline
├── jest.config.json
├── package.json
├── .dockerignore
├── .gitignore
├── terraform/
│   ├── backend.tf                            # S3 remote state + DynamoDB lock
│   ├── main.tf                               # Jenkins EC2 + App EC2 + IAM role + SGs + key pair
│   ├── variables.tf
│   ├── outputs.tf
│   └── inventory.tpl                         # Rendered → ansible/inventory.ini
└── ansible/
    ├── ansible.cfg
    ├── playbook.yml                          # Play 1: Python 3.9 | Play 2: Jenkins | Play 3: Docker
    ├── configure_jenkins.yml                 # Plugins + credentials + pipeline job
    ├── secrets.yml.example                   # Copy → secrets.yml, fill in values
    ├── templates/
    │   ├── create_credentials.groovy.j2      # registry_creds + ec2_ssh + git_credentials
    │   └── pipeline_job.xml.j2
    └── roles/
        ├── jenkins/tasks/main.yml            # Java, Jenkins, Docker, Node, AWS CLI
        └── docker/tasks/main.yml             # Docker only
```

---

## 2. Prerequisites (your laptop)

| Tool | Install |
|------|---------|
| Terraform ≥ 1.6 | https://developer.hashicorp.com/terraform/install |
| Ansible ≥ 2.14 | `pip3 install ansible` |
| AWS CLI v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |

```bash
aws configure   # enter Access Key, Secret, region, output format
```

---

## 3. Step-by-Step

### Step 1 — Push code to GitHub
```bash
cd cicd-pipeline
git init
git add .
git commit -m "initial commit"
git remote add origin https://github.com/your-username/cicd-pipeline.git
git push -u origin main
```

### Step 2 — Create S3 bucket and DynamoDB table for Terraform backend
```bash
# Create S3 bucket
aws s3api create-bucket \
    --bucket your-tfstate-bucket \
    --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket your-tfstate-bucket \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### Step 3 — Update backend.tf
Edit `terraform/backend.tf` and replace `your-tfstate-bucket` with the bucket name you just created.

### Step 4 — Update Jenkinsfile
Edit line 5 in `Jenkinsfile`:
```groovy
IMAGE_NAME = 'your-dockerhub-user/cicd-demo-app'
```
Commit and push.

### Step 5 — Provision infrastructure
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Terraform creates:
- TLS key pair → saved as `terraform/ec2_key.pem`
- Jenkins EC2 (t2.medium) with IAM role (ec2:DescribeInstances)
- App EC2 (t2.micro)
- Two security groups
- `ansible/inventory.ini` with both IPs

### Step 6 — Configure both EC2s
```bash
cd ../ansible

# Installs Python 3.9, Jenkins + tools on Jenkins EC2
# Installs Python 3.9, Docker on App EC2
ansible-playbook -i inventory.ini playbook.yml
```

### Step 7 — Fill in secrets
```bash
cp secrets.yml.example secrets.yml
# Edit secrets.yml with your real values
```

### Step 8 — Configure Jenkins
```bash
ansible-playbook -i inventory.ini configure_jenkins.yml -e @secrets.yml
```

This installs plugins, creates credentials (`registry_creds`, `ec2_ssh`, optionally `git_credentials`), and creates the pipeline job.

At the end it prints:
```
Jenkins URL : http://<JENKINS_IP>:8080
Username    : admin
Password    : <password>
Job         : cicd-demo-pipeline
```

### Step 9 — Trigger the pipeline
1. Open `http://<JENKINS_IP>:8080`
2. Log in with printed credentials
3. Click `cicd-demo-pipeline` → **Build Now**

Pipeline stages:
```
Checkout → Install/Build → Test → Docker Build → Push Image → Deploy
```

### Step 10 — Verify
```bash
curl http://<APP_IP>:3000/
# {"status":"ok","message":"CI/CD Pipeline Demo App","version":"<BUILD_NUM>"}

curl http://<APP_IP>:3000/health
# {"status":"healthy","uptime":...}
```

Or open in browser: `http://<APP_IP>:3000`

---

## 4. Jenkins Credentials Created

| ID | Type | Purpose |
|----|------|---------|
| `registry_creds` | Username/Password | Docker Hub login for push + pull |
| `ec2_ssh` | SSH Private Key | SSH into App EC2 for deployment |
| `git_credentials` | Username/Password | GitHub access (optional, private repos only) |

---

## 5. Pipeline Stages Detail

| Stage | What happens |
|-------|-------------|
| Checkout | Clones repo from GitHub |
| Install/Build | `npm ci` — installs exact dependencies |
| Test | Jest runs, JUnit XML + HTML coverage published |
| Docker Build | Multi-stage build — tests run inside, prod image output |
| Push Image | Login to Docker Hub, push `:<BUILD_NUM>` and `:latest` |
| Deploy | Discover App EC2 IP via AWS tag → SSH → pull image → swap container → health check |
| Post (always) | Remove local images from Jenkins EC2, docker logout |

---

## 6. GitHub Webhook (auto-trigger on push)

1. GitHub repo → **Settings → Webhooks → Add webhook**
2. Payload URL: `http://<JENKINS_IP>:8080/github-webhook/`
3. Content type: `application/json`
4. Event: **Just the push event**
5. Save

After this every `git push` to `main` triggers the pipeline automatically.

---

## 7. Cleanup
```bash
cd terraform
terraform destroy -auto-approve
```
Destroys both EC2s, both SGs, IAM role, and key pair.

The S3 bucket and DynamoDB table are not destroyed (they may hold state for other projects). Delete manually if needed:
```bash
aws s3 rb s3://your-tfstate-bucket --force
aws dynamodb delete-table --table-name terraform-state-lock
```

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Ansible `UNREACHABLE` | EC2 still booting | Re-run playbook, `wait_for_connection` handles it |
| Python build takes too long | Normal — compiles from source | Wait ~5 min for Play 1 to finish |
| Jenkins not reachable after playbook | Service still starting | Wait 30s, refresh browser |
| Plugin install fails | Jenkins restarted mid-install | Re-run `configure_jenkins.yml` |
| `docker: permission denied` on Jenkins | Group change needs restart | Re-run playbook, it restarts Jenkins |
| Push fails `unauthorized` | Wrong Docker Hub token | Update `secrets.yml`, re-run `configure_jenkins.yml` |
| Deploy `None` EC2 IP | Instance not running or wrong tag | Check `terraform apply` ran successfully |
| Port 3000 unreachable | SG missing inbound rule | Check `var.app_port = 3000` in `variables.tf` |

---

## 👨‍💻 Author

Furaha Justine