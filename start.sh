#!/bin/bash
echo "Starting container setup..."

# 1. Start OpenSSH Server
service ssh start

# 2. Ensure target directories exist
mkdir -p /workspace/ComfyUI/models/diffusion_models \
         /workspace/ComfyUI/models/text_encoders \
         /workspace/ComfyUI/models/vae \
         /workspace/ComfyUI/models/loras

# Helper function for fast multi-threaded downloads via aria2c
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local auth_header="$4"

    if [ -f "$dir/$filename" ]; then
        echo "--> [Skipped] $filename already exists."
    else
        echo "--> Downloading $filename via aria2c (16 parallel connections)..."
        if [ -n "$auth_header" ]; then
            aria2c -x 16 -s 16 -k 1M --header="$auth_header" -d "$dir" -o "$filename" "$url"
        else
            aria2c -x 16 -s 16 -k 1M -d "$dir" -o "$filename" "$url"
        fi
    fi
}

HF_AUTH=""
if [ -n "$HF_TOKEN" ]; then
    HF_AUTH="Authorization: Bearer $HF_TOKEN"
fi

# 3. Fast Parallel Downloads for Hugging Face Models
# [1/4] FLUX.2 Klein 9B FP8
download_file \
    "https://huggingface.co/black-forest-labs/FLUX.2-klein-9b-fp8/resolve/main/flux-2-klein-9b-fp8.safetensors" \
    "/workspace/ComfyUI/models/diffusion_models" \
    "flux-2-klein-9b-fp8.safetensors" \
    "$HF_AUTH"

# [2/4] Qwen 3 Text Encoder
download_file \
    "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
    "/workspace/ComfyUI/models/text_encoders" \
    "qwen_3_8b_fp8mixed.safetensors" \
    "$HF_AUTH"

# [3/4] FLUX.2 VAE
download_file \
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "/workspace/ComfyUI/models/vae" \
    "flux2-vae.safetensors" \
    "$HF_AUTH"

# [4/4] Klein Consistency LoRA
download_file \
    "https://huggingface.co/dx8152/Flux2-Klein-9B-Consistency/resolve/main/Klein-consistency.safetensors" \
    "/workspace/ComfyUI/models/loras" \
    "Klein-consistency.safetensors" \
    "$HF_AUTH"

# 4. Download Civitai Pulpkhor LoRA with aria2c
PULPKHOR_FILE="/workspace/ComfyUI/models/loras/flux2-klein-9b-retro-comic-pulpkhor.safetensors"
if [ ! -f "$PULPKHOR_FILE" ]; then
    echo "--> Downloading Pulpkhor LoRA from Civitai via aria2c..."
    CIVITAI_URL="https://civitai.com/api/download/models/2713511"
    if [ -n "$CIVITAI_TOKEN" ]; then
        CIVITAI_URL="${CIVITAI_URL}?token=${CIVITAI_TOKEN}"
    fi

    aria2c -x 16 -s 16 -k 1M -U "Mozilla/5.0" -d "/workspace/ComfyUI/models/loras" -o "flux2-klein-9b-retro-comic-pulpkhor.safetensors" "$CIVITAI_URL"

    FILESIZE=$(stat -c%s "$PULPKHOR_FILE" 2>/dev/null || echo 0)
    if [ "$FILESIZE" -lt 1000000 ]; then
        echo "WARNING: Civitai download returned an authentication error (size: ${FILESIZE} bytes)."
        rm -f "$PULPKHOR_FILE"
    else
        echo "Civitai Pulpkhor LoRA verified successfully (${FILESIZE} bytes)."
    fi
else
    echo "--> [Skipped] Pulpkhor LoRA already exists."
fi

# 5. Launch ComfyUI
echo "Starting ComfyUI..."
cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8080 --enable-manager