import os
from PIL import Image

def analyze_image(path):
    try:
        img = Image.open(path)
        print(f"Image: {path}")
        print(f"Format: {img.format}")
        print(f"Size: {img.size}")
        print(f"Mode: {img.mode}")
    except Exception as e:
        print(f"Error: {e}")

analyze_image("assets/car_images/bavora/bavora_e.png")
