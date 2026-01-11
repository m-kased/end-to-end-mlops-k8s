"""
ML Model definition and utilities.
"""
import pickle
import os
from typing import Optional
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import pandas as pd


class MLModel:
    """Wrapper class for ML model with training and prediction capabilities."""
    
    def __init__(self, model: Optional[RandomForestClassifier] = None):
        """Initialize model.
        
        Args:
            model: Pre-trained model or None for new model
        """
        self.model = model or RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42
        )
        self.version = "1.0.0"
    
    def train(self, X: np.ndarray, y: np.ndarray) -> dict:
        """Train the model.
        
        Args:
            X: Feature matrix
            y: Target vector
            
        Returns:
            Dictionary with training metrics
        """
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        self.model.fit(X_train, y_train)
        
        # Evaluate
        train_score = self.model.score(X_train, y_train)
        test_score = self.model.score(X_test, y_test)
        
        y_pred = self.model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        metrics = {
            "train_score": float(train_score),
            "test_score": float(test_score),
            "accuracy": float(accuracy),
            "n_samples": len(X),
            "n_features": X.shape[1] if len(X.shape) > 1 else 1
        }
        
        return metrics
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """Make predictions.
        
        Args:
            X: Feature matrix
            
        Returns:
            Predictions array
        """
        return self.model.predict(X)
    
    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        """Get prediction probabilities.
        
        Args:
            X: Feature matrix
            
        Returns:
            Probability array
        """
        return self.model.predict_proba(X)
    
    def save(self, path: str) -> None:
        """Save model to disk.
        
        Args:
            path: Path to save model
        """
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            pickle.dump({
                'model': self.model,
                'version': self.version
            }, f)
    
    @classmethod
    def load(cls, path: str) -> 'MLModel':
        """Load model from disk.
        
        Args:
            path: Path to model file
            
        Returns:
            MLModel instance
        """
        with open(path, 'rb') as f:
            data = pickle.load(f)
        
        instance = cls(model=data['model'])
        instance.version = data.get('version', '1.0.0')
        return instance


def generate_sample_data(n_samples: int = 1000, n_features: int = 20) -> tuple:
    """Generate sample data for training.
    
    Args:
        n_samples: Number of samples
        n_features: Number of features
        
    Returns:
        Tuple of (X, y) arrays
    """
    np.random.seed(42)
    X = np.random.randn(n_samples, n_features)
    # Create binary classification target
    y = (X.sum(axis=1) > 0).astype(int)
    return X, y
