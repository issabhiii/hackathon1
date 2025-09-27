# app/ocr_paddle.py
from typing import List, Dict, Any, Tuple
import numpy as np
import cv2
from paddleocr import PaddleOCR

# Lazy global model
_OCR = None

def _get_ocr(lang: str = "en"):
    global _OCR
    if _OCR is None:
        _OCR = PaddleOCR(
            use_angle_cls=True,
            lang=lang,          # 'en' by default; add packs for others
            show_log=False,
            det_db_box_thresh=0.5,
            rec=True,
        )
    return _OCR

def _to_hw(img: np.ndarray) -> Tuple[int, int]:
    h, w = img.shape[:2]
    return h, w

def ocr_structured(image_bytes: bytes, lang: str = "en") -> Dict[str, Any]:
    """Detector+Recognizer OCR. Returns columns with ordered items and geometry."""
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Unsupported or corrupted image.")

    h, w = _to_hw(img)
    ocr = _get_ocr(lang)

    # Optional contrast boost (uncomment if scans are faint):
    # lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    # l,a,b = cv2.split(lab)
    # clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    # cl = clahe.apply(l)
    # limg = cv2.merge((cl,a,b))
    # img = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)

    result = ocr.ocr(img, cls=True)
    # Normalize result to a flat list for one image
    if isinstance(result, list) and len(result) > 0 and isinstance(result[0], list):
        result = result[0]

    blocks = []
    for item in result:
        pts = item[0]                     # 4-point polygon
        text, conf = item[1][0], float(item[1][1])
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        minx, maxx = max(0, min(xs)), min(w, max(xs))
        miny, maxy = max(0, min(ys)), min(h, max(ys))
        blocks.append({
            "text": text,
            "confidence": conf,
            "bbox": [float(minx), float(miny), float(maxx), float(maxy)],
            "quad": [[float(p[0]), float(p[1])] for p in pts],
            "center": [float((minx + maxx) / 2), float((miny + maxy) / 2)],
        })

    columns = _group_into_columns(blocks, page_width=w)
    return {"width": w, "height": h, "columns": columns}

def _group_into_columns(blocks: List[Dict[str, Any]], page_width: int) -> List[Dict[str, Any]]:
    if not blocks:
        return []
    # Sort by x center
    blocks_sorted = sorted(blocks, key=lambda b: b["center"][0])
    xs = [b["center"][0] for b in blocks_sorted]
    gaps = [xs[i+1] - xs[i] for i in range(len(xs) - 1)]
    threshold = max(40.0, 0.15 * page_width)   # split where there is a large gap

    cuts = [i for i, g in enumerate(gaps) if g > threshold]
    indices = []
    start = 0
    for cut in cuts:
        indices.append((start, cut + 1))
        start = cut + 1
    indices.append((start, len(blocks_sorted)))

    columns = []
    for (s, e) in indices:
        col_blocks = blocks_sorted[s:e]
        # sort each column top-to-bottom
        col_blocks = sorted(col_blocks, key=lambda b: b["bbox"][1])
        # (Optional) filter low-confidence items:
        # col_blocks = [b for b in col_blocks if b["confidence"] >= 0.5]
        columns.append({
            "x_range": [
                min(b["bbox"][0] for b in col_blocks),
                max(b["bbox"][2] for b in col_blocks)
            ],
            "items": [{
                "text": b["text"],
                "confidence": b["confidence"],
                "bbox": b["bbox"],
                "quad": b["quad"],
            } for b in col_blocks]
        })
    return columns
