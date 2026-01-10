.PHONY: help build train serve test lint deploy clean helm-install helm-upgrade

help:
	@echo "MLOps Project Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build          - Build Docker images"
	@echo "  train           - Train model locally"
	@echo "  serve           - Run serving API locally"
	@echo "  test            - Run tests"
	@echo "  lint            - Run linters"
	@echo "  deploy          - Deploy with Helm (all components)"
	@echo "  helm-install    - Install Helm dependencies"
	@echo "  helm-upgrade    - Upgrade Helm releases"
	@echo "  clean           - Clean up generated files"

build:
	docker build -f docker/Dockerfile.train -t mlops-train:latest .
	docker build -f docker/Dockerfile.serve -t mlops-serve:latest .

train:
	PYTHONPATH=. python -m src.train --output-dir ./models

serve:
	PYTHONPATH=. python -m src.serve

test:
	pytest tests/ -v

lint:
	flake8 src/ --count --select=E9,F63,F7,F82 --show-source --statistics
	black --check src/

helm-install:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add istio https://istio-release.storage.googleapis.com/charts
	helm repo update

deploy:
	./scripts/deploy.sh all

helm-upgrade:
	helm upgrade --install mlops-serving ./helm/mlops-serving \
		--namespace mlops \
		--create-namespace \
		--set istio.enabled=true

clean:
	rm -rf models/
	rm -rf __pycache__/
	rm -rf *.egg-info/
	find . -type d -name __pycache__ -exec rm -r {} +
	find . -type f -name "*.pyc" -delete
