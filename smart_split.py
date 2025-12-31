import os
from PIL import Image

def get_row_density(img, y, width):
    count = 0
    for x in range(width):
        r, g, b, a = img.getpixel((x, y))
        if a > 10 and (r < 250 or g < 250 or b < 250):
            count += 1
    return count

def get_col_density(img, x, height):
    count = 0
    for y in range(height):
        r, g, b, a = img.getpixel((x, y))
        if a > 10 and (r < 250 or g < 250 or b < 250):
            count += 1
    return count

def find_low_density_gaps(densities, threshold_ratio=0.02, min_gap_size=5):
    # threshold_ratio: max density to consider as "gap" (relative to max density observed or width)
    # But simpler: relative to the dimension size.
    
    max_val = max(densities) if densities else 0
    threshold = max(5, max_val * 0.1) # 10% of max density is considered "empty enough"
    
    segments = []
    in_gap = False
    gap_start = 0
    
    # We want to find SEGMENTS OF CONTENT, separated by GAPS.
    # So we iterate.
    
    content_segments = []
    in_content = False
    start = 0
    
    for i, d in enumerate(densities):
        is_content = d > threshold
        
        if is_content and not in_content:
            in_content = True
            start = i
        elif not is_content and in_content:
            in_content = False
            content_segments.append((start, i))
            
    if in_content:
        content_segments.append((start, len(densities)))
        
    return content_segments

def recursive_split(img, x_offset, y_offset, depth=0):
    width, height = img.size
    
    # Don't split too small
    if width < 50 or height < 50:
        return [(x_offset, y_offset, x_offset+width, y_offset+height)]

    # 1. Try Horizontal Split (Rows)
    row_densities = [get_row_density(img, y, width) for y in range(height)]
    rows = find_low_density_gaps(row_densities)
    
    # If we found multiple rows, recurse on each row
    if len(rows) > 1:
        results = []
        for y1, y2 in rows:
            sub_img = img.crop((0, y1, width, y2))
            results.extend(recursive_split(sub_img, x_offset, y_offset + y1, depth + 1))
        return results

    # 2. If no horizontal split, Try Vertical Split (Cols)
    col_densities = [get_col_density(img, x, height) for x in range(width)]
    cols = find_low_density_gaps(col_densities)
    
    # If we found multiple cols, recurse on each col
    if len(cols) > 1:
        results = []
        for x1, x2 in cols:
            sub_img = img.crop((x1, 0, x2, height))
            results.extend(recursive_split(sub_img, x_offset + x1, y_offset, depth + 1))
        return results

    # 3. If no split found, this is a leaf
    return [(x_offset, y_offset, x_offset+width, y_offset+height)]

def split_smart(image_path, output_dir):
    print(f"Processing {image_path}...")
    img = Image.open(image_path)
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    final_crops = recursive_split(img, 0, 0)
    
    print(f"Total detected regions: {len(final_crops)}")
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    image_count = 0
    for i, (x1, y1, x2, y2) in enumerate(final_crops):
        width = x2 - x1
        height = y2 - y1
        
        # Filter out tiny noise
        if width < 50 or height < 50:
            continue
            
        crop = img.crop((x1, y1, x2, y2))
        image_count += 1
        output_filename = f"signa_{image_count}.png"
        output_path = os.path.join(output_dir, output_filename)
        crop.save(output_path)
        print(f"Saved {output_path} ({width}x{height})")
            
    print(f"Final total images: {image_count}")

if __name__ == "__main__":
    input_path = "/Users/selimyay/cebinden/assets/car_images/koyoro/lotus/lotos.png"
    output_dir = "/Users/selimyay/cebinden/assets/car_images/koyoro/lotus/"
    split_smart(input_path, output_dir)
