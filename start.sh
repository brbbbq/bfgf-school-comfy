#!/bin/bash
echo "Starting container setup..."

# 1. Start OpenSSH Server
service ssh start

# 2. Ensure target directories exist
mkdir -p /workspace/ComfyUI/models/diffusion_models \
         /workspace/ComfyUI/models/text_encoders \
         /workspace/ComfyUI/models/vae \
         /workspace/ComfyUI/models/loras

# 3. Download Hugging Face Models via Python API
# (Skips automatically if files already exist on disk)
python3 -u - << 'EOF'
import os, shutil
from huggingface_hub import hf_hub_download

token = os.environ.get('HF_TOKEN')
models_dir = "/workspace/ComfyUI/models"

# 1. FLUX.2 Klein 9B FP8
flux_path = os.path.join(models_dir, "diffusion_models/flux-2-klein-9b-fp8.safetensors")
if not os.path.exists(flux_path):
    print("--> [1/4] Downloading FLUX.2 Klein 9B FP8...", flush=True)
    hf_hub_download(
        repo_id='black-forest-labs/FLUX.2-klein-9b-fp8',
        filename='flux-2-klein-9b-fp8.safetensors',
        local_dir=os.path.join(models_dir, "diffusion_models"),
        token=token
    )
else:
    print("--> FLUX.2 Klein 9B already exists. Skipping.")

# 2. Qwen 3 Text Encoder
qwen_path = os.path.join(models_dir, "text_encoders/qwen_3_8b_fp8mixed.safetensors")
if not os.path.exists(qwen_path):
    print("--> [2/4] Downloading Qwen 3 Text Encoder...", flush=True)
    downloaded = hf_hub_download(
        repo_id='Comfy-Org/vae-text-encorder-for-flux-klein-9b',
        filename='split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors',
        token=token
    )
    shutil.copy(downloaded, qwen_path)
else:
    print("--> Qwen 3 Text Encoder already exists. Skipping.")

# 3. FLUX.2 VAE
vae_path = os.path.join(models_dir, "vae/flux2-vae.safetensors")
if not os.path.exists(vae_path):
    print("--> [3/4] Downloading FLUX.2 VAE...", flush=True)
    downloaded = hf_hub_download(
        repo_id='Comfy-Org/flux2-dev',
        filename='split_files/vae/flux2-vae.safetensors',
        token=token
    )
    shutil.copy(downloaded, vae_path)
else:
    print("--> FLUX.2 VAE already exists. Skipping.")

# 4. Klein Consistency LoRA
lora_path = os.path.join(models_dir, "loras/Klein-consistency.safetensors")
if not os.path.exists(lora_path):
    print("--> [4/4] Downloading Klein Consistency LoRA...", flush=True)
    hf_hub_download(
        repo_id='dx8152/Flux2-Klein-9B-Consistency',
        filename='Klein-consistency.safetensors',
        local_dir=os.path.join(models_dir, "loras"),
        token=token
    )
else:
    print("--> Klein Consistency LoRA already exists. Skipping.")
EOF

# 4. Download Civitai Pulpkhor LoRA with Token Support & Size Validation
PULPKHOR_FILE="/workspace/ComfyUI/models/loras/flux2-klein-9b-retro-comic-pulpkhor.safetensors"

if [ ! -f "$PULPKHOR_FILE" ]; then
    echo "--> [5/5] Downloading Pulpkhor LoRA from Civitai..."
    
    CIVITAI_URL="https://civitai.com/api/download/models/2713511"
    if [ -n "$CIVITAI_TOKEN" ]; then
        CIVITAI_URL="${CIVITAI_URL}?token=${CIVITAI_TOKEN}"
    fi

    curl -L -A "Mozilla/5.0" "$CIVITAI_URL" -o "$PULPKHOR_FILE"

    # Validation: Real LoRA is ~70-80 MB. If less than 1 MB, it's an error page.
    FILESIZE=$(stat -c%s "$PULPKHOR_FILE" 2>/dev/null || echo 0)
    if [ "$FILESIZE" -lt 1000000 ]; then
        echo "WARNING: Civitai download returned an authentication/login error (size: ${FILESIZE} bytes)."
        echo "Please provide CIVITAI_TOKEN in Vast environment variables to download restricted models."
        rm -f "$PULPKHOR_FILE"
    else
        echo "Civitai Pulpkhor LoRA verified successfully (${FILESIZE} bytes)."
    fi
else
    echo "--> Pulpkhor LoRA already exists. Skipping."
fi

# 5. Launch ComfyUI
echo "Starting ComfyUI..."
cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8080 --enable-manager