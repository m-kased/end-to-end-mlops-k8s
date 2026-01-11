"""
Utility functions for MLOps pipeline.
"""
import os
import boto3
from typing import Optional
from google.cloud import storage as gcs_storage


def get_model_registry_path(version: str) -> str:
    """Get model registry path for a version.
    
    Args:
        version: Model version
        
    Returns:
        Registry path string
    """
    registry_type = os.getenv("MODEL_REGISTRY_TYPE", "local")
    base_path = os.getenv("MODEL_REGISTRY_PATH", "models")
    
    if registry_type == "s3":
        bucket = os.getenv("S3_BUCKET", "mlops-models")
        return f"s3://{bucket}/models/{version}/model.pkl"
    elif registry_type == "gcs":
        bucket = os.getenv("GCS_BUCKET", "mlops-models")
        return f"gs://{bucket}/models/{version}/model.pkl"
    else:
        return f"{base_path}/{version}/model.pkl"


def upload_to_registry(local_path: str, registry_path: str) -> None:
    """Upload file to model registry.
    
    Args:
        local_path: Local file path
        registry_path: Registry path (s3://, gs://, or local)
    """
    if registry_path.startswith("s3://"):
        # S3 upload
        s3_path = registry_path.replace("s3://", "")
        bucket_name, key = s3_path.split("/", 1)
        
        s3_client = boto3.client('s3')
        s3_client.upload_file(local_path, bucket_name, key)
        print(f"Uploaded to S3: {registry_path}")
        
    elif registry_path.startswith("gs://"):
        # GCS upload
        gcs_path = registry_path.replace("gs://", "")
        bucket_name, blob_name = gcs_path.split("/", 1)
        
        client = gcs_storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(local_path)
        print(f"Uploaded to GCS: {registry_path}")
        
    else:
        # Local copy
        os.makedirs(os.path.dirname(registry_path), exist_ok=True)
        import shutil
        shutil.copy2(local_path, registry_path)
        print(f"Copied to local: {registry_path}")


def download_from_registry(registry_path: str, local_path: str) -> None:
    """Download file from model registry.
    
    Args:
        registry_path: Registry path (s3://, gs://, or local)
        local_path: Local destination path
    """
    if registry_path.startswith("s3://"):
        # S3 download
        s3_path = registry_path.replace("s3://", "")
        bucket_name, key = s3_path.split("/", 1)
        
        s3_client = boto3.client('s3')
        s3_client.download_file(bucket_name, key, local_path)
        print(f"Downloaded from S3: {registry_path}")
        
    elif registry_path.startswith("gs://"):
        # GCS download
        gcs_path = registry_path.replace("gs://", "")
        bucket_name, blob_name = gcs_path.split("/", 1)
        
        client = gcs_storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.download_to_filename(local_path)
        print(f"Downloaded from GCS: {registry_path}")
        
    else:
        # Local copy
        import shutil
        shutil.copy2(registry_path, local_path)
        print(f"Copied from local: {registry_path}")
