# Architecture Documentation

## Overview

This MLOps project implements a production-ready machine learning pipeline on Kubernetes, leveraging DevOps best practices for CI/CD, infrastructure as code, and monitoring.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions CI/CD Pipeline                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   Lint   │→ │   Test   │→ │  Build   │→ │  Deploy  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Container Registry (ECR/GHCR)                   │
│  ┌──────────────┐              ┌──────────────┐            │
│  │ Training Img │              │ Serving Img  │            │
│  └──────────────┘              └──────────────┘            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (EKS)                   │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Training Namespace                      │    │
│  │  ┌──────────────────────────────────────────────┐  │    │
│  │  │  Training Job (Batch)                         │  │    │
│  │  │  - Trains model                               │  │    │
│  │  │  - Saves to PVC/Registry                      │  │    │
│  │  └──────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Serving Namespace                      │    │
│  │  ┌──────────────┐  ┌──────────────┐              │    │
│  │  │   FastAPI    │  │   FastAPI    │  (Replicas)   │    │
│  │  │   Pod 1      │  │   Pod 2      │              │    │
│  │  └──────┬───────┘  └──────┬───────┘              │    │
│  │         │                  │                       │    │
│  │         └────────┬─────────┘                       │    │
│  │                  ▼                                  │    │
│  │         ┌─────────────────┐                        │    │
│  │         │  Service (LB)   │                        │    │
│  │         └─────────────────┘                        │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Monitoring Namespace                   │    │
│  │  ┌──────────────┐  ┌──────────────┐              │    │
│  │  │  Prometheus  │  │   Grafana    │              │    │
│  │  └──────────────┘  └──────────────┘              │    │
│  └────────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Model Registry (S3)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Model v1.0  │  │  Model v1.1  │  │  Model v2.0  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Model Training (`src/train.py`)

- **Purpose**: Train ML models and save artifacts
- **Input**: Training data (generated or loaded)
- **Output**: Trained model file + metrics JSON
- **Deployment**: Kubernetes Job (batch processing)
- **Storage**: Persistent Volume or Cloud Storage (S3)

### 2. Model Serving (`src/serve.py`)

- **Framework**: FastAPI
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /ready` - Readiness probe
  - `POST /predict` - Model inference
  - `GET /metrics` - Prometheus metrics
- **Deployment**: Kubernetes Deployment (3 replicas)
- **Scaling**: Horizontal Pod Autoscaler (HPA) ready
- **Monitoring**: Prometheus metrics exposed

### 3. Model Registry

- **Storage Options**:
  - Local: PVC (Persistent Volume Claim)
  - AWS: S3 bucket
  
- **Versioning**: Timestamp-based versioning
- **Lifecycle**: 90-day retention policy

### 4. CI/CD Pipeline (GitHub Actions)

**Stages**:
1. **Lint**: Code quality checks (flake8, black)
2. **Test**: Unit tests
3. **Build**: Docker image builds
4. **Train**: Optional model training job
5. **Deploy**: Kubernetes deployment

**Triggers**:
- Push to `main` branch → Auto-deploy
- Manual workflow dispatch → Training + Deploy
- Commit message `[train]` → Trigger training

### 5. Infrastructure (Terraform Modules)

**Terraform Modules**:
- **VPC Module**: VPC, subnets (public/private), Internet Gateway, NAT Gateway, route tables
- **EKS Module**: EKS cluster, node groups, OIDC provider for IRSA
- **Helm Addons Module**: Base Kubernetes software installation

**AWS Resources**:
- EKS cluster with node group (auto-scaling enabled)
- VPC and subnets (public and private)
- S3 bucket for model registry
- IAM roles and policies:
  - Cluster and node roles
  - AWS Load Balancer Controller role (IRSA)
  - Cluster Autoscaler role (IRSA)
  - S3 access for nodes

**Base Software** (installed via Terraform Helm provider):
- kube-prometheus-stack (monitoring namespace)
- Istio (istio-system namespace)
- metrics-server (kube-system namespace)
- AWS Load Balancer Controller (kube-system namespace)
- Cluster Autoscaler (kube-system namespace)

### 6. Monitoring

**kube-prometheus-stack** (installed via Terraform):
- Prometheus Operator for Kubernetes-native monitoring
- Prometheus scrapes metrics from serving pods
- Metrics:
  - `ml_requests_total` - Request count
  - `ml_request_duration_seconds` - Request latency
  - `ml_predictions_total` - Prediction count by class
- ServiceMonitor for automatic metric discovery

**Grafana**:
- Pre-configured dashboards
- Visualizations for:
  - Request rate
  - Latency (p95, p99)
  - Prediction distribution
  - Pod health
  - Node metrics (via metrics-server)

**metrics-server**:
- Kubernetes metrics collection
- Enables `kubectl top` commands
- Required for HPA (Horizontal Pod Autoscaler)

## Data Flow

### Training Flow

```
1. Developer commits code → GitHub
2. GitHub Actions triggers training job
3. Training job runs in Kubernetes
4. Model trained and saved to PVC/Registry
5. Metrics saved alongside model
```

### Inference Flow

```
1. Client sends POST /predict request
2. Request routed to serving pod via Service
3. FastAPI loads model from PVC/Registry
4. Model makes prediction
5. Response returned to client
6. Metrics recorded in Prometheus
```

## Security Considerations

- **Secrets Management**: Kubernetes Secrets for credentials
- **Network Policies**: Istio-ready (can add Service Mesh)
- **RBAC**: Service accounts with minimal permissions
- **Image Security**: Container image scanning in CI/CD
- **TLS**: Ingress with TLS termination

## Scalability

- **Horizontal Pod Scaling**: Kubernetes HPA based on CPU/memory (requires metrics-server)
- **Vertical Scaling**: Resource requests/limits configured
- **Node Auto-scaling**: Cluster Autoscaler automatically scales EKS node groups
- **Load Balancing**: 
  - Internal: Kubernetes Service with round-robin
  - External: Istio Gateway with NLB (Network Load Balancer) via AWS Load Balancer Controller

## Best Practices Implemented

✅ **Infrastructure as Code**: Terraform modules for all infrastructure
✅ **Containerization**: Docker for all components
✅ **Orchestration**: Kubernetes-native deployments with Helm
✅ **CI/CD**: Automated pipelines with GitHub Actions
✅ **Monitoring**: kube-prometheus-stack (Prometheus Operator + Grafana)
✅ **Service Mesh**: Istio for traffic management and observability
✅ **Auto-scaling**: HPA for pods, Cluster Autoscaler for nodes
✅ **Load Balancing**: AWS Load Balancer Controller for ALB/NLB
✅ **Metrics**: metrics-server for Kubernetes metrics
✅ **Versioning**: Model versioning and registry (S3)
✅ **Health Checks**: Liveness and readiness probes
✅ **Resource Management**: Requests and limits
✅ **Secrets Management**: Kubernetes Secrets + AWS Secrets Manager
✅ **IAM**: IRSA (IAM Roles for Service Accounts) for secure access
✅ **Modular Architecture**: Reusable Terraform modules
✅ **Documentation**: Comprehensive docs

## Future Enhancements

- [ ] MLflow integration for experiment tracking
- [ ] A/B testing framework (using Istio traffic splitting)
- [ ] Model drift detection
- [ ] Automated retraining pipeline
- [ ] Feature store integration
- [ ] Distributed training support
- [ ] GPU support for training
- [ ] Multi-region deployment
- [ ] Advanced Istio features (mTLS, rate limiting)
- [ ] Custom Grafana dashboards for ML metrics