#!/bin/bash
echo "Starting model downloads..."

# 1. Ensure target directories exist
mkdir -p /workspace/ComfyUI/models/diffusion_models \
         /workspace/ComfyUI/models/text_encoders \
         /workspace/ComfyUI/models/vae \
         /workspace/ComfyUI/models/loras

# 2. Enable the Hugging Face rust-based high-speed transfer engine globally
export HF_HUB_ENABLE_HF_TRANSFER=1

echo "--> Downloading Hugging Face models via high-speed hf_transfer..."

# 3. Your python download script goes here (Identical to your original file)
python3 -c "
import os
from huggingface_hub import hf_hub_download

def get_hf_model(repo_id, filename, target_dir):
    print(f'Downloading {os.path.basename(filename)}...')
    try:
        # This utilizes hf_transfer to pull at maximum datacenter gigabit speeds
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

# [1/5] FLUX.2 Klein 9B FP8
get_hf_model('black-forest-labs/FLUX.2-klein-9b-fp8', 'flux-2-klein-9b-fp8.safetensors', '/workspace/ComfyUI/models/diffusion_models')

# [2/5] Qwen 3 Text Encoder
get_hf_model('Comfy-Org/vae-text-encorder-for-flux-klein-9b', 'split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors', '/workspace/ComfyUI/models/text_encoders')

# [3/5] FLUX.2 VAE
get_hf_model('Comfy-Org/flux2-dev', 'split_files/vae/flux2-vae.safetensors', '/workspace/ComfyUI/models/vae')

# [4/5] Klein Consistency LoRA
get_hf_model('dx8152/Flux2-Klein-9B-Consistency', 'Klein-consistency.safetensors', '/workspace/ComfyUI/models/loras')

# [5/5] Retro Comic Pulpkhor LoRA (Hosted on your Hugging Face)
get_hf_model('jhsu/flux2_retro_comic_style', 'FLUX.2-klein-9B_Retro_comic_PULPKHOR_STYLE.safetensors', '/workspace/ComfyUI/models/loras')
"
echo "Model downloads complete!"