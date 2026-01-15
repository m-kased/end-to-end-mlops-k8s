# AWS EKS Infrastructure with Terraform

This directory contains Terraform configuration for provisioning AWS EKS cluster and installing base Kubernetes software using a modular architecture.

## What Gets Provisioned

### Infrastructure (via Modules)
- **VPC Module**: VPC, subnets (public/private), Internet Gateway, NAT Gateway, route tables
- **EKS Module**: EKS cluster, node groups, OIDC provider for IRSA
- **S3 Bucket**: Model registry storage
- **IAM Roles**: For cluster, nodes, and service accounts (LB controller, autoscaler)

### Base Software (via Helm Addons Module)
- **kube-prometheus-stack**: Prometheus Operator + Grafana (in `monitoring` namespace)
- **Istio**: Service mesh (in `istio-system` namespace)
  - Istio base
  - Istiod (control plane)
  - Istio ingress gateway (NLB)
- **metrics-server**: Kubernetes metrics collection (in `kube-system` namespace)
- **AWS Load Balancer Controller**: Manages ALB/NLB resources (in `kube-system` namespace)
- **Cluster Autoscaler**: Auto-scales EKS node groups (in `kube-system` namespace)
- **mlops namespace**: Created with Istio injection enabled

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl installed
- Helm 3.x (for application deployment, not required for infrastructure)
- AWS account with permissions to create:
  - EKS clusters
  - VPCs and networking
  - IAM roles and policies
  - S3 buckets
  - EC2 instances
  - Load balancers

## Usage

### 1. Configure Variables

Create a `terraform.tfvars` file:

```hcl
project_name = "mlops"
cluster_name = "mlops-cluster"
environment  = "prod"
region       = "us-east-1"
node_count   = 3
instance_type = "t3.medium"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

This will:
1. Create VPC and networking infrastructure (via VPC module)
2. Create EKS cluster and node groups (takes ~15-20 minutes, via EKS module)
3. Install base Kubernetes software via Helm provider (via helm-addons module):
   - kube-prometheus-stack
   - Istio (base, istiod, gateway)
   - metrics-server
   - AWS Load Balancer Controller
   - Cluster Autoscaler
4. Create mlops namespace with Istio injection enabled
5. Create S3 bucket for model registry

### 5. Configure kubectl

After Terraform completes, configure kubectl:

```bash
aws eks update-kubeconfig --name mlops-cluster-prod --region us-east-1
```

Or use the output from Terraform:

```bash
terraform output -raw kubeconfig > kubeconfig
export KUBECONFIG=./kubeconfig
```

### 6. Verify Installation

```bash
# Check Istio
kubectl get pods -n istio-system

# Check Prometheus
kubectl get pods -n monitoring

# Check metrics-server
kubectl get pods -n kube-system | grep metrics-server

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check Cluster Autoscaler
kubectl get pods -n kube-system | grep cluster-autoscaler

# Check namespace
kubectl get namespace mlops
kubectl get namespace mlops -o jsonpath='{.metadata.labels.istio-injection}'
# Should output: enabled
```

## Outputs

After `terraform apply`, you'll get:

- `eks_cluster_name`: EKS cluster name
- `eks_cluster_endpoint`: Cluster API endpoint
- `model_registry_bucket`: S3 bucket for models
- `vpc_id`: VPC ID
- `prometheus_stack_status`: Status of Prometheus installation
- `istio_status`: Status of Istio components
- `metrics_server_status`: Status of metrics-server
- `aws_lb_controller_status`: Status of AWS Load Balancer Controller
- `cluster_autoscaler_status`: Status of Cluster Autoscaler
- `grafana_url`: Command to access Grafana
- `prometheus_url`: Command to access Prometheus
- `istio_gateway_address`: Command to get gateway address

## Accessing Services

### Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access at http://localhost:3000
# Default credentials: admin/admin
```

### Prometheus

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access at http://localhost:9090
```

### Istio Gateway

```bash
# Get LoadBalancer address
kubectl get svc istio-ingressgateway -n istio-system

# The gateway is configured as NLB (Network Load Balancer)
```

## Updating Base Software

To update Istio or kube-prometheus-stack versions, modify `helm.tf`:

```hcl
resource "helm_release" "istiod" {
  # ...
  version = "1.21.0"  # Update version here
}
```

Then run:

```bash
terraform plan
terraform apply
```

## Destroying

To remove everything:

```bash
terraform destroy
```

**Warning**: This will delete:
- EKS cluster
- All nodes
- VPC and networking
- S3 bucket (if empty)
- All installed software

## Troubleshooting

### Helm Provider Authentication

If you get authentication errors, ensure:

1. AWS credentials are configured:
   ```bash
   aws sts get-caller-identity
   ```

2. kubectl can access the cluster:
   ```bash
   kubectl get nodes
   ```

### Helm Releases Not Installing

Check Helm provider logs:

```bash
terraform apply -debug
```

Verify the cluster is ready:

```bash
kubectl get nodes
```

### Istio Sidecar Injection

Verify namespace label:

```bash
kubectl get namespace mlops -o yaml | grep istio-injection
```

If missing, add it:

```bash
kubectl label namespace mlops istio-injection=enabled --overwrite
```

## Cost Estimation

Approximate monthly costs (us-east-1):

- EKS Control Plane: ~$73/month
- 3x t3.medium nodes: ~$90/month
- NLB: ~$16/month
- Data transfer: Variable
- **Total**: ~$180-200/month (without data transfer)

Use spot instances to reduce costs:

```hcl
preemptible_nodes = true
instance_type     = "t3.medium"
```

## Security Notes

- IAM roles use least privilege
- OIDC provider configured for IRSA
- Secrets should be stored in AWS Secrets Manager (not in Terraform)
- Enable encryption at rest for S3 bucket
- Use private subnets for nodes in production
