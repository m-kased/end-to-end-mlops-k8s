output "prometheus_stack_status" {
  description = "Status of kube-prometheus-stack installation"
  value       = helm_release.prometheus_community.status
}

output "istio_status" {
  description = "Status of Istio components"
  value = {
    base    = helm_release.istio_base.status
    istiod  = helm_release.istiod.status
    gateway = helm_release.istio_gateway.status
  }
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
