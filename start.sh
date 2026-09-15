#!/bin/bash
echo "Starting container setup..."

# 1. Start OpenSSH Server
service ssh start

# 2. Ensure target directories exist
mkdir -p /workspace/ComfyUI/models/diffusion_models \
         /workspace/ComfyUI/models/text_encoders \
         /workspace/ComfyUI/models/vae \
         /workspace/ComfyUI/models/loras

# 3. Enable the Xet high-performance transfer engine globally
export HF_XET_HIGH_PERFORMANCE=1

echo "--> Downloading Hugging Face models via high-speed hf_xet..."

# We use Python here because the huggingface_hub library natively handles the hf_xet multi-threading
python3 -c "
import os
from huggingface_hub import hf_hub_download

def get_hf_model(repo_id, filename, target_dir):
    print(f'Downloading {os.path.basename(filename)}...')
    try:
        # This utilizes hf_xet to pull at maximum datacenter gigabit speeds
        cached_path = hf_hub_download(
            repo_id=repo_id, 
            filename=filename, 
            token=os.environ.get('HF_TOKEN')
        )
        # Symlink the file from the cache to the ComfyUI folder (Takes 0 seconds, uses no extra disk space)
        target_path = os.path.join(target_dir, os.path.basename(filename))
        if not os.path.exists(target_path):
            os.symlink(cached_path, target_path)
        print(f'Ready: {target_path}')
    except Exception as e:
        print(f'Error downloading {filename}: {e}')

# [1/4] FLUX.2 Klein 9B FP8
get_hf_model('black-forest-labs/FLUX.2-klein-9b-fp8', 'flux-2-klein-9b-fp8.safetensors', '/workspace/ComfyUI/models/diffusion_models')

# [2/4] Qwen 3 Text Encoder
get_hf_model('Comfy-Org/vae-text-encorder-for-flux-klein-9b', 'split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors', '/workspace/ComfyUI/models/text_encoders')

# [3/4] FLUX.2 VAE
get_hf_model('Comfy-Org/flux2-dev', 'split_files/vae/flux2-vae.safetensors', '/workspace/ComfyUI/models/vae')

# [4/4] Klein Consistency LoRA
get_hf_model('dx8152/Flux2-Klein-9B-Consistency', 'Klein-consistency.safetensors', '/workspace/ComfyUI/models/loras')
"

# 4. Download Civitai Pulpkhor LoRA (Civitai allows aria2c)
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