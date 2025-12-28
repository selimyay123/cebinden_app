import struct
import sys

def read_bmp(filename):
    with open(filename, 'rb') as f:
        data = f.read()
    
    if len(data) < 54:
        print(f"Error: File {filename} too small")
        sys.exit(1)

    pixel_offset = struct.unpack('<I', data[10:14])[0]
    width = struct.unpack('<i', data[18:22])[0]
    height = struct.unpack('<i', data[22:26])[0]
    bpp = struct.unpack('<H', data[28:30])[0]
    
    width = abs(width)
    height = abs(height)
    
    pixels = bytearray(data[pixel_offset:])
    return width, height, bpp, pixels, data[:pixel_offset]

def save_bmp(filename, header, pixels):
    with open(filename, 'wb') as f:
        f.write(header)
        f.write(pixels)

def shift_image(width, height, bpp, pixels, shift_x, shift_y):
    # Create new black buffer
    new_pixels = bytearray(len(pixels))
    
    bytes_per_pixel = bpp // 8
    row_size = ((width * bpp + 31) // 32) * 4
    
    for y in range(height):
        for x in range(width):
            # Target coordinates
            new_x = x + shift_x
            new_y = y + shift_y // 1 # Y direction might need inversion check?
            # BMP is usually bottom-up.
            # If we want to move content DOWN visually:
            # In bottom-up encoding, y=0 is bottom. y=height is top.
            # Moving Down means decreasing y? 
            # Let's assume standard top-down logic first, then flip if needed.
            # Actually, let's just map Source to Dest.
            
            # Source coordinates
            src_x = x - shift_x
            src_y = y - shift_y # If we shift content +3 (Down), we want dest(y) to take from src(y-3)
            
            # Check bounds
            if 0 <= src_x < width and 0 <= src_y < height:
                dest_offset = y * row_size + x * bytes_per_pixel
                src_offset = src_y * row_size + src_x * bytes_per_pixel
                
                if src_offset + 2 < len(pixels) and dest_offset + 2 < len(new_pixels):
                    new_pixels[dest_offset] = pixels[src_offset]     # B
                    new_pixels[dest_offset+1] = pixels[src_offset+1] # G
                    new_pixels[dest_offset+2] = pixels[src_offset+2] # R

    return new_pixels

# Read the converted BMP mask
width, height, bpp, pixels, header = read_bmp('temp_mask.bmp')

# Shift values:
# We want to move Mask Content LEFT (-3) and DOWN (+3)
# Wait, previous analysis:
# Image Center Y: 507. Mask Center Y: 504.5.
# Mask is "Lower" in coordinate value (closer to 0).
# If 0 is Bottom (BMP standard), then Mask is closer to Bottom.
# Image is Higher (Top).
# So Mask needs to move UP to match Image?
# Let's re-read: "Mask is Above Image" (if 0 is Top).
# Let's assume standard image coordinates (0=Top).
# Image Y=507. Mask Y=504.5.
# Mask is "Higher" (smaller Y).
# To match 507, Mask needs to increase Y (+2.5).
# So Mask needs to move DOWN.
# BMP is stored Bottom-Up usually.
# In Bottom-Up: Y=0 is Bottom.
# If Mask Y=504 and Image Y=507.
# Mask is "Lower" on screen? No, 507 is "Higher" (more up).
# So Mask needs to move UP (+3).
# Let's try shifting Y=+3 (Up in BMP, Down in visual? No, +Y is Up in BMP).
# If we want to move content UP visually, we add to Y in BMP.

# Let's try X=-3 (Left), Y=+3 (Up in BMP / Up visually).
# Or Y=-3 (Down in BMP / Down visually).

# Let's try generating BOTH directions and I'll pick one? No, I can't see.
# Let's trust the "Mask needs to move Left and Down" intuition from the screenshot.
# Screenshot Step 116: Mask (ghost) seemed to be to the Right and Up?
# If Mask is Right/Up, we need to move it Left/Down.
# Left: X = -3.
# Down: Y = -3 (in BMP, decreasing Y moves towards bottom).

new_pixels = shift_image(width, height, bpp, pixels, -3, -3)

save_bmp('temp_mask_aligned.bmp', header, new_pixels)
print("Saved temp_mask_aligned.bmp")
