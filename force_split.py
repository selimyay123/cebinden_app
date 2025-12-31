from PIL import Image
import sys
import os

def force_split(image_path):
    try:
        img = Image.open(image_path)
    except Exception as e:
        print(f"Error: Could not read {image_path}: {e}")
        return

    width, height = img.size
    mid_point = height // 2
    trim = 15  # Reduced trim to 15 pixels to balance artifact removal and preserving car body

    # Top half
    top_img = img.crop((0, 0, width, mid_point - trim))
    # Bottom half
    bottom_img = img.crop((0, mid_point + trim, width, height))

    base_name = os.path.splitext(image_path)[0]
    
    top_img.save(f"{base_name}_top.png")
    bottom_img.save(f"{base_name}_bottom.png")
    print(f"Split {image_path} into top and bottom halves.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python force_split.py <image_path>")
    else:
        force_split(sys.argv[1])
