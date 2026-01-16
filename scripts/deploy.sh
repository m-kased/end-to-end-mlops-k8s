#!/bin/bash
# Deployment script for MLOps project with Helm, Istio, and kube-prometheus-stack

set -e

NAMESPACE="mlops"
RELEASE_NAME="mlops"

echo "Deploying MLOps Stack"
echo "========================"

# Check prerequisites
command -v helm >/dev/null 2>&1 || { echo "ERROR: Helm is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI is required but not installed. Aborting." >&2; exit 1; }

# Check AWS authentication
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not authenticated. Please run 'aws configure' or login with your credentials." >&2
  exit 1
fi

# Create namespace
echo "Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Verify base software is installed (managed by Terraform)
echo "Verifying base software installation..."
if ! kubectl get namespace istio-system >/dev/null 2>&1; then
  echo "ERROR: Istio not found. Please run 'terraform apply' first to install base software."
  exit 1
fi

if ! kubectl get namespace monitoring >/dev/null 2>&1; then
  echo "ERROR: Monitoring namespace not found. Please run 'terraform apply' first to install kube-prometheus-stack."
  exit 1
fi

echo "Base software verified (Istio and kube-prometheus-stack managed by Terraform)"

# Deploy training job (optional)
if [ "$1" == "train" ] || [ "$1" == "all" ]; then
  echo "Deploying training job..."
  helm upgrade --install ${RELEASE_NAME}-training ./helm/mlops-training \
    --namespace ${NAMESPACE} \
    --wait
fi

# Deploy serving API
echo "Deploying serving API..."
helm upgrade --install ${RELEASE_NAME}-serving ./helm/mlops-serving \
  --namespace ${NAMESPACE} \
  --wait

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/${RELEASE_NAME}-serving -n ${NAMESPACE} || true

# Get service information
echo ""
echo "Deployment complete!"
echo ""
echo "Service Information:"
echo "========================"
kubectl get svc -n ${NAMESPACE}
echo ""
kubectl get pods -n ${NAMESPACE}
echo ""

# Get Istio gateway info
if kubectl get gateway -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "Istio Gateway:"
  kubectl get gateway -n ${NAMESPACE}
  echo ""
fi

# Get Istio ingress gateway LoadBalancer
echo "Istio Ingress Gateway:"
kubectl get svc istio-ingressgateway -n istio-system
echo ""

# Port forwarding instructions
echo "Access Services:"
echo "==================="
echo "Grafana:     kubectl port-forward -n ${NAMESPACE} svc/kube-prometheus-stack-grafana 3000:80"
echo "Prometheus:   kubectl port-forward -n ${NAMESPACE} svc/kube-prometheus-stack-prometheus 9090:9090"
echo "MLOps API:   kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-serving 8080:80"
echo ""
echo "Istio Gateway: kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
