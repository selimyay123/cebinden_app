import os
from PIL import Image

path = '/Users/selimyay/cebinden/assets/car_images/bavora/bavora.png'
if os.path.exists(path):
    try:
        with Image.open(path) as img:
            print(f"Dimensions: {img.size}")
            print(f"Format: {img.format}")
    except Exception as e:
        print(f"Error: {e}")
else:
    print("File not found")
