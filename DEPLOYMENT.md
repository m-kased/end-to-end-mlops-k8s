# Deployment Guide

This guide covers deploying the MLOps project to Kubernetes on AWS EKS using Helm charts.

## Prerequisites

- AWS account with appropriate permissions
- AWS EKS cluster (provisioned via Terraform)
- `kubectl` configured
- `helm` 3.x installed
- `terraform` installed
- Docker (for building images)
- AWS credentials configured (for S3 model registry and EKS access)

**Important**: Base software must be installed via Terraform first! This includes:
- kube-prometheus-stack (monitoring)
- Istio (service mesh)
- metrics-server
- AWS Load Balancer Controller
- Cluster Autoscaler

## Quick Start

### Step 1: Provision Infrastructure and Base Software

First, provision the EKS cluster and install base software using Terraform:

```bash
cd terraform/aws

# Initialize Terraform (this will download modules)
terraform init

# Set variables (optional - defaults work)
export TF_VAR_region=us-east-1
export TF_VAR_project_name=mlops
export TF_VAR_cluster_name=mlops-cluster
export TF_VAR_environment=prod

# Plan and apply
terraform plan
terraform apply

# This will:
# - Create VPC and networking (via VPC module)
# - Create EKS cluster and node groups (via EKS module)
# - Install base software via Helm (via helm-addons module):
#   * kube-prometheus-stack in 'monitoring' namespace
#   * Istio in 'istio-system' namespace
#   * metrics-server in 'kube-system' namespace
#   * AWS Load Balancer Controller in 'kube-system' namespace
#   * Cluster Autoscaler in 'kube-system' namespace
# - Create 'mlops' namespace with Istio injection enabled
# - Create S3 bucket for model registry
```

See `terraform/aws/README.md` for detailed Terraform documentation.

### Step 2: Build and Push Docker Images

```bash
# Build images
make build
# Or manually:
docker build -f docker/Dockerfile.train -t mlops-train:latest .
docker build -f docker/Dockerfile.serve -t mlops-serve:latest .

# Push to registry (ECR example)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com
docker tag mlops-train:latest AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/mlops-train:latest
docker push AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/mlops-train:latest
docker tag mlops-serve:latest AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/mlops-serve:latest
docker push AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/mlops-serve:latest
```

### Step 3: Deploy Application Components

After Terraform completes, deploy the application using Helm:

```bash
# Quick deployment (recommended)
./scripts/deploy.sh all

# Or deploy manually:
# Deploy training job (optional)
helm upgrade --install mlops-training ./helm/mlops-training \
  --namespace mlops \
  --set image.repository=YOUR_REGISTRY/mlops-train \
  --set image.tag=latest \
  --set registry.type=s3 \
  --set registry.s3.bucket=your-mlops-models-bucket \
  --wait

# Deploy serving API
helm upgrade --install mlops-serving ./helm/mlops-serving \
  --namespace mlops \
  --set image.repository=YOUR_REGISTRY/mlops-serve \
  --set image.tag=latest \
  --set istio.enabled=true \
  --wait
```

## Configuration

### Training Chart Values

Key configuration options in `helm/mlops-training/values.yaml`:

```yaml
image:
  repository: mlops-train
  tag: "latest"

training:
  samples: 1000
  outputDir: "/models"
  uploadToRegistry: true

registry:
  type: "s3"  # local, s3
  s3:
    bucket: "mlops-models"

persistence:
  enabled: true
  storageClass: "gp3"
  size: 10Gi
```

### Serving Chart Values

Key configuration options in `helm/mlops-serving/values.yaml`:

```yaml
replicaCount: 3

image:
  repository: mlops-serve
  tag: "latest"

istio:
  enabled: true
  gateway:
    hosts:
      - mlops-api.example.com

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

monitoring:
  serviceMonitor:
    enabled: true
```

## Accessing Services

### Port Forwarding

```bash
# Grafana (in monitoring namespace - installed by Terraform)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access at http://localhost:3000 (default: admin/admin)

# Prometheus (in monitoring namespace - installed by Terraform)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access at http://localhost:9090

# MLOps API (via Service)
kubectl port-forward -n mlops svc/mlops-serving 8080:80
# Access at http://localhost:8080

# MLOps API (via Istio Gateway)
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

### Istio Gateway

Get the Istio ingress gateway LoadBalancer address (provisioned by Terraform):

```bash
kubectl get svc istio-ingressgateway -n istio-system
```

Access the API via the gateway:

```bash
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
# Wait for LoadBalancer to be ready (may take a few minutes)
curl http://$INGRESS_HOST/predict -X POST -H "Content-Type: application/json" -d '{"features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]}'
```

**Note**: The Istio Gateway is configured as a Network Load Balancer (NLB) in AWS, provisioned automatically by Terraform.

## Testing the Deployment

### Check Pods

```bash
kubectl get pods -n mlops
```

### Check Logs

```bash
# Training job logs
kubectl logs job/mlops-training-job -n mlops

# Serving API logs
kubectl logs -l app=mlops-serving -n mlops
```

### Test API

```bash
# Port forward
kubectl port-forward -n mlops svc/mlops-serving 8080:80

# Health check
curl http://localhost:8080/health

# Make prediction
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]}'
```

## Monitoring

### ServiceMonitor

The serving chart automatically creates a ServiceMonitor for Prometheus:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: 30s
```

### Grafana Dashboards

Access Grafana:
- URL: `http://localhost:3000` (via port-forward)
- Default credentials: `admin/admin` (change in production!)

Pre-configured dashboards:
- MLOps Model Serving Dashboard (custom)
- Kubernetes cluster monitoring
- Node metrics

### Prometheus Queries

Example queries for monitoring:

```promql
# Request rate
rate(ml_requests_total[5m])

# Request latency (p95)
histogram_quantile(0.95, rate(ml_request_duration_seconds_bucket[5m]))

# Predictions by class
sum(rate(ml_predictions_total[5m])) by (prediction_class)

# Active pods
count(up{job="mlops-serving"})
```

## Istio Features

### Traffic Management

The serving chart includes:
- **Gateway**: External entry point
- **VirtualService**: Routing rules
- **DestinationRule**: Load balancing and circuit breaking

### Circuit Breaking

Configured in `values.yaml`:

```yaml
istio:
  destinationRule:
    trafficPolicy:
      outlierDetection:
        consecutiveErrors: 3
        interval: 30s
        baseEjectionTime: 30s
        maxEjectionPercent: 50
```

### Canary Deployments

Example canary deployment:

```bash
# Deploy canary version (10% traffic)
helm upgrade --install mlops-serving-canary ./helm/mlops-serving \
  --namespace mlops \
  --set image.tag=canary \
  --set istio.virtualService.http[0].route[0].weight=10 \
  --set istio.virtualService.http[0].route[1].weight=90
```

## CI/CD with GitHub Actions

1. Set up GitHub secrets:
   - `KUBECONFIG`: Base64 encoded kubeconfig file

2. Push to main branch to trigger deployment

3. Manually trigger training:
   - Go to Actions → "MLOps CI/CD Pipeline" → "Run workflow"
   - Check "Trigger model training"

## Troubleshooting

### Check Helm Releases

```bash
helm list -n mlops
helm list -n istio-system
```

### View Helm Values

```bash
helm get values mlops-serving -n mlops
```

### Pods not starting

```bash
# Check events
kubectl describe pod <pod-name> -n mlops

# Check logs
kubectl logs <pod-name> -n mlops
```

### Check Istio Sidecars

```bash
# Verify sidecar injection
kubectl get pod <pod-name> -n mlops -o jsonpath='{.spec.containers[*].name}'

# View Istio proxy logs
kubectl logs <pod-name> -n mlops -c istio-proxy
```

### Check ServiceMonitor

```bash
kubectl get servicemonitor -n mlops
kubectl describe servicemonitor mlops-serving -n mlops
```

### Model not loading

```bash
# Check PVC
kubectl get pvc -n mlops

# Check model files
kubectl exec -it <pod-name> -n mlops -- ls -la /models
```

### Service not accessible

```bash
# Check service endpoints
kubectl get endpoints -n mlops

# Check Istio gateway
kubectl get gateway -n mlops
kubectl get virtualservice -n mlops
```

## Upgrading

```bash
# Upgrade serving with new image
helm upgrade mlops-serving ./helm/mlops-serving \
  --namespace mlops \
  --set image.tag=new-version \
  --reuse-values
```

## Uninstalling

```bash
# Remove application components
helm uninstall mlops-serving -n mlops
helm uninstall mlops-training -n mlops

# Remove base software (via Terraform)
cd terraform/aws
terraform destroy

# Or manually remove base software
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
```

**Note**: Base software (Istio and kube-prometheus-stack) should be managed via Terraform. Use `terraform destroy` to remove everything.
