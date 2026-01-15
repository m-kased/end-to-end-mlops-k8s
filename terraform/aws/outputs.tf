# Outputs using modules
output "eks_cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_ca_certificate" {
  description = "EKS Cluster CA certificate"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "model_registry_bucket" {
  description = "S3 bucket for model registry"
  value       = aws_s3_bucket.model_registry.bucket
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "prometheus_stack_status" {
  description = "Status of kube-prometheus-stack"
  value       = module.helm_addons.prometheus_stack_status
}

output "istio_status" {
  description = "Status of Istio components"
  value       = module.helm_addons.istio_status
}

output "metrics_server_status" {
  description = "Status of metrics-server"
  value       = module.helm_addons.metrics_server_status
}

output "aws_lb_controller_status" {
  description = "Status of AWS Load Balancer Controller"
  value       = module.helm_addons.aws_lb_controller_status
}

output "cluster_autoscaler_status" {
  description = "Status of Cluster Autoscaler"
  value       = module.helm_addons.cluster_autoscaler_status
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
