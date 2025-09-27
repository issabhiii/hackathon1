# app/ocr_easyocr.py
from typing import Dict, Any, List, Tuple
import numpy as np
import cv2
import easyocr

# Cache a single Reader instance and the langs it was created with
_READER: easyocr.Reader | None = None
_READER_LANGS: List[str] | None = None

def _get_reader(lang_list: List[str]) -> easyocr.Reader:
    global _READER, _READER_LANGS
    # If we don't have a reader yet, or langs changed, make a new one
    if _READER is None or _READER_LANGS is None or set(_READER_LANGS) != set(lang_list):
        _READER = easyocr.Reader(lang_list, gpu=False, verbose=False)
        _READER_LANGS = list(lang_list)
    return _READER

def _hw(img: np.ndarray) -> Tuple[int, int]:
    h, w = img.shape[:2]
    return h, w

def ocr_structured(image_bytes: bytes, langs: str = "en") -> Dict[str, Any]:
    """
    EasyOCR end-to-end detection+recognition.
    Returns columns with ordered items and geometry (bbox + quad).
    """
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Unsupported or corrupted image.")
    h, w = _hw(img)

    # Support comma-separated languages like "en,es"
    lang_list = [s.strip() for s in langs.split(",") if s.strip()] or ["en"]

    reader = _get_reader(lang_list)
    # result: list of [ [x1,y1],[x2,y2],[x3,y3],[x4,y4] ], text, confidence
    result = reader.readtext(img)

    blocks = []
    for quad, text, conf in result:
        xs = [p[0] for p in quad]
        ys = [p[1] for p in quad]
        minx, maxx = max(0, min(xs)), min(w, max(xs))
        miny, maxy = max(0, min(ys)), min(h, max(ys))
        blocks.append({
            "text": text,
            "confidence": float(conf),
            "bbox": [float(minx), float(miny), float(maxx), float(maxy)],
            "quad": [[float(x), float(y)] for x, y in quad],
            "center": [float((minx + maxx)/2), float((miny + maxy)/2)],
        })

    columns = _group_into_columns(blocks, page_width=w)
    return {"width": w, "height": h, "columns": columns}

def _group_into_columns(blocks: List[Dict[str, Any]], page_width: int) -> List[Dict[str, Any]]:
    if not blocks:
        return []
    # sort by x center then split on large gaps
    blocks_sorted = sorted(blocks, key=lambda b: b["center"][0])
    xs = [b["center"][0] for b in blocks_sorted]
    gaps = [xs[i+1]-xs[i] for i in range(len(xs)-1)]
    threshold = max(40.0, 0.15 * page_width)
    cuts = [i for i, g in enumerate(gaps) if g > threshold]

    # slice columns
    indices = []
    start = 0
    for cut in cuts:
        indices.append((start, cut+1))
        start = cut+1
    indices.append((start, len(blocks_sorted)))

    columns = []
    for s, e in indices:
        col = sorted(blocks_sorted[s:e], key=lambda b: b["bbox"][1])
        columns.append({
            "x_range": [
                min(b["bbox"][0] for b in col),
                max(b["bbox"][2] for b in col)
            ],
            "items": [{
                "text": b["text"],
                "confidence": b["confidence"],
                "bbox": b["bbox"],
                "quad": b["quad"],
            } for b in col]
        })
    return columns
