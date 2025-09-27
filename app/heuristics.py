# app/heuristics.py
from typing import Dict, Any, List, Tuple, Optional
import re
from app.models import ExtractedPart, ValueWithMeta

_NUM = r"[-+]?\d+(?:\.\d+)?"
_INCH = r'(?:in|inch|")'
_MM = r'(?:mm|millimet(?:er|re)s?)'
_UNIT_NUM = rf"{_NUM}\s*(?:{_INCH}|{_MM}|psi|lbs|RPM|rpm|°C|°F|C|F|kg|g|lb|oz)?"

def _vw(value: Optional[str], unit: Optional[str], conf: float, src: Dict[str, Any]) -> Optional[ValueWithMeta]:
    if value is None:
        return None
    return ValueWithMeta(value=value, unit=unit, confidence=conf, sources=[{
        "text": src.get("text",""), "bbox": src.get("bbox",[0,0,0,0]), "confidence": src.get("confidence",0.5)
    }])

def _find_first(patterns: List[re.Pattern], text: str) -> Optional[re.Match]:
    for p in patterns:
        m = p.search(text)
        if m:
            return m
    return None

def _unitize(val: str) -> Tuple[str, Optional[str]]:
    # split "0.3750 in" -> ("0.3750", "in"), "38000 RPM" -> ("38000", "RPM")
    m = re.match(rf"^\s*({_NUM})\s*([A-Za-z°\"/]+)?\s*$", val)
    if not m:
        return val.strip(), None
    v, u = m.group(1), m.group(2)
    if u:
        u = u.strip().strip(".")
    return v, u

def heuristics_from_blocks(blocks: List[Dict[str, Any]]) -> ExtractedPart:
    text_lines = [b.get("text","") for b in blocks if (b.get("text") or "").strip()]
    joined = "\n".join(text_lines)

    # ---- quick picks ----
    # common keys
    part_name = None
    manu = None
    manu_id = None
    if m := re.search(r"\b(Part\s*(?:No\.?|Number)|P/N)\b[:#]?\s*([A-Za-z0-9\-\._/]+)", joined, re.I):
        manu_id = m.group(2).strip()
    if m := re.search(r"\b(Title|Description)\b[:#]?\s*([^\n]+)", joined, re.I):
        part_name = m.group(2).strip()
    if m := re.search(r"\b(Manufacturer|Vendor|Brand)\b[:#]?\s*([^\n]+)", joined, re.I):
        manu = m.group(2).strip()

    # materials
    material = None
    if m := re.search(r"\b(Material|Stainless(?:\s*Steel)?|Aluminum|Brass|Bronze|Plastic|Nylon)\b[:\-]?\s*([^\n]*)", joined, re.I):
        # prefer "Stainless steel" line on datasheets
        mat_line = m.group(0).strip()
        material = re.sub(r"^(Material[:\-]?\s*)","",mat_line, flags=re.I)

    # dimensions (bearings/spec sheets often list three)
    width = height = depth = diagonal = None
    candidates = [
        (r"\b(?:Inner\s*diameter|ID|Bore)\b[:\s]*(" + _UNIT_NUM + ")", "width"),
        (r"\b(?:Outer\s*diameter|OD)\b[:\s]*(" + _UNIT_NUM + ")", "height"),
        (r"\b(?:Width|W|Thickness)\b[:\s]*(" + _UNIT_NUM + ")", "depth"),
        (r"\bDiagonal\b[:\s]*(" + _UNIT_NUM + ")", "diagonal"),
        # generic lines like "0.3750 in" labeled (ID), (OD), (W):
        (r"\b(ID)\b.*?(" + _UNIT_NUM + ")", "width"),
        (r"\b(OD)\b.*?(" + _UNIT_NUM + ")", "height"),
        (r"\b(W|Width)\b.*?(" + _UNIT_NUM + ")", "depth"),
    ]
    for line in text_lines:
        for pat, slot in [(re.compile(p, re.I), s) for p,s in candidates]:
            m = pat.search(line)
            if not m:
                continue
            val = m.group(2) if m.lastindex and m.lastindex >= 2 else m.group(1)
            v,u = _unitize(val)
            vw = _vw(v, u, 0.75, {"text": line, "bbox": [0,0,0,0], "confidence": 0.6})
            if slot=="width" and not width: width = vw
            if slot=="height" and not height: height = vw
            if slot=="depth" and not depth: depth = vw
            if slot=="diagonal" and not diagonal: diagonal = vw

    # temperature
    tmin = tmax = trating = None
    for line in text_lines:
        if m := re.search(r"(-?\d+)\s*°?\s*C", line, re.I):
            t = _vw(m.group(1), "°C", 0.7, {"text": line})
            tmin = tmin or t
        if m := re.search(r"(-?\d+)\s*°?\s*F", line, re.I):
            t = _vw(m.group(1), "°F", 0.7, {"text": line})
            tmax = tmax or t
        if re.search(r"\bTemperature\b|\btemp\b", line, re.I):
            trating = trating or _vw(line.strip(), None, 0.5, {"text": line})

    # pressure
    pressure = None
    if m := re.search(rf"\b({_NUM})\s*(psi|bar|kPa)\b", joined, re.I):
        pressure = _vw(m.group(1), m.group(2), 0.7, {"text": m.group(0)})

    # load ratings / RPM (bearings)
    features: List[ValueWithMeta] = []
    for line in text_lines:
        if m := re.search(rf"\b({_NUM})\s*(RPM|rpm)\b", line):
            features.append(_vw(m.group(1), "RPM", 0.8, {"text": line}))
        if m := re.search(rf"\bDynamic load rating.*?\b({_NUM})\s*(lbs|N)\b", line, re.I):
            features.append(_vw(f"dynamic_load:{m.group(1)}", m.group(2), 0.8, {"text": line}))
        if m := re.search(rf"\bStatic load rating.*?\b({_NUM})\s*(lbs|N)\b", line, re.I):
            features.append(_vw(f"static_load:{m.group(1)}", m.group(2), 0.8, {"text": line}))

    # simple price
    price = None
    if m := re.search(r"\$\s*([0-9]+(?:\.[0-9]{2})?)", joined):
        price = _vw(m.group(1), "USD", 0.8, {"text": m.group(0)})

    return ExtractedPart(
        part_name=_vw(part_name, None, 0.6, {"text": part_name or ""}) if part_name else None,
        manufacturer=_vw(manu, None, 0.6, {"text": manu or ""}) if manu else None,
        manufacturer_id=_vw(manu_id, None, 0.8, {"text": manu_id or ""}) if manu_id else None,
        function=None,
        application=None,
        price=price,
        weight=None,
        dimensions={
            "width": width, "height": height, "depth": depth, "diagonal": diagonal
        },
        temperature={"min": tmin, "max": tmax, "rating": trating},
        resolution=None, pressure=pressure, material=_vw(material, None, 0.6, {"text": material or ""}) if material else None,
        features=[f for f in features if f]
    )
