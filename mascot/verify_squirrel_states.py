#!/usr/bin/env python3
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import Image, ImageChops


ROOT = Path(__file__).parent
SOURCE = Path("/Users/laike/Downloads/Image 10.png")
SHEET = ROOT / "squirrel_states_reference.png"
SVG = ROOT / "squirrel_states.svg"
OFFSETS = [(0, 0), (-512, 0), (-1024, 0), (0, -512), (-512, -512), (-1024, -512)]
STATES = ["eating", "belly", "expecting", "licking", "meditating", "celebrating"]


def main() -> None:
    assert SOURCE.read_bytes() == SHEET.read_bytes(), "reference copy changed"

    source = Image.open(SOURCE).convert("RGB")
    sheet = Image.open(SHEET).convert("RGB")
    assert source.size == sheet.size == (1536, 1024)

    root = ET.parse(SVG).getroot()
    ns = {"svg": "http://www.w3.org/2000/svg"}
    assert root.attrib["viewBox"] == "0 0 512 512"
    style = root.find("svg:style", ns).text
    assert "animation: morph-state 24s" in style
    assert "* 4s - 800ms" in style
    assert "filter: blur(5px)" in style
    assert [group.attrib["id"] for group in root.findall("svg:g", ns)] == STATES
    uses = root.findall("svg:g/svg:use", ns)
    assert [(int(use.attrib["x"]), int(use.attrib["y"])) for use in uses] == OFFSETS

    for x, y in OFFSETS:
        box = (-x, -y, -x + 512, -y + 512)
        assert ImageChops.difference(source.crop(box), sheet.crop(box)).getbbox() is None

    print("PASS: 6 SVG states map pixel-for-pixel to the 6 reference tiles")


if __name__ == "__main__":
    main()
