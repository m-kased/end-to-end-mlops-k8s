# Helm Addons Module - Installs base Kubernetes software

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name
    ]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.cluster_name
      ]
    }
  }
}

# Install kube-prometheus-stack
resource "helm_release" "prometheus_community" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = "monitoring"
  create_namespace = true

  values = var.prometheus_stack_values

  depends_on = [
    var.cluster_ready
  ]
}

# Install Istio base
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = "istio-system"
  create_namespace = true

  depends_on = [
    var.cluster_ready
  ]
}

# Install Istiod
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }

  depends_on = [
    helm_release.istio_base
  ]
}

# Install Istio ingress gateway
resource "helm_release" "istio_gateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
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
  version    = var.metrics_server_version
  namespace  = "kube-system"
  create_namespace = false

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [
    var.cluster_ready
  ]
}

# Install AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lb_controller_version
  namespace  = "kube-system"
  create_namespace = false

  set {
    name  = "clusterName"
    value = var.cluster_name
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
    value = var.aws_lb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    var.cluster_ready,
    var.aws_lb_controller_role_ready
  ]
}

# Install Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler_version
  namespace  = "kube-system"
  create_namespace = false

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
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
    value = var.cluster_autoscaler_role_arn
  }

  set {
    name  = "extraArgs.scan-interval"
    value = "10s"
  }

  depends_on = [
    var.cluster_ready,
    var.cluster_autoscaler_role_ready
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
