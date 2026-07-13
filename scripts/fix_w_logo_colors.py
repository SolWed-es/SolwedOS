import re, base64, sys
from io import BytesIO
import numpy as np
from PIL import Image

SOLWED_YELLOW = (245, 231, 10)   # #F5E70A
WHITE = (255, 255, 255)

REFERENCE_PATH = "/home/aruizb/SolwedOS/imagenes_Solwed/Logo_Solwed.PNG"
MIN_GAP_WIDTH = 15  # columns of zero-foreground separating a wordmark's text from the "W." mark


def build_reference_field():
    """Classify the ground-truth reference image (just the W. mark, no text)
    into a continuous yellowness field, cropped to the glyph's bounding box."""
    ref = np.array(Image.open(REFERENCE_PATH).convert('RGB'))
    r, g, b = ref[:, :, 0].astype(int), ref[:, :, 1].astype(int), ref[:, :, 2].astype(int)
    fg = (r > 40) | (g > 40) | (b > 40)
    ys, xs = np.where(fg)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    fg = fg[y0:y1 + 1, x0:x1 + 1]
    sub = ref[y0:y1 + 1, x0:x1 + 1]
    r, g, b = sub[:, :, 0].astype(int), sub[:, :, 1].astype(int), sub[:, :, 2].astype(int)
    is_yellow = fg & (b < r - 40) & (b < g - 40)
    field = np.where(fg, np.where(is_yellow, 1.0, 0.0), 0.5).astype(np.float32)
    return field


def mark_bbox(fg):
    """Given a 2D foreground bool mask that may contain a text wordmark to the
    left of the 'W.' mark, return (x0, x1) column range of just the mark —
    the segment after the widest zero-foreground column gap. Falls back to
    the full width if no such gap exists."""
    w = fg.shape[1]
    colcount = fg.sum(axis=0)
    zero_cols = np.where(colcount == 0)[0]
    if len(zero_cols) == 0:
        return 0, w - 1
    # find runs of consecutive zero columns
    runs = []
    start = zero_cols[0]
    prev = zero_cols[0]
    for c in zero_cols[1:]:
        if c != prev + 1:
            runs.append((start, prev))
            start = c
        prev = c
    runs.append((start, prev))
    # the mark is always the rightmost cluster in a wordmark layout, so use
    # the LAST sufficiently-wide gap that still has foreground after it, not
    # the overall widest (word spacing inside the text, e.g. between "Solwed"
    # and "OS", can be wider than the text-to-mark gap and would otherwise
    # swallow part of the text too) or trailing empty canvas margin
    qualifying = [r for r in runs if r[1] - r[0] + 1 >= MIN_GAP_WIDTH and r[1] + 1 < w and colcount[r[1] + 1:].sum() > 0]
    if not qualifying:
        return 0, w - 1
    last = qualifying[-1]
    return last[1] + 1, w - 1


def recolor_by_reference(arr, ref_field):
    """arr: RGBA array of the target asset (may include a text wordmark).
    Recolors only the 'W.' mark region by resizing the reference's yellowness
    field onto that region and thresholding, leaving everything else as-is."""
    alpha = arr[:, :, 3]
    fg = alpha > 20
    x0, x1 = mark_bbox(fg)
    mark_fg = np.zeros_like(fg)
    mark_fg[:, x0:x1 + 1] = fg[:, x0:x1 + 1]

    ys, xs = np.where(mark_fg)
    ty0, ty1, tx0, tx1 = ys.min(), ys.max(), xs.min(), xs.max()
    th, tw = ty1 - ty0 + 1, tx1 - tx0 + 1

    field_img = Image.fromarray((ref_field * 255).astype(np.uint8))
    resized = field_img.resize((tw, th), Image.BILINEAR)
    resized_arr = np.array(resized).astype(np.float32) / 255.0

    out = arr.copy()
    changed = 0
    for y, x in zip(ys, xs):
        val = resized_arr[y - ty0, x - tx0]
        color = SOLWED_YELLOW if val >= 0.5 else WHITE
        if tuple(out[y, x, :3]) != color:
            changed += 1
        out[y, x, 0], out[y, x, 1], out[y, x, 2] = color

    return out, changed


def fix_plain_png(path, ref_field):
    im = Image.open(path).convert('RGBA')
    arr = np.array(im)
    out, changed = recolor_by_reference(arr, ref_field)
    Image.fromarray(out.astype(np.uint8)).save(path)
    print(f"{path}: {changed} pixeles corregidos")


def fix_svg_embedded_png(path, ref_field):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    m = re.search(r'(base64,)([A-Za-z0-9+/=\s]+)(")', text)
    if not m:
        raise RuntimeError(f"no embedded PNG found in {path}")
    raw = base64.b64decode(m.group(2).replace('\n', '').replace(' ', ''))
    im = Image.open(BytesIO(raw)).convert('RGBA')
    arr = np.array(im)
    out, changed = recolor_by_reference(arr, ref_field)
    buf = BytesIO()
    Image.fromarray(out.astype(np.uint8)).save(buf, format='PNG')
    new_b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    text = text[:m.start(2)] + new_b64 + text[m.end(2):]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"{path}: {changed} pixeles corregidos (PNG embebido en SVG)")


if __name__ == "__main__":
    ref_field = build_reference_field()
    for path in sys.argv[1:]:
        if path.lower().endswith('.svg'):
            fix_svg_embedded_png(path, ref_field)
        else:
            fix_plain_png(path, ref_field)
