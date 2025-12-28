import struct
import sys

def read_bmp(filename):
    with open(filename, 'rb') as f:
        data = f.read()
    
    if len(data) < 54:
        print(f"Error: File {filename} too small")
        sys.exit(1)

    # BMP Header
    pixel_offset = struct.unpack('<I', data[10:14])[0]
    width = struct.unpack('<i', data[18:22])[0] # Signed
    height = struct.unpack('<i', data[22:26])[0] # Signed
    bpp = struct.unpack('<H', data[28:30])[0]
    
    height = abs(height)
    width = abs(width)
    
    print(f"File: {filename}, Width: {width}, Height: {height}, BPP: {bpp}, Offset: {pixel_offset}, Size: {len(data)}")
    
    pixels = data[pixel_offset:]
    return width, height, pixels, bpp

def get_bbox(width, height, pixels, bpp, is_mask=False):
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    
    bytes_per_pixel = bpp // 8
    row_size = ((width * bpp + 31) // 32) * 4
    
    # Sample background color from top-left (0,0)
    # In BMP bottom-up, (0,0) is at the end of the buffer? No, usually (0,0) is bottom-left.
    # But let's assume the background is uniform.
    # Let's sample the first pixel in the buffer (which is either bottom-left or top-left).
    bg_b = pixels[0]
    bg_g = pixels[1]
    bg_r = pixels[2]
    print(f"Background Color: R={bg_r}, G={bg_g}, B={bg_b}")

    for y in range(height):
        for x in range(width):
            offset = y * row_size + x * bytes_per_pixel
            
            if offset + 2 >= len(pixels):
                continue

            b = pixels[offset]
            g = pixels[offset+1]
            r = pixels[offset+2]
            
            if is_mask:
                # Mask: Find WHITE pixels
                if r > 200 and g > 200 and b > 200:
                    min_x = min(min_x, x)
                    max_x = max(max_x, x)
                    min_y = min(min_y, y)
                    max_y = max(max_y, y)
            else:
                # Image: Find pixels NOT matching background
                diff = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
                if diff > 20: # Tolerance
                    min_x = min(min_x, x)
                    max_x = max(max_x, x)
                    min_y = min(min_y, y)
                    max_y = max(max_y, y)
                    
    return min_x, max_x, min_y, max_y

w1, h1, p1, bpp1 = read_bmp('temp_slim.bmp')
w2, h2, p2, bpp2 = read_bmp('temp_mask.bmp')

# Image BBox
img_min_x, img_max_x, img_min_y, img_max_y = get_bbox(w1, h1, p1, bpp1, is_mask=False)
img_w = img_max_x - img_min_x
img_h = img_max_y - img_min_y
img_cx = (img_min_x + img_max_x) / 2
img_cy = (img_min_y + img_max_y) / 2

# Mask BBox
mask_min_x, mask_max_x, mask_min_y, mask_max_y = get_bbox(w2, h2, p2, bpp2, is_mask=True)
mask_w = mask_max_x - mask_min_x
mask_h = mask_max_y - mask_min_y
mask_cx = (mask_min_x + mask_max_x) / 2
mask_cy = (mask_min_y + mask_max_y) / 2

print(f"Image BBox: {img_min_x},{img_min_y} - {img_max_x},{img_max_y} (WxH: {img_w}x{img_h}) Center: {img_cx},{img_cy}")
print(f"Mask BBox: {mask_min_x},{mask_min_y} - {mask_max_x},{mask_max_y} (WxH: {mask_w}x{mask_h}) Center: {mask_cx},{mask_cy}")

# Calculate Offset (How much to move Mask to match Image)
# If Image Center is at 500 and Mask Center is at 510, we need to move Mask by -10 (Left)
dx = img_cx - mask_cx
# dy might be inverted because of BMP bottom-up, but let's see magnitude
dy = img_cy - mask_cy

# Calculate Scale (How much to scale Mask to match Image)
scale_x = img_w / mask_w if mask_w > 0 else 1
scale_y = img_h / mask_h if mask_h > 0 else 1

print(f"OFFSET_X: {dx}")
print(f"OFFSET_Y: {dy}")
print(f"SCALE_X: {scale_x}")
print(f"SCALE_Y: {scale_y}")

