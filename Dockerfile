# 1. Base Image
FROM pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# 2. System packages + build-essential + Node.js + OpenSSH Server
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl libgl1 libglib2.0-0 build-essential \
    openssh-server \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && mkdir -p /var/run/sshd /root/.ssh \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 3. Clone ComfyUI Core & Lock Commit
ENV COMFYUI_COMMIT=1f641fd9337f0ec4d635a28415a8d25a8d15f753
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI \
    && cd /workspace/ComfyUI \
    && git checkout ${COMFYUI_COMMIT}

WORKDIR /workspace/ComfyUI

# 4. Core dependencies with --upgrade (Enables DynamicVRAM and comfy_kitchen CUDA backend)
RUN pip install --no-cache-dir --upgrade -r requirements.txt \
    && pip install --no-cache-dir -r manager_requirements.txt \
    && pip install --no-cache-dir sageattention==1.0.6 huggingface_hub \
    && rm -rf /root/.cache

# 5. Clone Custom Nodes & Lock Commits
WORKDIR /workspace/ComfyUI/custom_nodes
RUN git clone https://github.com/rgthree/rgthree-comfy.git && cd rgthree-comfy && git checkout 2c5342a && cd .. \
    && git clone https://github.com/kijai/ComfyUI-KJNodes.git && cd ComfyUI-KJNodes && git checkout 5710537 && cd .. \
    && git clone https://github.com/chrisgoringe/cg-use-everywhere.git && cd cg-use-everywhere && git checkout 50ae9f8 && cd .. \
    && git clone https://github.com/cosmicbuffalo/comfyui-mobile-frontend.git && cd comfyui-mobile-frontend && git checkout 6255f22 && cd .. \
    && git clone https://github.com/Delcado19/ComfyUI-NAG.git && cd ComfyUI-NAG && git checkout 2355279 && cd ..

# 6. Install Node dependencies without cache
RUN pip install --no-cache-dir -r /workspace/ComfyUI/custom_nodes/rgthree-comfy/requirements.txt || true \
    && pip install --no-cache-dir -r /workspace/ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt || true \
    && pip install --no-cache-dir -r /workspace/ComfyUI/custom_nodes/cg-use-everywhere/requirements.txt || true \
    && pip install --no-cache-dir -r /workspace/ComfyUI/custom_nodes/comfyui-mobile-frontend/requirements.txt || true \
    && pip install --no-cache-dir -r /workspace/ComfyUI/custom_nodes/ComfyUI-NAG/requirements.txt || true \
    && rm -rf /root/.cache

# 7. Build Mobile Frontend & Prune node_modules Immediately
WORKDIR /workspace/ComfyUI/custom_nodes/comfyui-mobile-frontend
RUN npm install \
    && npm run build \
    && npm cache clean --force \
    && rm -rf node_modules /root/.npm

# 8. Setup Boot Script
WORKDIR /workspace/ComfyUI
COPY start.sh /workspace/ComfyUI/start.sh
RUN chmod +x /workspace/ComfyUI/start.sh

# Expose both ComfyUI (8080) and SSH (22)
EXPOSE 8080 22

CMD ["bash", "-c", "curl -fsSL https://raw.githubusercontent.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>/main/start.sh -o /workspace/ComfyUI/start.sh && chmod +x /workspace/ComfyUI/start.sh && /workspace/ComfyUI/start.sh"]