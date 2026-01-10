# End-to-End MLOps on Kubernetes

A production-ready MLOps project demonstrating best practices for deploying machine learning models on Kubernetes.

## Architecture

```
┌─────────────────┐
│  GitHub Actions │  CI/CD Pipeline
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Model Training │  Train & Version Models (Helm)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Model Registry │  S3 Store Model Artifacts
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Istio Gateway  │  Service Mesh Entry Point
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Model Serving  │  FastAPI + Kubernetes (Helm)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  kube-prom-stack│  Prometheus + Grafana
└─────────────────┘
```

## Components

- **ML Model**: Scikit-learn based model with training pipeline
- **Model Serving**: FastAPI REST API for inference
- **Containerization**: Docker images for training and serving
- **Orchestration**: Kubernetes with Helm charts
- **Service Mesh**: Istio for traffic management and observability
- **CI/CD**: GitHub Actions for automated pipelines
- **Infrastructure**: Terraform modules for AWS/EKS provisioning
- **Monitoring**: kube-prometheus-stack (Prometheus Operator + Grafana)
- **Model Registry**: Versioned model storage (S3)
- **Base Software**: All installed via Terraform Helm provider:
  - kube-prometheus-stack (monitoring)
  - Istio (service mesh)
  - metrics-server (Kubernetes metrics)
  - AWS Load Balancer Controller (ALB/NLB management)
  - Cluster Autoscaler (auto-scaling nodes)

## Quick Start

### Prerequisites

- AWS account with appropriate permissions
- kubectl configured
- Docker
- Terraform >= 1.0 (for infrastructure)
- Helm 3.x (for application deployment)
- Python 3.9+
- AWS CLI configured

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Train model
PYTHONPATH=. python -m src.train

# Run API locally
PYTHONPATH=. python -m src.serve
```

### Kubernetes Deployment (Helm)

```bash
# Quick deployment script
./scripts/deploy.sh all

# Or manually with Helm
helm upgrade --install mlops-serving ./helm/mlops-serving \
  --namespace mlops \
  --create-namespace \
  --set istio.enabled=true

# Check deployment
kubectl get pods -n mlops
helm list -n mlops
```

### Infrastructure (Terraform - AWS/EKS)

```bash
cd terraform/aws
terraform init
terraform plan
terraform apply

# This will:
# - Create VPC and networking (via VPC module)
# - Create EKS cluster and node groups (via EKS module)
# - Install base software via Helm (via helm-addons module):
#   * kube-prometheus-stack (monitoring)
#   * Istio (service mesh)
#   * metrics-server
#   * AWS Load Balancer Controller
#   * Cluster Autoscaler
# - Create mlops namespace with Istio injection
# - Create S3 bucket for model registry
```

## Project Structure

```
.
├── src/                    # Source code
│   ├── train.py           # Model training script
│   ├── serve.py           # FastAPI serving API
│   ├── model.py           # Model definition
│   └── utils.py           # Utility functions
├── helm/                   # Helm charts
│   ├── mlops-training/    # Training job chart
│   ├── mlops-serving/     # Serving API chart
│   └── kube-prometheus-stack/ # Monitoring values
├── k8s/                    # Legacy Kubernetes manifests (optional)
├── docker/                 # Dockerfiles
│   ├── Dockerfile.train   # Training image
│   └── Dockerfile.serve   # Serving image
├── terraform/              # Infrastructure as Code
│   ├── aws/               # Main AWS/EKS configuration
│   │   ├── main.tf        # Module orchestration
│   │   ├── iam.tf         # IAM roles and policies
│   │   ├── variables.tf   # Input variables
│   │   └── outputs.tf     # Output values
│   └── modules/           # Reusable Terraform modules
│       ├── vpc/           # VPC and networking
│       ├── eks/           # EKS cluster and nodes
│       └── helm-addons/   # Base Kubernetes software
├── scripts/                # Deployment scripts
│   ├── deploy.sh          # Helm deployment script
│   └── quick-start.sh     # Local development
├── .github/                # GitHub Actions
│   └── workflows/         # CI/CD pipelines
└── requirements.txt        # Python dependencies
```

## Features

- ✅ Automated model training pipeline
- ✅ Model versioning and registry (S3)
- ✅ Helm charts for easy deployment
- ✅ Istio service mesh integration (no nginx ingress)
- ✅ kube-prometheus-stack for monitoring
- ✅ CI/CD with GitHub Actions
- ✅ Infrastructure as Code (Terraform modules for AWS/EKS)
- ✅ Terraform-managed base software:
  - kube-prometheus-stack (Prometheus + Grafana)
  - Istio (service mesh)
  - metrics-server (Kubernetes metrics)
  - AWS Load Balancer Controller (ALB/NLB)
  - Cluster Autoscaler (auto-scaling)
- ✅ Horizontal Pod Autoscaling (HPA)
- ✅ Circuit breaking and traffic management
- ✅ ServiceMonitor for Prometheus
- ✅ Health checks and readiness probes
- ✅ Modular Terraform architecture

## License

MIT
