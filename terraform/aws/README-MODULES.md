# Terraform Modules Structure

The Terraform configuration has been refactored into reusable modules for better organization and maintainability.

## Module Structure

```
terraform/
├── aws/                    # Main configuration
│   ├── main.tf            # Original monolithic config (legacy)
│   ├── main-modular.tf    # New modular configuration
│   ├── iam.tf             # IAM roles and policies
│   ├── variables.tf       # Input variables
│   └── outputs.tf         # Output values
└── modules/                # Reusable modules
    ├── eks/               # EKS cluster module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── vpc/               # VPC and networking module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── helm-addons/       # Helm addons module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Modules

### 1. VPC Module (`modules/vpc`)

Manages VPC, subnets, internet gateway, NAT gateway, and route tables.

**Inputs:**
- `name`: Name prefix for resources
- `vpc_cidr`: VPC CIDR block
- `public_subnet_cidrs`: List of public subnet CIDRs
- `private_subnet_cidrs`: List of private subnet CIDRs
- `enable_nat_gateway`: Enable NAT gateway for private subnets

**Outputs:**
- `vpc_id`: VPC ID
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `all_subnet_ids`: Combined list of all subnet IDs

### 2. EKS Module (`modules/eks`)

Manages EKS cluster, node groups, and OIDC provider.

**Inputs:**
- `cluster_name`: Name of the EKS cluster
- `cluster_role_arn`: IAM role ARN for cluster
- `node_role_arn`: IAM role ARN for nodes
- `subnet_ids`: List of subnet IDs
- `kubernetes_version`: Kubernetes version
- `node_count`, `min_node_count`, `max_node_count`: Node scaling config
- `instance_type`: EC2 instance type
- `preemptible_nodes`: Use spot instances

**Outputs:**
- `cluster_id`, `cluster_arn`, `cluster_name`
- `cluster_endpoint`: API server endpoint
- `cluster_ca_certificate`: CA certificate
- `oidc_provider_arn`, `oidc_provider_url`: For IRSA

### 3. Helm Addons Module (`modules/helm-addons`)

Installs base Kubernetes software via Helm:
- **kube-prometheus-stack**: Prometheus Operator + Grafana (monitoring namespace)
- **Istio**: Service mesh (istio-system namespace)
  - Istio base
  - Istiod (control plane)
  - Istio ingress gateway (NLB)
- **metrics-server**: Kubernetes metrics collection (kube-system namespace)
- **AWS Load Balancer Controller**: Manages ALB/NLB resources (kube-system namespace)
- **Cluster Autoscaler**: Auto-scales EKS node groups (kube-system namespace)
- **mlops namespace**: Created with Istio injection enabled

**Inputs:**
- `cluster_name`, `cluster_endpoint`, `cluster_ca_certificate`
- `region`, `vpc_id`
- `aws_lb_controller_role_arn`: IAM role for LB controller
- `cluster_autoscaler_role_arn`: IAM role for autoscaler
- Version variables for each component:
  - `prometheus_stack_version` (default: "55.0.0")
  - `istio_version` (default: "1.20.0")
  - `metrics_server_version` (default: "3.11.0")
  - `aws_lb_controller_version` (default: "1.7.0")
  - `cluster_autoscaler_version` (default: "9.29.0")

**Outputs:**
- Status of each installed component

## Usage

### Using Modular Configuration

1. **Rename files** (optional - for clean migration):
   ```bash
   cd terraform/aws
   mv main.tf main-legacy.tf
   mv main-modular.tf main.tf
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan and Apply**:
   ```bash
   terraform plan
   terraform apply
   ```

### Migration from Monolithic to Modular

The modular configuration (`main-modular.tf`) uses the same variables and produces the same outputs as the original `main.tf`. You can:

1. **Gradual Migration**: Keep both files and test modular version
2. **Full Migration**: Replace `main.tf` with modular version
3. **Side-by-side**: Use different workspaces for testing

## Benefits of Modules

1. **Reusability**: Modules can be reused across environments
2. **Maintainability**: Easier to update and test individual components
3. **Clarity**: Clear separation of concerns
4. **Testing**: Test modules independently
5. **Documentation**: Self-documenting module structure

## Module Dependencies

```
VPC Module
    ↓
EKS Module (depends on VPC)
    ↓
Helm Addons Module (depends on EKS)
    ↓
IAM Roles (for service accounts: LB controller, autoscaler)
```

IAM resources are kept in `iam.tf` as they're shared across modules. They include:
- Cluster and node IAM roles
- AWS Load Balancer Controller IAM role (with IRSA)
- Cluster Autoscaler IAM role (with IRSA)
- S3 access policy for nodes

They can be modularized later if needed.

## Adding New Components

To add new Helm charts or components:

1. Add to `modules/helm-addons/main.tf`
2. Add variables to `modules/helm-addons/variables.tf`
3. Add outputs to `modules/helm-addons/outputs.tf`
4. Update main configuration if needed

## Module Versioning

For production use, consider pinning module versions:

```hcl
module "eks" {
  source = "../modules/eks"
  # Use git tags or specific paths for versioning
}
```
