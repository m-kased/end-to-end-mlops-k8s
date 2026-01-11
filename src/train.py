"""
Model training script for MLOps pipeline.
"""
import os
import sys
import argparse
import json
from datetime import datetime
from pathlib import Path

from .model import MLModel, generate_sample_data
from .utils import upload_to_registry, get_model_registry_path


def train_model(
    output_dir: str = "./models",
    model_version: str = None,
    n_samples: int = 1000,
    upload: bool = False
) -> dict:
    """Train model and save artifacts.
    
    Args:
        output_dir: Directory to save model
        model_version: Model version tag
        n_samples: Number of training samples
        upload: Whether to upload to model registry
        
    Returns:
        Training metrics dictionary
    """
    print(f"Starting model training at {datetime.now()}")
    
    # Generate or load training data
    print(f"Generating {n_samples} training samples...")
    X, y = generate_sample_data(n_samples=n_samples)
    print(f"Data shape: X={X.shape}, y={y.shape}")
    
    # Initialize and train model
    print("Initializing model...")
    model = MLModel()
    
    print("Training model...")
    metrics = model.train(X, y)
    
    # Create version tag
    if not model_version:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        model_version = f"v{timestamp}"
    
    model.version = model_version
    
    # Save model
    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, f"model-{model_version}.pkl")
    print(f"Saving model to {model_path}")
    model.save(model_path)
    
    # Save metrics
    metrics_path = os.path.join(output_dir, f"metrics-{model_version}.json")
    metrics['version'] = model_version
    metrics['timestamp'] = datetime.now().isoformat()
    
    with open(metrics_path, 'w') as f:
        json.dump(metrics, f, indent=2)
    
    print(f"Training completed!")
    print(f"Metrics: {json.dumps(metrics, indent=2)}")
    
    # Upload to registry if specified
    if upload:
        print("Uploading to model registry...")
        registry_path = get_model_registry_path(model_version)
        upload_to_registry(model_path, registry_path)
        upload_to_registry(metrics_path, registry_path.replace('.pkl', '-metrics.json'))
        print(f"Model uploaded to {registry_path}")
    
    return metrics


def main():
    """Main training entry point."""
    parser = argparse.ArgumentParser(description="Train ML model")
    parser.add_argument(
        "--output-dir",
        type=str,
        default=os.getenv("MODEL_OUTPUT_DIR", "./models"),
        help="Output directory for model artifacts"
    )
    parser.add_argument(
        "--version",
        type=str,
        default=None,
        help="Model version tag"
    )
    parser.add_argument(
        "--samples",
        type=int,
        default=int(os.getenv("TRAINING_SAMPLES", "1000")),
        help="Number of training samples"
    )
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload model to registry"
    )
    
    args = parser.parse_args()
    
    try:
        metrics = train_model(
            output_dir=args.output_dir,
            model_version=args.version,
            n_samples=args.samples,
            upload=args.upload
        )
        
        # Exit with error code if metrics are poor
        if metrics.get('test_score', 0) < 0.5:
            print("WARNING: Model performance is below threshold!")
            sys.exit(1)
        
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: Training failed: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
