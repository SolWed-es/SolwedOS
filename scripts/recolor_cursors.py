import struct, colorsys, os, sys

TARGET_HUE = 56.4 / 360.0   # #F5E70A
BLUE_HUE_LO = 170.0 / 360.0
BLUE_HUE_HI = 250.0 / 360.0
MIN_CHANNEL_RANGE = 25   # absolute max-min RGB difference; filters HSV-saturation false positives on near-black pixels
MIN_TOTAL_PIXELS = 80    # skip files where only a handful of stray pixels match (likely AA noise, not a real badge)

def parse_toc(data):
    header_size, version, ntoc = struct.unpack_from('<III', data, 4)
    toc = []
    off = 16
    for i in range(ntoc):
        typ, subtype, position = struct.unpack_from('<III', data, off)
        toc.append((typ, subtype, position))
        off += 12
    return toc

def is_target_pixel(r, g, b, a):
    if a < 40:
        return False
    if max(r, g, b) - min(r, g, b) < MIN_CHANNEL_RANGE:
        return False
    hh, ss, vv = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    return BLUE_HUE_LO < hh < BLUE_HUE_HI

def count_target_pixels(path):
    with open(path, 'rb') as f:
        data = f.read()
    toc = parse_toc(data)
    total = 0
    for typ, subtype, position in toc:
        if typ != 0xfffd0002:
            continue
        hsize, ctype, csubtype, cversion, width, height, xhot, yhot, delay = struct.unpack_from('<IIIIIIIII', data, position)
        pixel_off = position + 36
        npix = width * height
        pixels = struct.unpack_from(f'<{npix}I', data, pixel_off)
        for p in pixels:
            a = (p >> 24) & 0xff; r = (p >> 16) & 0xff; g = (p >> 8) & 0xff; b = p & 0xff
            if is_target_pixel(r, g, b, a):
                total += 1
    return total

def recolor_file(path, out_path):
    with open(path, 'rb') as f:
        data = bytearray(f.read())
    toc = parse_toc(bytes(data))
    changed = 0
    for typ, subtype, position in toc:
        if typ != 0xfffd0002:
            continue
        hsize, ctype, csubtype, cversion, width, height, xhot, yhot, delay = struct.unpack_from('<IIIIIIIII', data, position)
        pixel_off = position + 36
        npix = width * height
        pixels = list(struct.unpack_from(f'<{npix}I', data, pixel_off))
        new_pixels = []
        for p in pixels:
            a = (p >> 24) & 0xff; r = (p >> 16) & 0xff; g = (p >> 8) & 0xff; b = p & 0xff
            if is_target_pixel(r, g, b, a):
                hh, ss, vv = colorsys.rgb_to_hsv(r/255, g/255, b/255)
                nr, ng, nb = colorsys.hsv_to_rgb(TARGET_HUE, ss, vv)
                r, g, b = round(nr*255), round(ng*255), round(nb*255)
                changed += 1
            new_pixels.append((a << 24) | (r << 16) | (g << 8) | b)
        packed = struct.pack(f'<{npix}I', *new_pixels)
        data[pixel_off:pixel_off+len(packed)] = packed
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'wb') as f:
        f.write(data)
    return changed

if __name__ == "__main__":
    src_dir = sys.argv[1]
    out_dir = sys.argv[2]
    total_files = 0
    total_changed_files = 0
    for name in sorted(os.listdir(src_dir)):
        path = os.path.join(src_dir, name)
        if not os.path.isfile(path):
            continue
        total_files += 1
        try:
            n = count_target_pixels(path)
            if n >= MIN_TOTAL_PIXELS:
                out_path = os.path.join(out_dir, name)
                changed = recolor_file(path, out_path)
                total_changed_files += 1
                print(f"RECOLORED {name}: {changed} pixeles")
            elif n > 0:
                print(f"skip (ruido, {n}px): {name}")
        except Exception as e:
            print(f"SKIP {name}: {e}")
    print(f"--- {total_changed_files}/{total_files} ficheros recoloreados ---")
