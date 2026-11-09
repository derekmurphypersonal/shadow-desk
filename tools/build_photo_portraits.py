"""Generate photographic portraits of the (fictional) cabinet with a local open model.

Model: Realistic Vision V5.1 (CreativeML OpenRAIL-M) + sd-vae-ft-mse + LCM-LoRA SD1.5 (OpenRAIL++).
Runs on CPU. Every person here is invented; prompts never name or describe real people.

    pip install torch diffusers transformers accelerate peft safetensors pillow
    python3 tools/build_photo_portraits.py --models /opt/models [--only "Ray Castellano"] [--seed-offset 0]
"""
import argparse
import json
import os
import sys

import torch
from diffusers import AutoencoderKL, LCMScheduler, StableDiffusionPipeline
from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "portraits")

SETTING = {
    "flag": "blurred american flag behind",
    "office": "blurred wood-panelled office behind",
    "navy": "against a plain dark navy studio backdrop",
    "grey": "against a mottled grey studio backdrop",
    "window": "blurred office window behind",
}

# name: (description, setting, seed)
PEOPLE = {
    "Margaret Holloway": ("a 62 year old white woman with silver grey hair in a short bob, thin reading glasses, pearl necklace, navy blazer over a cream silk blouse, composed confident expression", "flag", 11),
    "Daniel Okafor": ("a 52 year old black man of nigerian descent, close cropped black hair, neat short beard, charcoal suit, white shirt, burgundy tie, small flag lapel pin, warm diplomatic smile", "office", 23),
    "Ray Castellano": ("a 64 year old italian american man, completely bald head, grey moustache, dark navy suit, navy tie, stern expression, retired general, medium shot", "flag", 38),
    "Evelyn Strand": ("a 50 year old white scandinavian woman, blonde hair pulled back in a bun, grey tailored suit, light blue blouse, small earrings, sharp intelligent gaze", "window", 41),
    "Victor Lindqvist": ("a 47 year old white man, brown hair with a side parting, rectangular glasses, charcoal suit, navy tie, slight knowing smile", "navy", 53),
    "Ruth Abernathy": ("a 60 year old black woman, short curly grey hair, black turtleneck under a black blazer, calm unreadable expression, intelligence director", "grey", 67),
    "Samuel Ito": ("a 58 year old japanese american man, salt and pepper hair side parted, tortoiseshell glasses, navy suit, teal tie, thoughtful expression", "office", 71),
    "Alan Pryce": ("a 45 year old white man, short brown hair, clean shaven, navy suit, red tie, earnest expression", "flag", 83),
    "Grace Whitfield": ("a 44 year old black woman, long straight black hair, burgundy blazer, cream blouse, gold earrings, confident smile", "office", 97),
    "Tomas Reyes": ("a 49 year old hispanic man, short black hair, thick black moustache, grey suit, gold tie, friendly expression", "window", 101),
    "Hannah Cole": ("a 41 year old white woman, auburn hair in a chin length bob, teal blazer, white blouse, determined expression", "grey", 113),
    "Marcus Bell": ("a 55 year old black man, shaved head, full grey beard, charcoal suit, green tie, broad shoulders, serious expression", "flag", 127),
    "Ingrid Sato": ("a 46 year old japanese american woman, black hair in a sleek bob, black turtleneck, black blazer, thin black glasses, cool analytical expression", "navy", 131),
    "Paul Navarro": ("a 63 year old hispanic man, grey hair side parted, navy suit, burgundy tie, kind tired eyes", "office", 149),
    "Lena Kowalski": ("a 43 year old white woman of polish descent, long blonde hair, navy blazer, ivory blouse, small earrings, poised expression", "window", 151),
    "Owen Marsh": ("a 39 year old white man, short auburn hair, short auburn beard, camel coloured suit, navy tie, energetic expression", "grey", 163),
    "Priya Raman": ("a 47 year old indian american woman, black hair in a low bun, teal blazer, white blouse, gold earrings, focused expression", "office", 173),
    "Carl Dunmore": ("a 68 year old white man, bald with white hair on the sides, white moustache, wire glasses, grey suit, red tie, gruff expression", "navy", 181),
    "June Halvorsen": ("a 66 year old white woman, short white hair, burgundy blazer, ivory blouse, pearl earrings, wise expression", "flag", 191),
}

PROMPT = ("RAW photo, close-up head and shoulders official portrait of {desc}, {setting}, "
          "soft studio light, 85mm, photorealistic, detailed skin")
NEG = ("(deformed iris, deformed pupils, semi-realistic, cgi, 3d, render, sketch, cartoon, drawing, anime:1.4), "
       "text, watermark, logo, cropped head, out of frame, worst quality, low quality, jpeg artifacts, ugly, "
       "duplicate, deformed, blurry, bad anatomy, extra fingers, hands, cross-eyed, asymmetric eyes")


def load(models: str) -> StableDiffusionPipeline:
    vae = AutoencoderKL.from_pretrained(os.path.join(models, "vae"), torch_dtype=torch.float32)
    pipe = StableDiffusionPipeline.from_pretrained(os.path.join(models, "rv51"), vae=vae, torch_dtype=torch.float32,
                                                   safety_checker=None, requires_safety_checker=False)
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe.load_lora_weights(os.path.join(models, "lcm"), weight_name="pytorch_lora_weights.safetensors")
    pipe.fuse_lora()
    pipe.set_progress_bar_config(disable=True)
    torch.set_num_threads(os.cpu_count() or 2)
    return pipe


def finish(img: Image.Image) -> Image.Image:
    # Square crop biased to the top (head and shoulders), gentle grade.
    w, h = img.size
    side = min(w, h)
    top = int((h - side) * 0.15)
    img = img.crop(((w - side) // 2, top, (w - side) // 2 + side, top + side))
    img = img.resize((512, 512), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.04)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))
    return img


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", default="/opt/models")
    ap.add_argument("--only", default="")
    ap.add_argument("--seed-offset", type=int, default=0)
    ap.add_argument("--steps", type=int, default=6)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    pipe = load(a.models)
    os.makedirs(a.out, exist_ok=True)
    names = [n for n in PEOPLE if not a.only or n in a.only.split(",")]
    for name in names:
        desc, setting, seed = PEOPLE[name]
        g = torch.Generator().manual_seed(seed + a.seed_offset)
        img = pipe(PROMPT.format(desc=desc, setting=SETTING[setting]), negative_prompt=NEG, width=512, height=640,
                   num_inference_steps=a.steps, guidance_scale=1.5, generator=g).images[0]
        path = os.path.join(a.out, name.lower().replace(" ", "_") + ".png")
        finish(img).save(path)
        print(name, "->", path, flush=True)


if __name__ == "__main__":
    sys.exit(main())
