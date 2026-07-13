import re, base64, sys
from io import BytesIO
import numpy as np
from scipy import ndimage
from PIL import Image

SOLWED_YELLOW = (245, 231, 10)   # #F5E70A
WHITE = (255, 255, 255)

def classify(arr):
    alpha = arr[:, :, 3]
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    fg = alpha > 20
    yellow = fg & (b < r - 40) & (b < g - 40)
    white = fg & ~yellow
    return fg, yellow, white

def fix_pixels(arr):
    fg, yellow, white = classify(arr)
    yl, ny = ndimage.label(yellow, structure=np.ones((3, 3)))
    wl, nw = ndimage.label(white, structure=np.ones((3, 3)))

    yellow_sizes = [(i, (yl == i).sum()) for i in range(1, ny + 1)]
    yellow_sizes = [t for t in yellow_sizes if t[1] >= 10]
    if not yellow_sizes:
        return arr, 0
    yellow_sizes.sort(key=lambda t: -t[1])
    anchor_id, anchor_size = yellow_sizes[0]
    anchor_mask = yl == anchor_id

    # dilate anchor by 2px to find touching white blobs
    dilated = ndimage.binary_dilation(anchor_mask, iterations=2)

    out = arr.copy()
    changed = 0

    # small yellow blobs far from the anchor -> white
    for i, size in yellow_sizes[1:]:
        if size < anchor_size * 0.5:
            mask = yl == i
            out[mask, 0], out[mask, 1], out[mask, 2] = WHITE
            changed += 1

    # white blobs touching the anchor -> yellow (skip tiny noise / the dot)
    for i in range(1, nw + 1):
        mask = wl == i
        size = mask.sum()
        if size < 10:
            continue
        if (mask & dilated).any():
            out[mask, 0], out[mask, 1], out[mask, 2] = SOLWED_YELLOW
            changed += 1

    return out, changed

def fix_plain_png(path):
    im = Image.open(path).convert('RGBA')
    arr = np.array(im)
    out, changed = fix_pixels(arr)
    Image.fromarray(out.astype(np.uint8)).save(path)
    print(f"{path}: {changed} regiones corregidas")

def fix_svg_embedded_png(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    m = re.search(r'(base64,)([A-Za-z0-9+/=\s]+)(")', text)
    if not m:
        raise RuntimeError(f"no embedded PNG found in {path}")
    raw = base64.b64decode(m.group(2).replace('\n', '').replace(' ', ''))
    im = Image.open(BytesIO(raw)).convert('RGBA')
    arr = np.array(im)
    out, changed = fix_pixels(arr)
    buf = BytesIO()
    Image.fromarray(out.astype(np.uint8)).save(buf, format='PNG')
    new_b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    text = text[:m.start(2)] + new_b64 + text[m.end(2):]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"{path}: {changed} regiones corregidas (PNG embebido en SVG)")

if __name__ == "__main__":
    for path in sys.argv[1:]:
        if path.lower().endswith('.svg'):
            fix_svg_embedded_png(path)
        else:
            fix_plain_png(path)
