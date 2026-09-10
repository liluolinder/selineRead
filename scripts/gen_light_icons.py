# 为所有图标生成浅色主题版本（深色线条，透明背景）
from PIL import Image
import os, glob

ICON_DIR = r"C:\Project\Cangjie\SelineRead\assets\icon"
DARK_COLOR = (60, 70, 90)  # 匹配 sidebarText 浅色模式

for path in glob.glob(os.path.join(ICON_DIR, "*.png")):
    name = os.path.basename(path)
    if "_light" in name:
        continue
    img = Image.open(path).convert("RGBA")
    data = []
    for r, g, b, a in img.getdata():
        if a > 0:
            data.append((DARK_COLOR[0], DARK_COLOR[1], DARK_COLOR[2], a))
        else:
            data.append((0, 0, 0, 0))
    light = Image.new("RGBA", img.size)
    light.putdata(data)
    base, ext = os.path.splitext(name)
    out_path = os.path.join(ICON_DIR, f"{base}_light{ext}")
    light.save(out_path)
    print(f"{name} -> {base}_light{ext}")

print("done")
