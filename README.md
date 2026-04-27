# Whale In The Cloud

A small but production-like AWS deployment project that provisions cloud infrastructure with Terraform and runs a containerized application behind Nginx.

## About The Project

This project demonstrates how to deploy a Docker-based backend application using a simple but realistic cloud architecture on AWS.

The main goals of this project were to practice:

* Infrastructure as Code with Terraform
* Docker image build and deployment
* Container orchestration with Docker Compose
* Reverse proxying and load balancing with Nginx
* Secure access using a bastion host
* Working with AWS services like EC2, VPC, and ECR

## Architecture Overview

```text
Developer machine
  ↓
Docker image build
  ↓
Amazon ECR
  ↓
Terraform-provisioned AWS infrastructure
  ↓
Bastion host (public subnet)
  ↓
Private application server (private subnet)
  ↓
Nginx reverse proxy
  ↓
api1 / api2 containers
```

### Infrastructure Components

- **Custom VPC**
- **Public and private subnets**
- **Bastion host** for controlled SSH access
- **Private application server** for running the containerized app
- **Amazon ECR** for storing the Docker image
- **NAT Gateway** for outbound internet access from private resources
- **Security groups** for network access control
- **IAM role** for AWS permissions

## Built With

- Terraform
- AWS EC2
- AWS VPC
- AWS ECR
- AWS IAM
- Docker
- Docker Compose
- Nginx
- Node.js
- Express

## Key Concepts Demonstrated

- Infrastructure as Code with Terraform
- Docker image build and deployment workflow
- Container orchestration with Docker Compose
- Reverse proxying and load balancing with Nginx
- Public/private subnet separation
- Bastion host access pattern
- Private application server design
- AWS networking fundamentals
- Security group configuration

## Getting Started

### Prerequisites

Make sure the following tools are installed and configured:

- Git
- Docker
- Terraform
- AWS CLI
- An AWS account
- An AWS key pair for EC2 access

You also need valid AWS credentials configured locally.

## Deployment Workflow

### 1. Clone The Repository

```bash
git clone https://github.com/TamasVasenszki/whale-in-the-cloud-project.git
cd whale-in-the-cloud-project
```

### 2. Create The ECR Repository

From the Terraform infrastructure directory, create the ECR repository first:

```bash
terraform init
terraform apply -target=aws_ecr_repository.app
```

### 3. Build And Push The Docker Image

Build the backend image for the target platform:

```bash
docker build --platform linux/amd64 -t <ecr-repository-url>:v1 ./backend
```

Authenticate Docker with ECR:

```bash
aws ecr get-login-password --region <aws-region> \
  | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.<aws-region>.amazonaws.com
```

Push the image:

```bash
docker push <ecr-repository-url>:v1
```

### 4. Provision The Infrastructure

Apply the Terraform configuration:

```bash
terraform apply
```

Terraform provisions the VPC, networking components, security groups, EC2 instances, IAM configuration, and deployment-related infrastructure.

### 5. Connect Through The Bastion Host

Connect to the bastion host first:

```bash
ssh -A -i <key-file> ec2-user@<bastion-public-ip>
```

Then connect from the bastion host to the private application server:

```bash
ssh ec2-user@<private-app-server-ip>
```

## Verification

### Check Running Containers

On the private application server:

```bash
sudo docker ps
```

### Test The Application Locally On The Server

```bash
curl http://localhost:8080/api/health
```

### Test From The Bastion Host

```bash
curl http://<private-app-server-ip>:8080/api/health
```

You should see responses from both backend containers over repeated requests. This confirms that Nginx is load balancing traffic between `api1` and `api2`.

## Security Considerations

- Only the bastion host is publicly accessible.
- The application server runs in a private subnet.
- SSH access to the application server goes through the bastion host.
- Application ports are not exposed directly to the public internet.
- Security groups restrict allowed traffic.
- Docker images are stored in ECR instead of being copied manually to the server.
- Terraform is used to keep infrastructure reproducible.

## Cost And Cleanup Warning

This project creates real AWS resources, which may generate costs. The NAT Gateway, EC2 instances, and other infrastructure components can incur charges while they are running.

To remove the provisioned resources:

```bash
terraform destroy
```

Always verify in the AWS Console that the resources were successfully removed.

## Testing And Quality Notes

This project currently focuses on infrastructure deployment and manual verification.

Recommended next quality improvements:

- Add automated smoke tests after deployment.
- Add CI/CD with GitHub Actions.
- Add Terraform validation and formatting checks.
- Add security scanning for Docker images.
- Add infrastructure policy checks.
- Add monitoring with Prometheus and Grafana.

## Design Decisions

### Single Terraform Configuration

The Terraform setup is intentionally kept simple instead of being split into modules. This made it easier to understand the full infrastructure flow during the learning phase.

Future iterations can refactor the infrastructure into reusable Terraform modules.

### Simple Backend Application

The backend application is intentionally minimal. The main goal of the project is to demonstrate infrastructure, deployment, networking, and containerization rather than complex business logic.

## Roadmap

- Refactor Terraform into modules
- Add CI/CD pipeline with GitHub Actions
- Add automated deployment checks
- Add PostgreSQL or another persistent data layer
- Add monitoring with Prometheus and Grafana
- Add autoscaling
- Add HTTPS termination
- Add more detailed architecture diagrams

## License

Distributed under the MIT License.

## Author

Tamás Vasenszki

- GitHub: [TamasVasenszki](https://github.com/TamasVasenszki)
- LinkedIn: [Tamás Vasenszki](https://www.linkedin.com/in/tamasvasenszki)
