# Main Terraform configuration using modules

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  
  backend "s3" {
    bucket = "mlops-terraform-state"
    key    = "terraform/state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  name              = var.cluster_name
  vpc_cidr          = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# IAM Module (using existing iam.tf for now, can be modularized later)
# For now, IAM resources are in iam.tf

# EKS Module
module "eks" {
  source = "../modules/eks"

  cluster_name     = "${var.cluster_name}-${var.environment}"
  cluster_role_arn = aws_iam_role.cluster.arn
  node_role_arn    = aws_iam_role.nodes.arn
  subnet_ids       = module.vpc.all_subnet_ids

  kubernetes_version      = var.kubernetes_version
  endpoint_private_access = true
  endpoint_public_access  = true

  node_count         = var.node_count
  min_node_count     = var.min_node_count
  max_node_count     = var.max_node_count
  instance_type      = var.instance_type
  preemptible_nodes  = var.preemptible_nodes

  cluster_policy_attachment = aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  node_policy_attachments = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket for Model Registry
resource "aws_s3_bucket" "model_registry" {
  bucket = "${var.project_name}-mlops-models-${var.environment}"
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    id      = "delete-old-models"
    enabled = true
    
    expiration {
      days = 90
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "model_registry" {
  bucket = aws_s3_bucket.model_registry.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Helm Addons Module
module "helm_addons" {
  source = "../modules/helm-addons"

  cluster_name          = module.eks.cluster_name
  cluster_endpoint      = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_ca_certificate
  region                = var.region
  vpc_id                = module.vpc.vpc_id

  aws_lb_controller_role_arn     = aws_iam_role.aws_load_balancer_controller.arn
  aws_lb_controller_role_ready   = aws_iam_role_policy.aws_load_balancer_controller
  cluster_autoscaler_role_arn    = aws_iam_role.cluster_autoscaler.arn
  cluster_autoscaler_role_ready  = aws_iam_role_policy.cluster_autoscaler

  prometheus_stack_values = [
    file("${path.module}/../helm/kube-prometheus-stack/values.yaml")
  ]

  cluster_ready = module.eks.cluster_id
}
