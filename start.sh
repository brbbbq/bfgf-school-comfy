#!/bin/bash
echo "Starting container setup..."

# 1. Hugging Face Authentication & Conditional Model Downloads
if [ -z "$HF_TOKEN" ]; then
    echo "No HF_TOKEN provided in environment variables. Skipping HF downloads."
else
    echo "HF_TOKEN detected. Authenticating..."
    huggingface-cli login --token "$HF_TOKEN"
    
    # Conditional download: Skips download if file already exists on persistent storage
    if [ ! -f "./models/checkpoints/sd_xl_base_1.0.safetensors" ]; then
        echo "Downloading SDXL Base..."
        huggingface-cli download stabilityai/stable-diffusion-xl-base-1.0 \
            sd_xl_base_1.0.safetensors \
            --local-dir ./models/checkpoints
    else
        echo "Model already exists. Skipping download."
    fi
fi

# 2. Launch ComfyUI
# Added --enable-manager to expose the built-in Manager UI
echo "Starting ComfyUI..."
python3 main.py --listen 0.0.0.0 --port 8080 --enable-manager