from PIL import Image
import os

def crop_center(img, target_ratio):
    width, height = img.size
    current_ratio = width / height
    
    if current_ratio > target_ratio:
        # Too wide, crop width
        new_width = int(height * target_ratio)
        left = (width - new_width) // 2
        img = img.crop((left, 0, left + new_width, height))
    else:
        # Too tall, crop height
        new_height = int(width / target_ratio)
        top = (height - new_height) // 2
        img = img.crop((0, top, width, top + new_height))
        
    return img

def normalize():
    base_dir = 'assets/car_images/Renauva'
    car_path = os.path.join(base_dir, 'Slim.png')
    mask_path = os.path.join(base_dir, 'Slim_mask.png')
    
    if not os.path.exists(car_path) or not os.path.exists(mask_path):
        print("Files not found!")
        return

    car = Image.open(car_path)
    mask = Image.open(mask_path)
    
    # Target Ratio: 120 / 140 = 0.857
    target_ratio = 120 / 140
    
    car_fixed = crop_center(car, target_ratio)
    mask_fixed = crop_center(mask, target_ratio)
    
    # Resize to a standard high resolution (e.g., 600x700) to keep quality but fix ratio
    # Or just keep the cropped size. Let's keep cropped size to avoid interpolation artifacts.
    
    car_fixed.save(os.path.join(base_dir, 'Slim_fixed.png'))
    mask_fixed.save(os.path.join(base_dir, 'Slim_mask_fixed.png'))
    
    print(f"Saved Slim_fixed.png: {car_fixed.size}")
    print(f"Saved Slim_mask_fixed.png: {mask_fixed.size}")

if __name__ == "__main__":
    normalize()
