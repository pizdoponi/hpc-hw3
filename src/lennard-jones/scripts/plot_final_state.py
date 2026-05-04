#!/usr/bin/env python3
import csv
import math
import sys
from pathlib import Path


def read_state(path: Path):
    metadata = {}
    data_lines = []

    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("#"):
                text = line[1:].strip()
                if "=" in text:
                    key, value = text.split("=", 1)
                    metadata[key.strip()] = value.strip()
                continue
            data_lines.append(line)

    reader = csv.DictReader(data_lines)
    particles = [row for row in reader]
    return metadata, particles


def main():
    if len(sys.argv) != 3:
        print("Usage: plot_final_state.py <input.csv> <output.svg>", file=sys.stderr)
        return 1

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    metadata, particles = read_state(input_path)
    box_size = float(metadata.get("box_size", "1.0"))
    width = 900
    height = 900
    margin = 40
    draw_size = min(width, height) - 2 * margin
    scale = draw_size / box_size if box_size > 0.0 else 1.0
    radius = max(1.5, min(4.0, 180.0 / math.sqrt(max(len(particles), 1))))

    svg_lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<rect x="{margin}" y="{margin}" width="{draw_size}" height="{draw_size}" fill="none" stroke="black" stroke-width="2"/>',
    ]

    for particle in particles:
        x = float(particle["x"])
        y = float(particle["y"])
        px = margin + x * scale
        py = margin + (box_size - y) * scale
        svg_lines.append(
            f'<circle cx="{px:.3f}" cy="{py:.3f}" r="{radius:.3f}" fill="#1f77b4" fill-opacity="0.85"/>'
        )

    title = (
        f"device={metadata.get('device', '?')}  particles={metadata.get('particles', '?')}  "
        f"steps={metadata.get('steps', '?')}  block={metadata.get('gpu_block_size', '?')}"
    )
    svg_lines.append(
        f'<text x="{margin}" y="24" font-family="monospace" font-size="16" fill="black">{title}</text>'
    )
    svg_lines.append("</svg>\n")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(svg_lines), encoding="utf-8")
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
