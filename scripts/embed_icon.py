# 给已编译好的 Windows exe 嵌入图标（资源管理器/任务栏可见）。
#
# 为什么不在链接期加：仓颉工程用 cjpm 出包，link-option 里塞 COFF 资源对象
# 依赖本机路径、不好跨机器复现；而 Win32 自带的 UpdateResource 可以直接改 PE
# 文件，不需要 rc.exe/windres，脚本更稳。
#
# 用法：
#   python scripts/embed_icon.py <exe> <png>
#
# 依赖：Pillow（把 PNG 转成多尺寸 ICO）

import ctypes
import struct
import sys
import tempfile
import os
from ctypes import wintypes

from PIL import Image

RT_ICON = 3
RT_GROUP_ICON = 14
ICON_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def make_ico(png_path):
    """PNG -> 多尺寸 ICO，返回 (entries, ico_bytes)；entries 每项含 (w,h,...,data)。"""
    img = Image.open(png_path).convert("RGBA")
    fd, ico_path = tempfile.mkstemp(suffix=".ico")
    os.close(fd)
    try:
        img.save(ico_path, format="ICO", sizes=ICON_SIZES)
        data = open(ico_path, "rb").read()
    finally:
        os.remove(ico_path)

    reserved, typ, count = struct.unpack_from("<HHH", data, 0)
    if typ != 1:
        raise ValueError("not an ico")
    entries = []
    for i in range(count):
        w, h, cc, res, planes, bpp, size, off = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        entries.append((w, h, cc, res, planes, bpp, size, off, data[off:off + size]))
    if not entries:
        raise ValueError("empty ico")
    return entries


def embed(exe_path, png_path):
    entries = make_ico(png_path)
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.BeginUpdateResourceW.restype = wintypes.HANDLE
    k32.BeginUpdateResourceW.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
    k32.UpdateResourceW.restype = wintypes.BOOL
    k32.UpdateResourceW.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p,
                                    wintypes.WORD, ctypes.c_void_p, wintypes.DWORD]
    k32.EndUpdateResourceW.restype = wintypes.BOOL
    k32.EndUpdateResourceW.argtypes = [wintypes.HANDLE, wintypes.BOOL]

    h = k32.BeginUpdateResourceW(exe_path, False)
    if not h:
        raise OSError("BeginUpdateResource failed: %d" % ctypes.get_last_error())

    ok = True
    for idx, e in enumerate(entries, start=1):
        blob = e[8]
        buf = ctypes.create_string_buffer(blob, len(blob))
        if not k32.UpdateResourceW(h, ctypes.c_void_p(RT_ICON), ctypes.c_void_p(idx), 0,
                                   buf, len(blob)):
            ok = False
            err = ctypes.get_last_error()
            break

    if ok:
        grp = struct.pack("<HHH", 0, 1, len(entries))
        for idx, e in enumerate(entries, start=1):
            w, h2, cc, res, planes, bpp, size, off, blob = e
            grp += struct.pack("<BBBBHHIH", w, h2, cc, res, planes, bpp, size, idx)
        gbuf = ctypes.create_string_buffer(grp, len(grp))
        if not k32.UpdateResourceW(h, ctypes.c_void_p(RT_GROUP_ICON), ctypes.c_void_p(1), 0,
                                   gbuf, len(grp)):
            ok = False
            err = ctypes.get_last_error()

    if not k32.EndUpdateResourceW(h, not ok):
        raise OSError("EndUpdateResource failed: %d" % ctypes.get_last_error())
    if not ok:
        raise OSError("UpdateResource failed: %d" % err)

    print("icon embedded (%d sizes): %s" % (len(entries), exe_path))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: python embed_icon.py <exe> <png>", file=sys.stderr)
        sys.exit(2)
    embed(sys.argv[1], sys.argv[2])
