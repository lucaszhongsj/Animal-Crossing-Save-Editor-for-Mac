#!/usr/bin/env python3
"""Verify the generated-fixture villager scenario in VALIDATION.md.

Usage: python3 scripts/verify-villager-ui-export.py ORIGINAL_FIXTURE UI_EXPORT [LANGUAGE_SLOT]
This verifies test fixtures, not arbitrary user saves. No ACNHCore code is used.
"""
import importlib.util
import pathlib
import struct
import sys

helper_path = pathlib.Path(__file__).with_name("verify-map-ui-export.py")
spec = importlib.util.spec_from_file_location("fixture_crypto", helper_path)
crypto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(crypto)


def verify(original, exported, language=1):
    before, after = crypto.decrypt(original), crypto.decrypt(exported)
    assert len(before) == len(after) == 0x9B0E90
    expected = bytearray(before)
    offset = 0x120
    expected[offset:offset + 3] = bytes([4, 23, 2])  # Raymond, custom Cranky personality
    expected[offset + 0x46] = 255
    expected[offset + 0x1267A] |= 2
    for index, text in [(0, "Hello 🌴"), (1, "🌴" * 10)]:
        start = 0x120 + index * 0x13230 + 0x10768 + language * 0x2C
        encoded = text.encode("utf-16-le")
        expected[start:start + 44] = encoded + bytes(44 - len(encoded))
    expected[0x120 + 0x13230 + 0x46] = 0
    regions = [(0x110, 0x1E339C), (0x1E34B0, 0x3D089C)]
    for base in [0x5B3E60, 0x6288A0, 0x69D2E0, 0x711D20,
                 0x786760, 0x7FB1A0, 0x86FBE0, 0x8E4620]:
        regions += [(base, 0x37ACC), (base + 0x37AD0, 0x3CE5C)]
    regions.append((0x958F50, 0x57F3C))
    for offset, length in regions:
        checksum = crypto.murmur(after[offset + 4:offset + 4 + length])
        assert struct.unpack_from("<I", after, offset)[0] == checksum, hex(offset)
        struct.pack_into("<I", expected, offset, checksum)
    if expected != after:
        differences = [i for i, (a, b) in enumerate(zip(expected, after)) if a != b]
        raise AssertionError(f"Unexpected bytes at {[hex(i) for i in differences[:20]]}")
    for path in original.rglob("*"):
        if path.is_file() and path.name != "main.dat":
            assert path.read_bytes() == (exported / path.relative_to(original)).read_bytes(), path.name
    print("PASS: exactly the seven reviewed changes across Raymond and Lucky.")
    print("PASS: Unicode catchphrases, friendship 255/0, identity/personality and moving-out bit.")
    print("PASS: all 19 island checksums; houses, other memories, map and sibling files preserved.")


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    verify(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) == 4 else 1)
