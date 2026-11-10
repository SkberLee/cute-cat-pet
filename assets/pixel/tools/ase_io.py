#!/usr/bin/env python3
"""Minimal ASE / .aseprite writer (RGBA, multi-layer, multi-frame)."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path


def _u8(n: int) -> bytes:
    return bytes([n & 0xFF])


def _u16(n: int) -> bytes:
    return struct.pack("<H", n & 0xFFFF)


def _u32(n: int) -> bytes:
    return struct.pack("<I", n & 0xFFFFFFFF)


def _i16(n: int) -> bytes:
    return struct.pack("<h", int(n))


def _astr(s: str) -> bytes:
    b = s.encode("utf-8")
    return _u16(len(b)) + b


def _chunk(ctype: int, data: bytes) -> bytes:
    return _u32(6 + len(data)) + _u16(ctype) + data


def _layer_chunk(name: str, visible: bool = True, opacity: int = 255, reference: bool = False) -> bytes:
    flags = 0
    if visible:
        flags |= 1
    flags |= 2  # editable
    if reference:
        flags |= 64
    data = (
        _u16(flags)
        + _u16(0)
        + _u16(0)
        + _u16(0)
        + _u16(0)
        + _u16(0)
        + _u8(opacity)
        + b"\0\0\0"
        + _astr(name)
    )
    return _chunk(0x2004, data)


def _cel_chunk(layer: int, w: int, h: int, rgba: bytes, x: int = 0, y: int = 0, opacity: int = 255) -> bytes:
    raw = zlib.compress(rgba, 9)
    data = (
        _u16(layer)
        + _i16(x)
        + _i16(y)
        + _u8(opacity)
        + _u16(2)  # compressed image
        + b"\0" * 7
        + _u16(w)
        + _u16(h)
        + raw
    )
    return _chunk(0x2005, data)


def write_ase(path: str | Path, w: int, h: int, layers: list[dict], duration: int = 120) -> None:
    """Write an RGBA .aseprite file.

    layers: list of dicts with keys:
      name, opacity=255, visible=True, reference=False,
      frames: list[bytes|None]  (raw RGBA w*h*4, or None for empty frame)
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    nframes = max(len(L.get("frames", [None])) for L in layers) if layers else 1
    nframes = max(1, nframes)
    frame_blobs: list[bytes] = []
    for fi in range(nframes):
        chunks: list[bytes] = []
        if fi == 0:
            for L in layers:
                chunks.append(
                    _layer_chunk(
                        L["name"],
                        L.get("visible", True),
                        int(L.get("opacity", 255)),
                        L.get("reference", False),
                    )
                )
        for li, L in enumerate(layers):
            frames = L.get("frames", [None])
            img = frames[fi] if fi < len(frames) else None
            if img is not None:
                if len(img) != w * h * 4:
                    raise ValueError(f"layer {L['name']} frame {fi} size {len(img)} != {w*h*4}")
                chunks.append(_cel_chunk(li, w, h, img))
        body = b"".join(chunks)
        n = len(chunks)
        hdr = _u32(16 + len(body)) + _u16(0xF1FA) + _u16(min(n, 0xFFFF)) + _u16(duration) + b"\0\0" + _u32(n)
        frame_blobs.append(hdr + body)
    body = b"".join(frame_blobs)
    header = bytearray(128)
    struct.pack_into("<I", header, 0, 128 + len(body))
    struct.pack_into("<H", header, 4, 0xA5E0)
    struct.pack_into("<H", header, 6, nframes)
    struct.pack_into("<H", header, 8, w)
    struct.pack_into("<H", header, 10, h)
    struct.pack_into("<H", header, 12, 32)
    struct.pack_into("<I", header, 14, 1)  # layer opacity valid
    struct.pack_into("<H", header, 18, duration)
    header[34] = 1
    header[35] = 1
    path.write_bytes(bytes(header) + body)
