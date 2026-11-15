#!/usr/bin/env python3
"""Cuts portrait sample photos out of the Stitch design mock-ups (dev tool, output is committed)."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "screenshot-assets"
OUT.mkdir(parents=True, exist_ok=True)

# name: (source, crop box in source pixels, patch boxes to smooth viewfinder overlays)
CROPS = {
    "photo-1": ("01-viewfinder.png", (40, 285, 740, 1235), [(285, 680, 495, 820)]),
    "photo-2": ("01-viewfinder.png", (285, 815, 600, 1235), []),
    "photo-3": ("02-darkroom.png", (48, 1290, 305, 1600), []),
    "photo-4": ("04-import.png", (462, 365, 690, 690), []),
    "photo-5": ("01-viewfinder.png", (45, 285, 380, 676), []),
    # Landscape, for the Import screen's negative frame (not used as a roll frame).
    "photo-6": ("01-viewfinder.png", (40, 330, 740, 780), [(285, 680, 495, 820)]),
}


def remove_dot_grid(image):
    """The viewfinder mock-up has a 2x2 px dot every 6 px (phase 4,4); interpolate those pixels from their neighbours."""
    a = np.asarray(image).astype(float)
    out = a.copy()
    for y0 in range(4, a.shape[0] - 3, 6):
        for x0 in range(4, a.shape[1] - 3, 6):
            for dy in (0, 1):
                for dx in (0, 1):
                    horizontal = a[y0 + dy, x0 - 1] * (2 - dx) / 3 + a[y0 + dy, x0 + 2] * (1 + dx) / 3
                    vertical = a[y0 - 1, x0 + dx] * (2 - dy) / 3 + a[y0 + 2, x0 + dx] * (1 + dy) / 3
                    out[y0 + dy, x0 + dx] = (horizontal + vertical) / 2
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


for name, (source, box, patches) in CROPS.items():
    image = Image.open(ROOT / "design" / source).convert("RGB")
    # Remove the mock-up's dot-grid overlay and the thin focus box.
    if source == "01-viewfinder.png":
        image = remove_dot_grid(image)
    for patch in patches:
        region = image.crop(patch).filter(ImageFilter.MedianFilter(7)).filter(ImageFilter.GaussianBlur(1.5))
        image.paste(region, patch[:2])
    photo = image.crop(box)
    scale = 1800 / photo.height
    photo = photo.resize((round(photo.width * scale), 1800), Image.LANCZOS)
    photo = photo.filter(ImageFilter.UnsharpMask(radius=3, percent=60, threshold=2))
    photo.save(OUT / f"{name}.jpg", quality=92)
    print(name, photo.size)
