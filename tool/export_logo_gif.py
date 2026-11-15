"""Encode Flutter-rendered logo PNGs as a smooth, looping branded GIF.

Run `flutter test tool/export_logo_gif_frames_test.dart` first, then this script.
Requires Pillow. The app's artwork and handwriting renderer are used unchanged.
"""

import json
from pathlib import Path

from PIL import Image, ImageChops


def main():
    root = Path(__file__).resolve().parents[1]
    paths = sorted((root / "build/logo_gif/frames").glob("frame-*.png"))
    if not paths:
        raise SystemExit("Render the Flutter logo frames before encoding.")

    # All frames share a palette so gradients do not flicker between frames.
    columns = 11
    tile = 128
    rows = (len(paths) + columns - 1) // columns
    samples = Image.new("RGB", (columns * tile, rows * tile), "#f7f9fe")
    for index, path in enumerate(paths):
        with Image.open(path) as source:
            thumbnail = source.convert("RGB").resize(
                (tile, tile), Image.Resampling.LANCZOS
            )
            samples.paste(thumbnail, ((index % columns) * tile, (index // columns) * tile))
    palette = samples.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    # Reserve the exact splash background, avoiding dither patterns across the
    # large, otherwise uniform canvas when median-cut averages pale colors.
    palette.putpalette(palette.getpalette()[:765] + [247, 249, 254])
    frames = []
    for path in paths:
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            indexed = rgb.quantize(
                palette=palette, dither=Image.Dither.FLOYDSTEINBERG
            )
            # Pillow's fast palette lookup can approximate even an exact
            # background color. Preserve these original canvas pixels exactly.
            difference = ImageChops.difference(
                rgb, Image.new("RGB", rgb.size, "#f7f9fe")
            )
            red, green, blue = difference.split()
            background_mask = ImageChops.lighter(
                red, ImageChops.lighter(green, blue)
            ).point(lambda value: 255 if value == 0 else 0)
            indexed.paste(255, mask=background_mask)
            frames.append(indexed)

    destination = root / "exports/Apna-POS-Logo-Writing.gif"
    destination.parent.mkdir(parents=True, exist_ok=True)
    durations = [40] * len(frames)
    durations[-1] = 1200
    frames[0].save(
        destination,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=1,
        optimize=False,
    )

    # Read the encoded file back, including every frame, before reporting it.
    with Image.open(destination) as gif:
        total_ms = 0
        for index in range(gif.n_frames):
            gif.seek(index)
            gif.load()
            total_ms += gif.info.get("duration", 0)
        assert gif.size == (600, 600)
        assert gif.info.get("loop") == 0
        assert total_ms == sum(durations)
        assert gif.convert("RGB").crop((0, 0, 70, 600)).getcolors() == [
            (70 * 600, (247, 249, 254))
        ]
        gif.convert("RGB").save(root / "build/logo_gif/final-gif-frame.png")
        print(json.dumps({
            "file": str(destination),
            "size": gif.size,
            "frames": gif.n_frames,
            "duration_ms": total_ms,
            "loop": "infinite",
            "bytes": destination.stat().st_size,
        }, indent=2))


if __name__ == "__main__":
    main()
