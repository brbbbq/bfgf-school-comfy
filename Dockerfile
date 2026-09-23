# 1. Inherit Vast's highly optimized image (Includes Syncthing, Jupyter, SSH, and ComfyUI)
FROM vastai/comfy:v0.35.0-cuda-13.2-py312

# 2. Switch to root to install Node.js and aria2
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y --no-install-recommends \
    nodejs aria2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Define where Vast keeps ComfyUI
ENV COMFYUI_DIR=/workspace/ComfyUI

# 3. Clone Custom Nodes (Vast already installed core ComfyUI, so we skip that)
WORKDIR ${COMFYUI_DIR}/custom_nodes
RUN git clone https://github.com/rgthree/rgthree-comfy.git && cd rgthree-comfy && git checkout 2c5342a && cd .. \
    && git clone https://github.com/kijai/ComfyUI-KJNodes.git && cd ComfyUI-KJNodes && git checkout 5710537 && cd .. \
    && git clone https://github.com/chrisgoringe/cg-use-everywhere.git && cd cg-use-everywhere && git checkout 50ae9f8 && cd .. \
    && git clone https://github.com/cosmicbuffalo/comfyui-mobile-frontend.git && cd comfyui-mobile-frontend && git checkout 6255f22 && cd .. \
    && git clone https://github.com/slahiri/ComfyUI-Workflow-Models-Downloader.git && cd ComfyUI-Workflow-Models-Downloader && git checkout c3ef4db && cd ..

# 4. Install Node Dependencies (--no-cache-dir prevents gigabytes of bloat)
RUN pip install --no-cache-dir sageattention==1.0.6 huggingface_hub hf_transfer \
    && pip install --no-cache-dir -r rgthree-comfy/requirements.txt || true \
    && pip install --no-cache-dir -r ComfyUI-KJNodes/requirements.txt || true \
    && pip install --no-cache-dir -r cg-use-everywhere/requirements.txt || true \
    && pip install --no-cache-dir -r comfyui-mobile-frontend/requirements.txt || true \
    && pip install --no-cache-dir -r ComfyUI-Workflow-Models-Downloader/requirements.txt || true \
    && rm -rf /root/.cache

# 5. Build Mobile Frontend & Prune Immediately
WORKDIR ${COMFYUI_DIR}/custom_nodes/comfyui-mobile-frontend
RUN npm install \
    && npm run build \
    && npm cache clean --force \
    && rm -rf node_modules /root/.npm

# 6. Setup your Model Download Script
COPY start-models.sh /workspace/start-models.sh
RUN chmod +x /workspace/start-models.sh

# Return to workspace
WORKDIR /workspace