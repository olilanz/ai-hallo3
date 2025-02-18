#!/bin/bash

set -euo pipefail  # Exit on error, show commands, handle pipes safely

echo "🔧 Starting Hallo3 container startup script..."

# Set up environment variables
H3_AUTO_UPDATE=${H3_AUTO_UPDATE:-0}

CACHE_HOME="/workspace/cache"
export HF_HOME="${CACHE_HOME}/huggingface"
export TORCH_HOME="${CACHE_HOME}/torch"
CKPTS_HOME="${CACHE_HOME}/ckpts"
OUTPUT_HOME="/workspace/output"

echo "📂 Setting up cache directories..."
mkdir -p "${CACHE_HOME}" "${HF_HOME}" "${TORCH_HOME}" "${CKPTS_HOME}" "${OUTPUT_HOME}"

# Clone or update HVGP
REPO_HOME="${CACHE_HOME}/Hallo3"
if [ ! -d "$REPO_HOME" ]; then
    echo "📥 Unpacking Hallo repository..."
    mkdir -p "$REPO_HOME"
    tar -xzvf repo.tar.gz --strip-components=1 -C "$REPO_HOME"
fi
if [[ "$H3_AUTO_UPDATE" == "1" ]]; then
    echo "🔄 Updating the Hallo3 repository..."
    git -C "$REPO_HOME" reset --hard
    git -C "$REPO_HOME" pull
fi

# Ensure symlinks for models & output
ln -sfn "${CKPTS_HOME}" "$REPO_HOME/pretrained_models"
ln -sfn "${OUTPUT_HOME}" "$REPO_HOME/output"

# Virtual environment setup
VENV_HOME="${CACHE_HOME}/venv"
echo "📦 Setting up Python virtual environment..."
if [ ! -d "$VENV_HOME" ]; then
    # Create virtual environment, but re-use globally installed packages if available (e.g. via base container)
    python3 -m venv "$VENV_HOME" --system-site-packages
fi
source "${VENV_HOME}/bin/activate"

# Ensure latest pip version
pip install --no-cache-dir --upgrade pip wheel

# Install required dependencies
echo "📦 Installing Python dependencies..."
pip install --no-cache-dir \
    torch==2.4.0 \
    xformers \
    gradio==4.*
pip install --no-cache-dir -r "$REPO_HOME/requirements.txt"
pip install --no-cache-dir \
    "huggingface_hub[cli]"

# Download model only if not already present
if [ ! -d "${CKPTS_HOME}/hallo3" ]; then
    echo "📥 Downloading fudan-generative-ai/hallo3 model..."
    huggingface-cli download fudan-generative-ai/hallo3 --local-dir "$CKPTS_HOME"
else
    echo "✅ Model already exists in ${CKPTS_HOME}, skipping download."
fi

# patching the start-up function, so that the script listens on the public network interface
if grep -q 'interface.launch(server_name="0.0.0.0", server_port=7860)' "$REPO_HOME/hallo3/app.py"; then
    echo "Launch function is already patched."
else
    # Replace interface.launch(share=True) with interface.launch(server_name="0.0.0.0", server_port=7860)
    sed -i 's/interface.launch(share=True)/interface.launch(server_name="0.0.0.0", server_port=7860)/g' "$REPO_HOME/hallo3/app.py"
    echo "Launch function patched with server_name=\"0.0.0.0\", server_port=7860."
fi

# Start the service
echo "🚀 Starting Hallo3 service..."
cd "$REPO_HOME"
python3 -u hallo3/app.py 2>&1 | tee "${CACHE_HOME}/output.log"
echo "❌ The HVGP service has terminated."
