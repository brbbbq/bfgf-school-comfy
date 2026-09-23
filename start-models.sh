#!/bin/bash
echo "=== Starting Vast ComfyUI Setup ==="

# 1. If main.py isn't in /workspace/ComfyUI, safely merge core ComfyUI into it
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "Restoring ComfyUI core files..."
    git clone https://github.com/comfyanonymous/ComfyUI.git /tmp/ComfyUI_core
    cp -rn /tmp/ComfyUI_core/* /workspace/ComfyUI/
    cp -n /tmp/ComfyUI_core/.* /workspace/ComfyUI/ 2>/dev/null || true
    rm -rf /tmp/ComfyUI_core
fi

# 2. Ensure target model directories exist
mkdir -p /workspace/ComfyUI/models/diffusion_models \
         /workspace/ComfyUI/models/text_encoders \
         /workspace/ComfyUI/models/vae \
         /workspace/ComfyUI/models/loras

# 3. Enable HF Transfer & Run Model Downloads
export HF_HUB_ENABLE_HF_TRANSFER=1
echo "--> Downloading Hugging Face models..."

python3 -c "
import os
from huggingface_hub import hf_hub_download

def get_hf_model(repo_id, filename, target_dir):
    print(f'Downloading {os.path.basename(filename)}...')
    try:
        cached_path = hf_hub_download(
            repo_id=repo_id, 
            filename=filename, 
            token=os.environ.get('HF_TOKEN'),
            cache_dir='/workspace/huggingface_cache'
        )
        target_path = os.path.join(target_dir, os.path.basename(filename))
        if os.path.lexists(target_path):
            os.remove(target_path)
        os.symlink(cached_path, target_path)
        print(f'Ready: {target_path}')
    except Exception as e:
        print(f'Error downloading {filename}: {e}')

get_hf_model('black-forest-labs/FLUX.2-klein-9b-fp8', 'flux-2-klein-9b-fp8.safetensors', '/workspace/ComfyUI/models/diffusion_models')
get_hf_model('Comfy-Org/vae-text-encorder-for-flux-klein-9b', 'split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors', '/workspace/ComfyUI/models/text_encoders')
get_hf_model('Comfy-Org/flux2-dev', 'split_files/vae/flux2-vae.safetensors', '/workspace/ComfyUI/models/vae')
get_hf_model('dx8152/Flux2-Klein-9B-Consistency', 'Klein-consistency.safetensors', '/workspace/ComfyUI/models/loras')
get_hf_model('jhsu/flux2_retro_comic_style', 'FLUX.2-klein-9B_Retro_comic_PULPKHOR_STYLE.safetensors', '/workspace/ComfyUI/models/loras')
"

echo "Model downloads complete!"

# 4. Revive ComfyUI
echo "Restarting ComfyUI service..."
supervisorctl update
supervisorctl restart comfyui || supervisorctl start comfyui
echo "=== All systems online ==="