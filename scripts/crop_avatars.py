#!/usr/bin/env python3
"""
Smart face-crop script for ANIMINA dev seed avatars.

Uses face_recognition (dlib) to detect faces, then crops a square region
centered on the face with ~40% padding (head + shoulders). Falls back to
center crop if no face is detected. Output is 800x800 JPEG.

Usage:
    pip install face_recognition Pillow
    python scripts/crop_avatars.py

Reads from:  priv/static/images/seeds/avatars/incoming/
Writes to:   priv/static/images/seeds/avatars/incoming/cropped/
"""

import os
import sys
from pathlib import Path

try:
    import face_recognition
    from PIL import Image
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install face_recognition Pillow")
    sys.exit(1)

# Paths relative to project root
PROJECT_ROOT = Path(__file__).resolve().parent.parent
INPUT_DIR = PROJECT_ROOT / "priv" / "static" / "images" / "seeds" / "avatars" / "incoming"
OUTPUT_DIR = INPUT_DIR / "cropped"

TARGET_SIZE = 800
FACE_PADDING = 0.4  # 40% padding around face bounding box
JPEG_QUALITY = 90

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"}


def crop_around_face(image_path: Path, output_path: Path) -> str:
    """Crop image around detected face. Returns 'face' or 'fallback'."""

    # Load for face detection (face_recognition uses numpy arrays)
    img_array = face_recognition.load_image_file(str(image_path))
    face_locations = face_recognition.face_locations(img_array)

    # Open with Pillow for the actual crop
    img = Image.open(image_path)
    img_width, img_height = img.size

    if face_locations:
        # Use the largest face if multiple detected
        if len(face_locations) > 1:
            # face_locations returns (top, right, bottom, left)
            face_locations.sort(key=lambda f: (f[2] - f[0]) * (f[1] - f[3]), reverse=True)

        top, right, bottom, left = face_locations[0]

        face_width = right - left
        face_height = bottom - top
        face_center_x = left + face_width // 2
        face_center_y = top + face_height // 2

        # Calculate crop size: face dimension + padding, then make square
        crop_size = int(max(face_width, face_height) * (1 + FACE_PADDING * 2))

        # Bias the crop upward slightly — we want more space above the head
        # and below to include shoulders
        vertical_offset = int(crop_size * 0.05)
        face_center_y += vertical_offset

        # Ensure crop_size doesn't exceed image dimensions
        crop_size = min(crop_size, img_width, img_height)

        # Calculate crop bounds centered on face
        crop_left = max(0, face_center_x - crop_size // 2)
        crop_top = max(0, face_center_y - crop_size // 2)

        # Adjust if crop goes beyond image edges
        if crop_left + crop_size > img_width:
            crop_left = img_width - crop_size
        if crop_top + crop_size > img_height:
            crop_top = img_height - crop_size

        crop_box = (crop_left, crop_top, crop_left + crop_size, crop_top + crop_size)
        method = "face"
    else:
        # Fallback: center crop (largest square from center)
        crop_size = min(img_width, img_height)
        crop_left = (img_width - crop_size) // 2
        crop_top = (img_height - crop_size) // 2
        crop_box = (crop_left, crop_top, crop_left + crop_size, crop_top + crop_size)
        method = "fallback"

    # Crop, resize, and save
    cropped = img.crop(crop_box)
    cropped = cropped.resize((TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)

    # Convert to RGB if necessary (e.g., RGBA PNGs)
    if cropped.mode != "RGB":
        cropped = cropped.convert("RGB")

    cropped.save(str(output_path), "JPEG", quality=JPEG_QUALITY)
    return method


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Collect input files
    input_files = sorted([
        f for f in INPUT_DIR.iterdir()
        if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS
    ])

    if not input_files:
        print(f"No images found in {INPUT_DIR}")
        print("Copy your raw avatar photos there and re-run.")
        sys.exit(0)

    print(f"Processing {len(input_files)} images from {INPUT_DIR}")
    print(f"Output to {OUTPUT_DIR}")
    print()

    face_count = 0
    fallback_count = 0
    errors = []

    for i, file_path in enumerate(input_files, 1):
        # Output as JPEG with same stem name
        output_name = file_path.stem + ".jpg"
        output_path = OUTPUT_DIR / output_name

        try:
            method = crop_around_face(file_path, output_path)
            if method == "face":
                face_count += 1
                status = "✓ face"
            else:
                fallback_count += 1
                status = "○ center"
            print(f"  [{i:3d}/{len(input_files)}] {status}  {file_path.name} → {output_name}")
        except Exception as e:
            errors.append((file_path.name, str(e)))
            print(f"  [{i:3d}/{len(input_files)}] ✗ ERROR  {file_path.name}: {e}")

    # Report
    print()
    print("=" * 50)
    print(f"  Total:    {len(input_files)}")
    print(f"  Face:     {face_count}")
    print(f"  Fallback: {fallback_count}")
    print(f"  Errors:   {len(errors)}")
    print("=" * 50)

    if errors:
        print()
        print("Files with errors:")
        for name, err in errors:
            print(f"  - {name}: {err}")

    if fallback_count > 0:
        print()
        print("Review fallback crops — no face was detected in these images.")
        print("You may want to manually crop or replace them.")


if __name__ == "__main__":
    main()
