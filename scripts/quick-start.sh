#!/bin/bash
# Quick start script for local development

set -e

echo "MLOps Quick Start"
echo "==================="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required"
    exit 1
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create models directory
mkdir -p models

# Set PYTHONPATH to include project root
export PYTHONPATH="${PWD}:${PYTHONPATH}"

# Train model
echo "Training model..."
python -m src.train --output-dir ./models

# Start serving API
echo "Starting serving API..."
echo "API will be available at http://localhost:8000"
echo "Press Ctrl+C to stop"
python -m src.serve
