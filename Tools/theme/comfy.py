"""Appel minimal à ComfyUI (http://127.0.0.1:8188) avec FLUX 2 Klein.

    from comfy import generate
    image = generate("prompt", width=1536, height=384, seed=1)   # PIL.Image RGB

Modèles attendus sur le serveur : flux-2-klein-4b-fp8 (diffusion_models),
qwen_3_4b (text_encoders), flux2-vae (vae), Flux_2-Turbo-LoRA_comfyui (loras).
"""

import io
import json
import time
import urllib.parse
import urllib.request
import uuid

from PIL import Image

SERVER = "http://127.0.0.1:8188"
STEPS = 8


def _workflow(prompt, width, height, seed):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux-2-klein-4b-fp8.safetensors",
                                                     "weight_dtype": "default"}},
        "2": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0],
              "lora_name": "Flux_2-Turbo-LoRA_comfyui.safetensors", "strength_model": 1.0}},
        "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "flux2"}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["3", 0], "text": prompt}},
        "5": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
        "6": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "7": {"class_type": "Flux2Scheduler", "inputs": {"steps": STEPS, "width": width, "height": height}},
        "8": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "euler"}},
        "9": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "10": {"class_type": "BasicGuider", "inputs": {"model": ["2", 0], "conditioning": ["4", 0]}},
        "11": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["9", 0], "guider": ["10", 0],
               "sampler": ["8", 0], "sigmas": ["7", 0], "latent_image": ["6", 0]}},
        "12": {"class_type": "VAEDecode", "inputs": {"samples": ["11", 0], "vae": ["5", 0]}},
        "13": {"class_type": "SaveImage", "inputs": {"images": ["12", 0], "filename_prefix": "nextstep_theme"}},
    }


def _post(path, payload):
    request = urllib.request.Request(SERVER + path, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read())


def _get(path):
    with urllib.request.urlopen(SERVER + path) as response:
        return response.read()


def generate(prompt, width=1536, height=384, seed=1, timeout=600):
    client = str(uuid.uuid4())
    queued = _post("/prompt", {"prompt": _workflow(prompt, width, height, seed), "client_id": client})
    prompt_id = queued["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        history = json.loads(_get("/history/" + prompt_id))
        entry = history.get(prompt_id)
        if entry and entry.get("outputs"):
            for output in entry["outputs"].values():
                for image in output.get("images", []):
                    query = urllib.parse.urlencode({"filename": image["filename"],
                                                    "subfolder": image["subfolder"], "type": image["type"]})
                    return Image.open(io.BytesIO(_get("/view?" + query))).convert("RGB")
        if entry and entry.get("status", {}).get("status_str") == "error":
            raise RuntimeError(json.dumps(entry["status"])[:2000])
        time.sleep(1)
    raise TimeoutError(prompt_id)
