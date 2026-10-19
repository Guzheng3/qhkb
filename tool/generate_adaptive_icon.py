"""Generate Android adaptive icon layers from the REAL shipped app icon.

Source of truth: assets/branding/launcher_icon.png (pixel-identical to the
mipmap ic_launcher.png set). Produces background (edge-color continuation)
and foreground (artwork centered with safe-zone margin) layers for all
densities, plus preview composites for human review before committing.

Layer strategy (icon refresh):
- Background layer: solid fill of the source artwork's corner/edge color
  (white for the current master). Nothing of the illustration goes into the
  background layer, otherwise the artwork would show up twice (background +
  foreground) and the visible content would shrink to background scale ×
  foreground scale.
- Foreground layer: artwork auto-cropped to its non-white bounding box
  (brightness threshold CROP_THRESHOLD) and scaled so the content's longest
  side spans CONTENT_SCALE of the 108dp adaptive canvas (≈69dp, i.e. inside
  the 72dp safe zone). Cropping first is what keeps the visible content at
  the intended size regardless of how much empty margin the master has.
- Legacy full-bleed mipmap-*/ic_launcher.png is regenerated as the composite
  of both layers, so no pre-refresh artwork stays in the tree.

Startup branding is NOT generated here anymore: the Android 12+ system
splash is stripped to a bare background color (values-v31 styles) and the
startup branding is drawn by the app's own Flutter splash
(lib/widgets/app_startup_splash.dart) using the source image directly.
System-side splash icon/branding resources were removed after three device
failures traced to the OS icon mask/scale pipeline (double-plate ghost,
cropped-artwork blur).

Usage:
    python tool/generate_adaptive_icon.py
    python tool/generate_adaptive_icon.py --import-source <master.png>
    python tool/generate_adaptive_icon.py --compare-out <path.png>
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "branding" / "launcher_icon.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
PREVIEW = ROOT / ".tmp_adaptive_preview"
BASE = 1024
# 108dp adaptive canvas; only the central 72dp safe zone is visible.
# 0.64 × 108dp ≈ 69dp keeps the artwork fully inside that safe zone with a
# little breathing room, matching how the legacy full-bleed bitmap filled the
# launcher mask.
CONTENT_SCALE = 0.64
# A pixel counts as "empty margin" when every channel is at least this bright.
CROP_THRESHOLD = 245
# Anything this close to white is snapped to pure white for the background fill.
WHITE_SNAP = 250
DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
LEGACY_DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def edge_color(src: Image.Image) -> tuple:
    """Corner / edge color of the artwork, used to fill the background layer."""
    rgb = np.asarray(src.convert("RGB"), dtype=np.uint8)
    h, w = rgb.shape[:2]
    samples = np.array(
        [
            rgb[0, 0],
            rgb[0, w - 1],
            rgb[h - 1, 0],
            rgb[h - 1, w - 1],
            rgb[0, w // 2],
            rgb[h - 1, w // 2],
            rgb[h // 2, 0],
            rgb[h // 2, w - 1],
        ]
    )
    color = tuple(int(v) for v in np.median(samples, axis=0).round())
    if all(channel >= WHITE_SNAP for channel in color):
        return (255, 255, 255)
    return color


def content_bbox(src: Image.Image, threshold: int = CROP_THRESHOLD) -> tuple:
    """Bounding box of everything darker than the white margin."""
    arr = np.asarray(src.convert("RGB"), dtype=np.uint8)
    mask = (arr < threshold).any(axis=2)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return (0, 0, src.width, src.height)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def build_background(color: tuple, size: int = BASE) -> Image.Image:
    """Solid edge-color fill — the illustration belongs to the foreground only."""
    return Image.new("RGBA", (size, size), color + (255,))


def build_foreground(src: Image.Image) -> Image.Image:
    """Crop the empty margin, then scale the content into the safe zone."""
    box = content_bbox(src)
    crop = src.convert("RGBA").crop(box)
    scale = CONTENT_SCALE * BASE / max(crop.width, crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    content = crop.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    canvas.alpha_composite(content, ((BASE - size[0]) // 2, (BASE - size[1]) // 2))
    return canvas


def scale_centered(img: Image.Image, scale: float) -> Image.Image:
    size = int(BASE * scale)
    small = img.resize((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    off = (BASE - size) // 2
    canvas.alpha_composite(small, (off, off))
    return canvas


def legacy_background(src: Image.Image) -> Image.Image:
    """Pre-refresh background layer: edge gradient overlaid with the artwork.

    Kept only to render the before/after comparison — for an opaque master this
    paints the whole illustration into the background layer, which is the defect
    the current implementation fixes.
    """
    arr = np.asarray(src.convert("RGB"), dtype=np.float64)
    mid = BASE // 2
    top_mid = arr[0, mid]
    bottom_mid = arr[-1, mid]
    left_mid = arr[mid, 0]
    right_mid = arr[mid, -1]
    s = np.linspace(0.0, 1.0, BASE)[:, None, None]
    t = np.linspace(0.0, 1.0, BASE)[None, :, None]
    vert = top_mid[None, None, :] * (1.0 - s) + bottom_mid[None, None, :] * s
    horz = left_mid[None, None, :] * (1.0 - t) + right_mid[None, None, :] * t
    out = 0.5 * vert + 0.5 * horz
    alpha = np.asarray(src.convert("RGBA"), dtype=np.float64)[:, :, 3:4] / 255.0
    rgb = np.asarray(src.convert("RGB"), dtype=np.float64)
    final = out * (1.0 - alpha) + rgb * alpha
    return Image.fromarray(np.clip(final, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255
    )
    return mask


def circle_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask


def masked_tile(img: Image.Image, mask: Image.Image, size: int) -> Image.Image:
    tile = Image.new("RGBA", (size, size), (238, 238, 238, 255))
    tile.paste(img.resize((size, size), Image.Resampling.LANCZOS), (0, 0), mask)
    return tile


def write_before_after(composite: Image.Image, src: Image.Image, out: Path) -> None:
    """Squircle comparison: pre-refresh logic vs. cropped safe-zone fill."""
    before = Image.alpha_composite(
        legacy_background(src.resize((BASE, BASE), Image.Resampling.LANCZOS)),
        scale_centered(src.resize((BASE, BASE), Image.Resampling.LANCZOS), 0.67),
    )
    size = 320
    squircle = rounded_mask(BASE, 0.24).resize((size, size), Image.Resampling.LANCZOS)
    gap, pad, label = 30, 20, 26
    sheet = Image.new(
        "RGBA", (size * 2 + gap + pad * 2, size + pad * 2 + label), (255, 255, 255, 255)
    )
    sheet.paste(masked_tile(before, squircle, size), (pad, pad + label))
    sheet.paste(masked_tile(composite, squircle, size), (pad + size + gap, pad + label))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad + 4, pad + 4), "before: artwork in both layers (0.67)", fill=(90, 90, 90))
    draw.text(
        (pad + size + gap + 4, pad + 4),
        "after: white bg + cropped content (0.64)",
        fill=(90, 90, 90),
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)
    print("comparison written to " + str(out))


Q = chr(39)
D = chr(34)
ADAPTIVE_XML = (
    "<?xml version=" + Q + "1.0" + Q + " encoding=" + Q + "utf-8" + Q + "?>" + chr(10) +
    "<adaptive-icon xmlns:android=" + D + "http://schemas.android.com/apk/res/android" + D + ">" + chr(10) +
    "    <background android:drawable=" + D + "@mipmap/ic_launcher_background" + D + "/>" + chr(10) +
    "    <foreground android:drawable=" + D + "@mipmap/ic_launcher_foreground" + D + "/>" + chr(10) +
    "</adaptive-icon>" + chr(10)
)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate adaptive icon layers.")
    parser.add_argument(
        "--import-source",
        metavar="PATH",
        help="resample a master PNG to BASE px (LANCZOS) into assets/branding/launcher_icon.png first",
    )
    parser.add_argument(
        "--compare-out",
        metavar="PATH",
        help="also write the pre-refresh vs. cropped squircle comparison to PATH",
    )
    args = parser.parse_args()

    if args.import_source:
        master = Image.open(args.import_source).convert("RGBA")
        SRC.parent.mkdir(parents=True, exist_ok=True)
        master.resize((BASE, BASE), Image.Resampling.LANCZOS).save(SRC)
        print("imported " + args.import_source + " -> " + str(SRC) + " at " + str(BASE) + "px")

    src = Image.open(SRC).convert("RGBA").resize((BASE, BASE), Image.Resampling.LANCZOS)
    box = content_bbox(src)
    color = edge_color(src)
    background = build_background(color)
    foreground = build_foreground(src)
    composite = Image.alpha_composite(background, foreground)

    content_w = round(CONTENT_SCALE * BASE * (box[2] - box[0]) / max(box[2] - box[0], box[3] - box[1]))
    print(
        "source " + str(src.width) + "x" + str(src.height)
        + " | white margin crop box " + str(box)
        + " | background color " + str(color)
    )
    print(
        "content " + str(content_w) + "px wide on a " + str(BASE) + "px canvas = "
        + str(round(CONTENT_SCALE, 2)) + " of canvas (108dp canvas -> "
        + str(round(CONTENT_SCALE * 108, 1)) + "dp content, 72dp safe zone)"
    )

    for density, factor in DENSITIES.items():
        layer = int(round(108 * factor))
        d = RES / ("mipmap-" + density)
        d.mkdir(parents=True, exist_ok=True)
        background.resize((layer, layer), Image.Resampling.LANCZOS).save(d / "ic_launcher_background.png")
        foreground.resize((layer, layer), Image.Resampling.LANCZOS).save(d / "ic_launcher_foreground.png")

    # Legacy full-bleed bitmaps: overwritten with the new composite so the
    # pre-refresh artwork cannot survive in any density.
    for density, side in LEGACY_DENSITIES.items():
        d = RES / ("mipmap-" + density)
        d.mkdir(parents=True, exist_ok=True)
        composite.resize((side, side), Image.Resampling.LANCZOS).save(d / "ic_launcher.png")

    xml_dir = RES / "mipmap-anydpi-v26"
    xml_dir.mkdir(parents=True, exist_ok=True)
    (xml_dir / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")

    # Previews for human review BEFORE trusting the result on device.
    PREVIEW.mkdir(parents=True, exist_ok=True)
    size = 256
    comp_r = composite.resize((size, size), Image.Resampling.LANCZOS)
    real_r = src.resize((size, size), Image.Resampling.LANCZOS)
    squircle = rounded_mask(BASE, 0.24).resize((size, size))
    circle = circle_mask(BASE).resize((size, size))

    def save_masked(img, mask, name):
        out = Image.new("RGBA", (size, size), (238, 238, 238, 255))
        out.paste(img, (0, 0), mask)
        out.save(PREVIEW / name)

    save_masked(comp_r, squircle, "preview_hyperos_squircle.png")
    save_masked(comp_r, circle, "preview_circle.png")

    side = Image.new("RGBA", (size * 2 + 30, size + 20), (255, 255, 255, 255))
    old_tile = Image.new("RGBA", (size, size), (238, 238, 238, 255))
    old_tile.paste(real_r, (0, 0), squircle)
    new_tile = Image.new("RGBA", (size, size), (238, 238, 238, 255))
    new_tile.paste(comp_r, (0, 0), squircle)
    side.paste(old_tile, (10, 10))
    side.paste(new_tile, (size + 20, 10))
    side.save(PREVIEW / "preview_old_vs_new.png")

    if args.compare_out:
        write_before_after(composite, src, Path(args.compare_out))

    print("layers written; previews in .tmp_adaptive_preview/")


if __name__ == "__main__":
    main()