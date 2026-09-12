#!/bin/bash
echo "Starting container setup..."

# 1. Start OpenSSH Server
service ssh start

mkdir -p ./models/diffusion_models ./models/text_encoders ./models/vae ./models/loras

# 2. Hugging Face Authentication (if token provided)
if [ -n "$HF_TOKEN" ]; then
    echo "HF_TOKEN detected. Authenticating..."
    huggingface-cli login --token "$HF_TOKEN"
fi

# 3. Automated Model Downloads (Skip if already downloaded)
if [ ! -f "./models/diffusion_models/flux-2-klein-9b-fp8.safetensors" ]; then
    echo "Downloading FLUX.2 Klein 9B..."
    huggingface-cli download black-forest-labs/FLUX.2-klein-9b-fp8 \
        flux-2-klein-9b-fp8.safetensors \
        --local-dir ./models/diffusion_models
fi

if [ ! -f "./models/text_encoders/qwen_3_8b_fp8mixed.safetensors" ]; then
    echo "Downloading Qwen 3 Text Encoder..."
    huggingface-cli download Comfy-Org/vae-text-encorder-for-flux-klein-9b \
        split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors \
        --local-dir /tmp/hf_qwen \
        && mv /tmp/hf_qwen/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors ./models/text_encoders/ \
        && rm -rf /tmp/hf_qwen
fi

if [ ! -f "./models/vae/flux2-vae.safetensors" ]; then
    echo "Downloading FLUX.2 VAE..."
    huggingface-cli download Comfy-Org/flux2-dev \
        split_files/vae/flux2-vae.safetensors \
        --local-dir /tmp/hf_vae \
        && mv /tmp/hf_vae/split_files/vae/flux2-vae.safetensors ./models/vae/ \
        && rm -rf /tmp/hf_vae
fi

if [ ! -f "./models/loras/Klein-consistency.safetensors" ]; then
    echo "Downloading Klein Consistency LoRA..."
    huggingface-cli download dx8152/Flux2-Klein-9B-Consistency \
        Klein-consistency.safetensors \
        --local-dir ./models/loras
fi

if [ ! -f "./models/loras/flux2-klein-9b-retro-comic-pulpkhor.safetensors" ]; then
    echo "Downloading Pulpkhor LoRA..."
    curl -L "https://civitai.com/api/download/models/2413450" \
        -o ./models/loras/flux2-klein-9b-retro-comic-pulpkhor.safetensors
fi

# 4. Launch ComfyUI
echo "Starting ComfyUI..."
python3 main.py --listen 0.0.0.0 --port 8080 --enable-manager