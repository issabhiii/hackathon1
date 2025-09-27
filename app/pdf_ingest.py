from typing import Dict, Any, List
import fitz  # PyMuPDF
import numpy as np
import cv2

def _np_from_pixmap(pix) -> np.ndarray:
    if pix.alpha:
        pix = fitz.Pixmap(pix, 0)
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
    if pix.n == 3:
        return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    elif pix.n == 1:
        return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    else:
        return img

def pdf_to_blocks(pdf_bytes: bytes, ocr_fn) -> Dict[str, Any]:
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    all_columns: List[Dict[str, Any]] = []

    for page in doc:
        text_blocks = page.get_text("blocks")
        page_blocks = []
        for blk in text_blocks:
            if len(blk) >= 5:
                x0, y0, x1, y1, txt = blk[:5]
                txt = (txt or "").strip()
                if not txt:
                    continue
                page_blocks.append({
                    "text": txt,
                    "confidence": 0.99,
                    "bbox": [float(x0), float(y0), float(x1), float(y1)],
                    "quad": [[float(x0), float(y0)], [float(x1), float(y0)],
                             [float(x1), float(y1)], [float(x0), float(y1)]],
                    "center": [float((x0+x1)/2), float((y0+y1)/2)]
                })

        if page_blocks:
            page_blocks.sort(key=lambda b: (b["center"][0], b["bbox"][1]))
            all_columns.append({
                "x_range": [
                    min(b["bbox"][0] for b in page_blocks),
                    max(b["bbox"][2] for b in page_blocks)
                ],
                "items": [{
                    "text": b["text"],
                    "confidence": b["confidence"],
                    "bbox": b["bbox"],
                    "quad": b["quad"],
                } for b in sorted(page_blocks, key=lambda b: b["bbox"][1])]
            })
        else:
            # No text layer → render & OCR
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            img = _np_from_pixmap(pix)
            ok, buf = cv2.imencode(".png", img)
            if not ok:
                continue
            png_bytes = buf.tobytes()
            ocrd = ocr_fn(png_bytes, langs="en")
            for col in ocrd.get("columns", []):
                all_columns.append(col)

    w = int(doc[-1].rect.width) if len(doc) else 0
    h = int(doc[-1].rect.height) if len(doc) else 0
    doc.close()
    return {"width": w, "height": h, "columns": all_columns}
