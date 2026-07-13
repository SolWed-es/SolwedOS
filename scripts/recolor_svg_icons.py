import colorsys, re, sys

TARGET_HUE = 56.4 / 360.0   # #F5E70A, mismo amarillo Solwed que recolor_cursors.py
BLUE_HUE_LO = 170.0 / 360.0
BLUE_HUE_HI = 250.0 / 360.0

HEX_RE = re.compile(r'#([0-9a-fA-F]{6})\b')

def rotate_if_blue(hexcode):
    r, g, b = (int(hexcode[i:i+2], 16) for i in (0, 2, 4))
    hh, ss, vv = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    if not (BLUE_HUE_LO < hh < BLUE_HUE_HI):
        return None
    nr, ng, nb = colorsys.hsv_to_rgb(TARGET_HUE, ss, vv)
    return '{:02x}{:02x}{:02x}'.format(round(nr*255), round(ng*255), round(nb*255))

def recolor_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    changes = {}
    for hexcode in set(m.group(1) for m in HEX_RE.finditer(text)):
        new = rotate_if_blue(hexcode)
        if new:
            changes[hexcode] = new
    for old, new in changes.items():
        text = text.replace('#' + old, '#' + new)
    if changes:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
    return changes

if __name__ == "__main__":
    for path in sys.argv[1:]:
        changes = recolor_file(path)
        if changes:
            detail = ', '.join(f'#{o}->#{n}' for o, n in changes.items())
            print(f"RECOLORED {path}: {detail}")
        else:
            print(f"skip (sin azules): {path}")
