# EKS Cluster Module

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }
  
  # Enable OIDC provider for IRSA (IAM Roles for Service Accounts)
  identity {
    type = "OIDC"
  }
  
  depends_on = [
    var.cluster_policy_attachment
  ]

  tags = var.tags
}

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = var.tags
}

# EKS Node Group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  
  scaling_config {
    desired_size = var.node_count
    max_size     = var.max_node_count
    min_size     = var.min_node_count
  }
  
  instance_types = [var.instance_type]
  capacity_type  = var.preemptible_nodes ? "SPOT" : "ON_DEMAND"
  
  depends_on = var.node_policy_attachments

  tags = var.tags
}
