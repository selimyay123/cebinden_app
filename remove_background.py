from PIL import Image
import os
import sys

def remove_white_background(directory):
    for filename in os.listdir(directory):
        if filename.lower().endswith(".png"):
            file_path = os.path.join(directory, filename)
            print(f"Processing {file_path}...")
            
            try:
                img = Image.open(file_path)
                img = img.convert("RGBA")
                datas = img.getdata()

                newData = []
                for item in datas:
                    # Change all white (also shades of whites)
                    # to transparent
                    if item[0] > 240 and item[1] > 240 and item[2] > 240:
                        newData.append((255, 255, 255, 0))
                    else:
                        newData.append(item)

                img.putdata(newData)
                img.save(file_path, "PNG")
                print(f"Saved {file_path}")
            except Exception as e:
                print(f"Error processing {filename}: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_dir = sys.argv[1]
        remove_white_background(target_dir)
    else:
        print("Usage: python3 remove_background.py <directory_path>")
