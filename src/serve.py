"""
FastAPI serving API for ML model inference.
"""
import os
import sys
from typing import List, Optional
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

from .model import MLModel
from .utils import download_from_registry, get_model_registry_path


# Prometheus metrics
REQUEST_COUNT = Counter(
    'ml_requests_total',
    'Total number of prediction requests',
    ['model_version']
)

REQUEST_DURATION = Histogram(
    'ml_request_duration_seconds',
    'Time spent processing prediction requests',
    ['model_version']
)

PREDICTION_COUNTER = Counter(
    'ml_predictions_total',
    'Total number of predictions made',
    ['model_version', 'prediction_class']
)


# Initialize FastAPI app
app = FastAPI(
    title="MLOps Model Serving API",
    description="REST API for ML model inference",
    version="1.0.0"
)

# Global model instance
model: Optional[MLModel] = None
model_version: str = "unknown"


class PredictionRequest(BaseModel):
    """Request model for predictions."""
    features: List[float] = Field(..., description="Feature vector for prediction")
    
    class Config:
        schema_extra = {
            "example": {
                "features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] * 2
            }
        }


class PredictionResponse(BaseModel):
    """Response model for predictions."""
    prediction: int = Field(..., description="Predicted class")
    probabilities: List[float] = Field(..., description="Class probabilities")
    model_version: str = Field(..., description="Model version used")


def load_model(version: Optional[str] = None) -> None:
    """Load model from registry or local path.
    
    Args:
        version: Model version to load, or None for latest
    """
    global model, model_version
    
    model_path = os.getenv("MODEL_PATH", "./models/model.pkl")
    
    # If version specified, try to download from registry
    if version:
        registry_path = get_model_registry_path(version)
        try:
            download_from_registry(registry_path, model_path)
        except Exception as e:
            print(f"Warning: Could not download from registry: {e}")
            print(f"Using local model at {model_path}")
    
    # Load model
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model not found at {model_path}")
    
    model = MLModel.load(model_path)
    model_version = model.version
    print(f"Model loaded: version {model_version}")


@app.on_event("startup")
async def startup_event():
    """Load model on startup."""
    version = os.getenv("MODEL_VERSION")
    load_model(version)
    print("API server started")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model_version": model_version,
        "model_loaded": model is not None
    }


@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "ready", "model_version": model_version}


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """Make prediction on input features.
    
    Args:
        request: Prediction request with features
        
    Returns:
        Prediction response with class and probabilities
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    REQUEST_COUNT.labels(model_version=model_version).inc()
    
    with REQUEST_DURATION.labels(model_version=model_version).time():
        try:
            # Convert to numpy array
            features = np.array(request.features).reshape(1, -1)
            
            # Make prediction
            prediction = model.predict(features)[0]
            probabilities = model.predict_proba(features)[0].tolist()
            
            # Update metrics
            PREDICTION_COUNTER.labels(
                model_version=model_version,
                prediction_class=str(int(prediction))
            ).inc()
            
            return PredictionResponse(
                prediction=int(prediction),
                probabilities=probabilities,
                model_version=model_version
            )
            
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Prediction error: {str(e)}")


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": "MLOps Model Serving API",
        "version": "1.0.0",
        "model_version": model_version,
        "endpoints": {
            "health": "/health",
            "ready": "/ready",
            "predict": "/predict",
            "metrics": "/metrics",
            "docs": "/docs"
        }
    }


def main():
    """Main entry point for serving API."""
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    
    uvicorn.run(
        "serve:app",
        host=host,
        port=port,
        reload=False,
        log_level="info"
    )


if __name__ == "__main__":
    main()
