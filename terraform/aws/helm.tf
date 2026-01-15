# Helm provider for installing base Kubernetes software
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = aws_eks_cluster.mlops.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.mlops.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.mlops.name
    ]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.mlops.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.mlops.certificate_authority[0].data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.mlops.name
      ]
    }
  }
}

# Add Helm repositories
resource "helm_release" "prometheus_community" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.0.0"
  namespace  = "monitoring"
  create_namespace = true

  values = [
    file("${path.module}/../helm/kube-prometheus-stack/values.yaml")
  ]

  depends_on = [
    aws_eks_cluster.mlops,
    aws_eks_node_group.mlops
  ]
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = "1.20.0"
  namespace  = "istio-system"
  create_namespace = true

  depends_on = [
    aws_eks_cluster.mlops,
    aws_eks_node_group.mlops
  ]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = "1.20.0"
  namespace  = "istio-system"

  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }

  depends_on = [
    helm_release.istio_base
  ]
}

resource "helm_release" "istio_gateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = "1.20.0"
  namespace  = "istio-system"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  depends_on = [
    helm_release.istiod
  ]
}

# Install metrics-server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"
  create_namespace = false

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [
    aws_eks_cluster.mlops,
    aws_eks_node_group.mlops
  ]
}

# Install AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.0"
  namespace  = "kube-system"
  create_namespace = false

  set {
    name  = "clusterName"
    value = aws_eks_cluster.mlops.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = aws_vpc.mlops.id
  }

  depends_on = [
    aws_eks_cluster.mlops,
    aws_eks_node_group.mlops,
    aws_iam_role.aws_load_balancer_controller
  ]
}

# Install Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.29.0"
  namespace  = "kube-system"
  create_namespace = false

  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.mlops.name
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }

  set {
    name  = "extraArgs.scan-interval"
    value = "10s"
  }

  depends_on = [
    aws_eks_cluster.mlops,
    aws_eks_node_group.mlops,
    aws_iam_role.cluster_autoscaler
  ]
}

# Create mlops namespace with Istio injection enabled
resource "kubernetes_namespace" "mlops" {
  metadata {
    name = "mlops"
    labels = {
      istio-injection = "enabled"
    }
  }

  depends_on = [
    helm_release.istiod
  ]
}

# Outputs for Helm releases
output "prometheus_stack_status" {
  value       = helm_release.prometheus_community.status
  description = "Status of kube-prometheus-stack installation"
}

output "istio_status" {
  value = {
    base    = helm_release.istio_base.status
    istiod  = helm_release.istiod.status
    gateway = helm_release.istio_gateway.status
  }
  description = "Status of Istio components"
}

output "grafana_url" {
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
  description = "Command to access Grafana"
}

output "prometheus_url" {
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
  description = "Command to access Prometheus"
}

output "istio_gateway_address" {
  value       = "kubectl get svc istio-ingressgateway -n istio-system"
  description = "Command to get Istio gateway LoadBalancer address"
}

output "metrics_server_status" {
  description = "Status of metrics-server installation"
  value       = helm_release.metrics_server.status
}

output "aws_lb_controller_status" {
  description = "Status of AWS Load Balancer Controller installation"
  value       = helm_release.aws_load_balancer_controller.status
}

output "cluster_autoscaler_status" {
  description = "Status of Cluster Autoscaler installation"
  value       = helm_release.cluster_autoscaler.status
}
