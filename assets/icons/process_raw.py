import os
import shutil
from PIL import Image

def recolorImage(img_path, r, g, b):
    # palette and grayscale pngs index as a single value rather than a tuple
    img = Image.open(img_path).convert("RGBA")
    pixels = img.load()

    for y in range(img.height):
        for x in range(img.width):
            (_, _, _, a) = pixels[x, y]
            pixels[x, y] = (r, g, b, a)
    
    return img

def recolorFolder(folder_path, new_folder_path, r, g, b):
    if os.path.isdir(new_folder_path):
        shutil.rmtree(new_folder_path)

    os.makedirs(new_folder_path)

    for file_name in os.listdir(folder_path):
        if file_name.endswith(".png"):
            recolored = recolorImage(os.path.join(folder_path, file_name), r, g, b)
            recolored.save(os.path.join(new_folder_path, file_name))

file_parent_path = os.path.dirname(os.path.abspath(__file__))
output_folder_path = os.path.join(file_parent_path, "asphalt", "processed")
raw_path = os.path.join(file_parent_path, "raw")

if os.path.isdir(output_folder_path):
    shutil.rmtree(output_folder_path)

os.makedirs(output_folder_path)

recolorFolder(raw_path, os.path.join(output_folder_path, "dark"), 225, 225, 225)
recolorFolder(raw_path, os.path.join(output_folder_path, "light"), 94, 94, 94)
recolorFolder(raw_path, os.path.join(output_folder_path, "dark_selected"), 82, 139, 255)
recolorFolder(raw_path, os.path.join(output_folder_path, "light_selected"), 112, 160, 255)