"""
Tests for ML model.
"""
import pytest
import numpy as np
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from src.model import MLModel, generate_sample_data


def test_model_initialization():
    """Test model initialization."""
    model = MLModel()
    assert model.model is not None
    assert model.version == "1.0.0"


def test_model_training():
    """Test model training."""
    model = MLModel()
    X, y = generate_sample_data(n_samples=100, n_features=10)
    
    metrics = model.train(X, y)
    
    assert 'train_score' in metrics
    assert 'test_score' in metrics
    assert 'accuracy' in metrics
    assert metrics['train_score'] > 0
    assert metrics['test_score'] > 0


def test_model_prediction():
    """Test model prediction."""
    model = MLModel()
    X, y = generate_sample_data(n_samples=100, n_features=10)
    model.train(X, y)
    
    predictions = model.predict(X[:5])
    assert len(predictions) == 5
    assert all(p in [0, 1] for p in predictions)


def test_model_save_load(tmp_path):
    """Test model save and load."""
    model = MLModel()
    X, y = generate_sample_data(n_samples=100, n_features=10)
    model.train(X, y)
    
    model_path = tmp_path / "test_model.pkl"
    model.save(str(model_path))
    
    loaded_model = MLModel.load(str(model_path))
    assert loaded_model.version == model.version
    
    # Test predictions match
    predictions_original = model.predict(X[:5])
    predictions_loaded = loaded_model.predict(X[:5])
    np.testing.assert_array_equal(predictions_original, predictions_loaded)
