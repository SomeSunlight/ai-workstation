#!/usr/bin/env python3
"""Offline integrity check for the shipped Windows NemoClaw penguin ICO.

This catches a malformed embedded PNG even when the Windows .lnk fixture
only verifies that an ICO file exists. No OS APIs or third-party packages.
"""
from pathlib import Path
from struct import unpack_from
from zlib import crc32, decompress

ROOT = Path(__file__).resolve().parents[2]
icon = (ROOT / "bootstrap/windows/nemoclaw-hermes.ico").read_bytes()
assert len(icon) >= 22, "icon is truncated"
reserved, icon_type, count = unpack_from("<HHH", icon)
assert (reserved, icon_type, count) == (0, 1, 1), "unexpected ICO header"
width, height, colors, reserved, planes, bits, size, offset = unpack_from("<BBBBHHII", icon, 6)
assert (width, height, planes, bits) == (64, 64, 1, 32), "unexpected ICO entry"
assert offset == 22 and offset + size == len(icon), "ICO payload length mismatch"

png = icon[offset:offset + size]
assert png[:8] == b"\x89PNG\r\n\x1a\n", "PNG signature missing"
position = 8
palette_count = None
transparency_count = None
compressed = bytearray()
seen = []
while position < len(png):
    assert position + 12 <= len(png), "PNG chunk header truncated"
    length = unpack_from(">I", png, position)[0]
    kind = png[position + 4:position + 8]
    end = position + 12 + length
    assert end <= len(png), f"{kind!r}: chunk overflows PNG"
    data = png[position + 8:position + 8 + length]
    checksum = unpack_from(">I", png, position + 8 + length)[0]
    assert crc32(kind + data) == checksum, f"{kind!r}: invalid PNG CRC"
    seen.append(kind)
    if kind == b"PLTE":
        assert length % 3 == 0
        palette_count = length // 3
    elif kind == b"tRNS":
        transparency_count = length
    elif kind == b"IDAT":
        compressed.extend(data)
    position = end
    if kind == b"IEND":
        break
assert position == len(png), "unexpected bytes after IEND"
assert seen == [b"IHDR", b"PLTE", b"tRNS", b"IDAT", b"IEND"], "unexpected PNG chunks"
assert transparency_count is not None and palette_count is not None
assert transparency_count <= palette_count, "indexed PNG transparency exceeds palette"
assert decompress(compressed), "PNG image data is empty or cannot be decompressed"
assert unpack_from(">II", png, 16) == (64, 64), "embedded PNG dimensions changed"
print("[OK] NemoClaw penguin ICO: exact size, PNG CRCs, palette and pixel data.")
