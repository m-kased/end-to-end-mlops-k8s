variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for load balancer controller"
  type        = string
}

variable "cluster_ready" {
  description = "Dependency to ensure cluster is ready"
  type        = any
  default     = null
}

variable "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  type        = string
}

variable "aws_lb_controller_role_ready" {
  description = "Dependency for AWS LB Controller role"
  type        = any
  default     = null
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  type        = string
}

variable "cluster_autoscaler_role_ready" {
  description = "Dependency for Cluster Autoscaler role"
  type        = any
  default     = null
}

variable "prometheus_stack_version" {
  description = "Version of kube-prometheus-stack"
  type        = string
  default     = "55.0.0"
}

variable "prometheus_stack_values" {
  description = "Values for kube-prometheus-stack"
  type        = list(string)
  default     = []
}

variable "istio_version" {
  description = "Version of Istio"
  type        = string
  default     = "1.20.0"
}

variable "metrics_server_version" {
  description = "Version of metrics-server"
  type        = string
  default     = "3.11.0"
}

variable "aws_lb_controller_version" {
  description = "Version of AWS Load Balancer Controller"
  type        = string
  default     = "1.7.0"
}

variable "cluster_autoscaler_version" {
  description = "Version of Cluster Autoscaler"
  type        = string
  default     = "9.29.0"
}
