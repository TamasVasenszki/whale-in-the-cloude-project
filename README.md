# Whale in the Cloud 🐳☁️

A small but production-like Docker-based architecture running on AWS, provisioned with Terraform.

## 🚀 Project Overview

This project demonstrates how to deploy a containerized backend application using a simple but realistic cloud architecture.

The main goals of this project were to practice:

* Infrastructure as Code with Terraform
* Docker image build and deployment
* Container orchestration with Docker Compose
* Reverse proxying and load balancing with Nginx
* Secure access using a bastion host
* Working with AWS services like EC2, VPC, and ECR

---

## 🏗️ Architecture

The infrastructure consists of:

* A custom **VPC**
* **Public and private subnets**
* A **bastion host** (publicly accessible)
* An **application server** (private, only reachable via bastion)
* An **ECR repository** for storing the Docker image
* A **NAT Gateway** for outbound internet access from private instances

### Flow

User → Bastion → Private EC2 → Nginx → API containers

---

## 🐳 Application

The application is a simple Node.js backend running in Docker containers.

* Two identical API containers (`api1`, `api2`)
* Nginx acts as a reverse proxy and load balancer
* Health endpoint:

```bash
/api/health
```

Example response:

```text
OK from api1 | DB: SKIPPED
```

---

## ⚙️ Technologies Used

* **Terraform**
* **AWS (EC2, VPC, ECR, IAM)**
* **Docker & Docker Compose**
* **Nginx**
* **Node.js (Express)**

---

## 📦 Deployment Workflow

### 1. Create ECR repository

```bash
terraform apply -target=aws_ecr_repository.app
```

### 2. Build and push Docker image

```bash
docker build --platform linux/amd64 -t <ECR_URL>:v1 ./backend

aws ecr get-login-password --region <REGION> \
  | docker login --username AWS --password-stdin <ECR_REGISTRY>

docker push <ECR_URL>:v1
```

### 3. Provision infrastructure

```bash
terraform apply
```

### 4. Connect via bastion

```bash
ssh -A -i <KEY.pem> ec2-user@<BASTION_PUBLIC_IP>
ssh ec2-user@<SERVER_PRIVATE_IP>
```

---

## 🔍 Verification

### Check running containers

```bash
sudo docker ps
```

### Test the application (server)

```bash
curl http://localhost:8080/api/health
```

### Test from bastion

```bash
curl http://<SERVER_PRIVATE_IP>:8080/api/health
```

You should see responses alternating between:

```text
api1
api2
```

→ This confirms **load balancing is working**.

---

## 🔐 Security Design

* Only the **bastion host** is publicly accessible
* The **application server is private**
* SSH access is restricted through the bastion
* Application ports are not exposed to the internet

---

## 🧠 Design Decisions

### No Terraform modules (yet)

This project is intentionally kept in a single Terraform configuration file.

The goal was to fully understand:

* Networking (VPC, subnets, routing)
* EC2 provisioning
* IAM roles and permissions
* Bootstrapping with `user_data`

After this learning phase, the project will be refactored into a modular structure.

---

## 🔄 Future Improvements

* Refactor Terraform into modules
* Add CI/CD pipeline (GitHub Actions)
* Introduce a real database (PostgreSQL)
* Add monitoring (Prometheus + Grafana)
* Use private subnets with NAT Gateway in all environments
* Add autoscaling

---

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

---

## 📌 Notes

* AWS resources are region-specific (ECR, EC2, key pairs, etc.)
* Docker image must be pushed to the correct regional ECR
* `user_data` handles automatic setup of Docker and application startup

---

## 👨‍💻 Author

Built as part of a DevOps learning journey, focusing on understanding real-world infrastructure and deployment patterns.
