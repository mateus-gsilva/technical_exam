# technical_exam

This project was created as part of a technical interview.

Before running Terraform, adjust `terraform/terraform.tfvars` to your needs (e.g., `aws_region`, VPC CIDR/subnets, EKS endpoint access, and node group sizing).

This repository contains:
- Infrastructure (VPC + EKS + add-ons) provisioned with Terraform
- A simple NGINX demo app (Hello World) packaged as a Docker image
- A GitHub Actions pipeline to build/push to GHCR and deploy to EKS via `kubectl set image`

## Scope covered
- Create an EKS cluster with Observability (Prometheus and Grafana) using Terraform
- Create a simple application (Hello World) to demonstrate observability
- Expose the application externally
- Publish the project on GitHub
- Create an optional CI/CD pipeline for build/push and deploy

## Structure
- `terraform/`: VPC + EKS + Helm releases (kube-prometheus-stack and nginx)
- `terraform/helm/`: chart values (`nginx_bitnami.yaml`, `kube-prometheus-stack.yaml`)
- `app/`: `Dockerfile`, `.dockerignore`, and `index.html`
- `.github/workflows/docker-build.yml`: build/push + deploy

## Prerequisites
- AWS CLI configured locally (to run Terraform): `aws configure`
- Terraform installed
- `kubectl` installed
- AWS credentials with permission to create VPC/EKS/EC2/IAM/ELB resources

## Provision (Terraform)

From `terraform/`:

```bash
cd terraform
terraform init
terraform apply
```

Useful outputs (after apply):

```bash
terraform output kubectl_context_command
terraform output demo_app_service_url
```

> For testing, the NGINX LoadBalancer address (DNS/IP) appears in the `demo_app_service_url` output.

## What Terraform creates (overview)

### VPC
Defined in `terraform/main.tf` using `terraform-aws-modules/vpc/aws`.

Main provisioned components:
- VPC with CIDR defined in `terraform/terraform.tfvars`
- Public and private subnets (multi-AZ)
- Internet Gateway (ingress/egress through public subnets)
- NAT Gateway (egress to the internet from private subnets)
- Route tables and associations
- Database subnets/subnet group (enabled in the module; useful for future extensions)

Rationale:
- EKS nodes run in private subnets; the NLB (Service type LoadBalancer) uses public subnets for external exposure.

### EKS
Defined in `terraform/main.tf` using `terraform-aws-modules/eks/aws`.

What is created/configured:
- EKS cluster with configurable Kubernetes version
- Public/private endpoint access driven by variables (for this test the endpoint may be public; see “Security notes”)
- Managed Node Group (defined in `terraform/terraform.tfvars`)
- Essential EKS add-ons (e.g., `vpc-cni`, `coredns`, `kube-proxy`, `metrics-server`) configured via `eks_addons`
- Cluster access rules via `access_entries` (EKS Access Entries)

### Observability (Prometheus + Grafana)
Implemented using `aws-ia/eks-blueprints-addons/aws` in `terraform/main.tf`.

This module installs the `kube-prometheus-stack` chart (Prometheus Operator), which includes:
- Prometheus
- Grafana
- Exporters and other stack components

Chart configuration:
- Values in `terraform/helm/kube-prometheus-stack.yaml` (e.g., in this project: `alertmanager.enabled: false`)

### Demo app (NGINX via Helm)
Defined in `terraform/main.tf` as `helm_release.demo_app` using the Bitnami `nginx` chart.

What this release provides:
- NGINX Deployment/Service in the `nginx` namespace
- A `LoadBalancer` Service (configured in `terraform/helm/nginx_bitnami.yaml`) which creates an AWS NLB
- The external address is exposed via `terraform output demo_app_service_url`

Relation to the pipeline:
- Ideally, this kind of image update would be handled via **GitOps** (e.g., Argo CD/Flux) by updating declarative manifests in the repo.
- For simplicity (and to keep CI/CD optional and short), this implementation uses `kubectl set image` on the `demo-app` Deployment.
- In other words: Helm creates the “skeleton” (Deployment/Service/LB) and CI/CD updates the image used by the Deployment.

## Pipeline (build/push + deploy)

The workflow lives in `.github/workflows/docker-build.yml`.

### Build + Push to GHCR
- On `push` to the `main` branch, the pipeline:
  - builds the image from `app/`
  - pushes to `ghcr.io/<owner>/<repo>`
  - publishes tags:
    - `:<sha>`
    - `:<run_number>` (sequential per workflow run)

### Deploy to EKS
The `deploy` job runs on `push` to `main` and executes:
- `kubectl set image deployment/demo-app ...`
- `kubectl rollout status ...`

At the end of the deploy, the pipeline also queries the `demo-app` Service and writes the LoadBalancer URL to the GitHub Actions **Job Summary** (when available).

It authenticates to the cluster using a ServiceAccount token (via GitHub Secrets).

## Configure GitHub access to the cluster

The deploy uses 3 GitHub Secrets:
- `K8S_SERVER`: Kubernetes API endpoint
- `K8S_CA`: `certificate-authority-data` (base64)
- `K8S_TOKEN`: ServiceAccount token with minimal RBAC

### Commands to collect the values

**K8S_SERVER**
```bash
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
```

**K8S_CA**
```bash
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'; echo
```

**K8S_TOKEN** (namespace `nginx`, secret `gha-deployer-token`)
```bash
kubectl -n nginx get secret gha-deployer-token -o jsonpath='{.data.token}' | base64 -d; echo
```

> Note: the ServiceAccount + RBAC + token Secret can be provisioned via Helm `extraDeploy` in the nginx values.

## Security notes

### Public cluster endpoint (test-only)
To make testing/demos easier with **GitHub-hosted runners** (which run outside your VPC and have changing IPs), this project may be configured with:
- EKS public endpoint enabled
- `eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]` (no CIDR restriction)

This **must not be replicated in production**.

Better alternatives (production):
- **Self-hosted runner** inside the VPC (or with a fixed egress IP) + restrict the public endpoint CIDR to a `/32`, or even **disable the public endpoint**.
- **Private EKS endpoint** + private connectivity (VPN/Direct Connect) and run CI/CD inside the network.
- Run CI/CD **internally** (e.g., **self-managed GitLab** inside the VPC with internal runners), avoiding reliance on GitHub-hosted runner networking.
- Avoid static ServiceAccount tokens: prefer **AWS OIDC + IAM (IRSA/Access Entries)** and generate tokens via `aws eks get-token` when possible.

> Important: if a ServiceAccount token leaks, rotate it immediately (recreate the Secret/token).

### Public registry (test-only)
To simplify pulling images from cluster nodes (without configuring `imagePullSecret`), the **GHCR** package may be **public**.

This **must not be replicated in production**.

Better alternatives (production):
- Keep GHCR **private** and configure `imagePullSecret` in the namespace/Deployment (or via Helm values).
- Use **Amazon ECR** and allow pulling via the **node group IAM role** (or IRSA in specific cases), avoiding static secrets in the cluster.
- Use External Secrets/Secrets Manager to centrally manage registry credentials.
