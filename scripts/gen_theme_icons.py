# 生成 sun.png / moon.png 侧边栏主题切换图标（64x64 透明 PNG，线条风格）
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, os

OUT = r"C:\Project\Cangjie\SelineRead\assets\icon"
COLOR = (203, 213, 225)  # SIDEBAR_TEXT

def make_sun():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = 33, 33
    # 中心圆轮廓
    d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], outline=COLOR, width=3)
    # 8 条射线
    for i in range(8):
        ang = math.radians(i * 45)
        r0, r1 = 18.0, 24.0
        x0 = cx + r0 * math.cos(ang)
        y0 = cy + r0 * math.sin(ang)
        x1 = cx + r1 * math.cos(ang)
        y1 = cy + r1 * math.sin(ang)
        d.line([x0, y0, x1, y1], fill=COLOR, width=3)
    return img

def make_moon():
    # 月牙：大圆填充 - 偏移小圆填充，再提取边缘
    big = Image.new("L", (64, 64), 0)
    db = ImageDraw.Draw(big)
    db.ellipse([12, 20, 48, 56], fill=255)        # 大圆
    small = Image.new("L", (64, 64), 0)
    ds = ImageDraw.Draw(small)
    ds.ellipse([26, 10, 56, 40], fill=255)        # 偏移小圆（左上）
    moon_mask = ImageChops.difference(big, small) # 大圆独有区域 = 月牙
    edges = moon_mask.filter(ImageFilter.FIND_EDGES)
    # 膨胀边缘使线条加粗
    thick = edges.filter(ImageFilter.MaxFilter(3))
    thick = thick.filter(ImageFilter.MaxFilter(3))
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    alpha = thick.point(lambda v: min(255, v * 3))
    img.putalpha(alpha)
    # 上色
    data = []
    for a in alpha.getdata():
        data.append((COLOR[0], COLOR[1], COLOR[2], a if a > 0 else 0))
    img.putdata(data)
    return img

sun = make_sun()
sun.save(os.path.join(OUT, "sun.png"))
moon = make_moon()
moon.save(os.path.join(OUT, "moon.png"))
print("saved:", os.path.join(OUT, "sun.png"), os.path.join(OUT, "moon.png"))