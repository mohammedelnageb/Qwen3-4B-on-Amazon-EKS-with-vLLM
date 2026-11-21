"""Serve Qwen3-4B with vLLM on a Modal L4 GPU (OpenAI-compatible API).

Same model and vLLM flags as the EKS deployment, used for the GPU vs CPU comparison.

Deploy:  modal deploy modal/vllm_qwen.py
Stop:    modal app stop qwen-vllm
"""

import subprocess

import modal

MODEL_NAME = "Qwen/Qwen3-4B-Instruct-2507"
SERVED_MODEL_NAME = "qwen3-4b"
GPU_TYPE = "L4"  # same GPU as g6.xlarge on AWS
VLLM_PORT = 8000
MINUTES = 60  # seconds

vllm_image = (
    modal.Image.from_registry("nvidia/cuda:12.9.0-devel-ubuntu22.04", add_python="3.12")
    .entrypoint([])
    .uv_pip_install("vllm==0.21.0")
    .env({"HF_XET_HIGH_PERFORMANCE": "1"})
)

# Cache model weights and vLLM compile artifacts between cold starts
hf_cache_vol = modal.Volume.from_name("huggingface-cache", create_if_missing=True)
vllm_cache_vol = modal.Volume.from_name("vllm-cache", create_if_missing=True)

app = modal.App("qwen-vllm")


@app.server(
    image=vllm_image,
    gpu=GPU_TYPE,
    scaledown_window=5 * MINUTES,  # shut down after 5 idle minutes to save credits
    startup_timeout=15 * MINUTES,
    volumes={
        "/root/.cache/huggingface": hf_cache_vol,
        "/root/.cache/vllm": vllm_cache_vol,
    },
    secrets=[modal.Secret.from_name("vllm-api-key")],  # provides VLLM_API_KEY
    port=VLLM_PORT,
    unauthenticated=True,  # vLLM itself enforces the API key
)
class Server:
    @modal.enter()
    def start(self):
        cmd = [
            "vllm",
            "serve",
            MODEL_NAME,
            "--served-model-name",
            SERVED_MODEL_NAME,
            "--host",
            "0.0.0.0",
            "--port",
            str(VLLM_PORT),
            "--max-model-len",
            "8192",
            "--gpu-memory-utilization",
            "0.90",
        ]
        print(*cmd)
        self.process = subprocess.Popen(cmd)

    @modal.exit()
    def stop(self):
        self.process.terminate()
