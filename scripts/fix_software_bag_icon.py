import colorsys, re, base64, sys
from io import BytesIO
from PIL import Image

TARGET_HUE = 56.4 / 360.0   # #F5E70A
BLUE_HUE_LO = 170.0 / 360.0
BLUE_HUE_HI = 250.0 / 360.0

# Revertir el rotado anterior de las 3 partes vectoriales (asa + realce),
# que recolor_svg_icons.py puso en amarillo. Mapeo exacto calculado a partir
# de los azules originales (#1754d3, #5284ff, #6694ff) con el mismo TARGET_HUE.
REVERT_VECTOR = {
    'd3c817': '1754d3',
    'fff552': '5284ff',
    'fff666': '6694ff',
}

def recolor_pixel(r, g, b, a):
    if a < 10:
        return r, g, b, a
    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    if not (BLUE_HUE_LO < h < BLUE_HUE_HI):
        return r, g, b, a
    nr, ng, nb = colorsys.hsv_to_rgb(TARGET_HUE, s, v)
    return round(nr*255), round(ng*255), round(nb*255), a

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    for old, new in REVERT_VECTOR.items():
        text = text.replace('#' + old, '#' + new)

    m = re.search(r'(xlink:href="data:image/png;base64,)([A-Za-z0-9+/=\s]+)(")', text)
    if not m:
        raise RuntimeError(f"no embedded PNG found in {path}")
    raw = base64.b64decode(m.group(2).replace('\n', '').replace(' ', ''))
    im = Image.open(BytesIO(raw)).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            px[x, y] = recolor_pixel(*px[x, y])
    buf = BytesIO()
    im.save(buf, format='PNG')
    new_b64 = base64.b64encode(buf.getvalue()).decode('ascii')

    text = text[:m.start(2)] + new_b64 + text[m.end(2):]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"fixed {path}: {len(REVERT_VECTOR)} colores vectoriales revertidos, cuerpo raster recoloreado")

if __name__ == "__main__":
    for path in sys.argv[1:]:
        fix_file(path)
