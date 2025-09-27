# app/extractor_llm.py
import json, re, http.client
from typing import Dict, Any, List, Optional
from app.models import ExtractedPart, ExtractResponse
from app.heuristics import heuristics_from_blocks

# ---- Ollama ----
OLLAMA_HOST = "localhost"
OLLAMA_PORT = 11434
# Use a small local model you have pulled (faster on CPU)
# e.g. "qwen2.5:3b-instruct" or "phi3:3.8b-mini-instruct"
OLLAMA_MODEL = "qwen2.5:3b-instruct"

# ---- Limits (speed) ----
TIMEOUT_SECS = 120
NUM_PREDICT  = 140
NUM_CTX      = 1024
MAX_LINES    = 40      # max OCR lines to send
MAX_LINE_LEN = 120     # trim long lines

SYSTEM = (
    "You are an information extraction assistant. "
    "You MUST return valid JSON only. No prose, no markdown."
)

# Few-shot: a tiny example (bearing-ish spec) to guide the model
FEW_SHOT_USER = (
"Extract fields from:\n"
"Title / Description: ACTUATOR PIVOT BEARING\n"
"Material: Stainless steel\n"
"ID: 0.3750 in\n"
"OD: 0.8750 in\n"
"Width: 0.2812 in\n"
"Dynamic load rating (radial): 748 lbs\n"
"Static load rating (radial): 316 lbs\n"
"Grease: 30% Fill\n"
)
FEW_SHOT_ASSIST = json.dumps({
  "part_name": {"value":"ACTUATOR PIVOT BEARING","unit":None,"confidence":0.9,"sources":[]},
  "manufacturer":{"value":None,"unit":None,"confidence":0.5,"sources":[]},
  "manufacturer_id":{"value":None,"unit":None,"confidence":0.5,"sources":[]},
  "function":{"value":"bearing","unit":None,"confidence":0.7,"sources":[]},
  "application":{"value":"actuator pivot","unit":None,"confidence":0.6,"sources":[]},
  "price":None,
  "weight":None,
  "dimensions":{
    "width":{"value":"0.2812","unit":"in","confidence":0.9,"sources":[]},
    "height":{"value":"0.8750","unit":"in","confidence":0.9,"sources":[]},
    "depth":{"value":"0.3750","unit":"in","confidence":0.9,"sources":[]},
    "diagonal":None
  },
  "temperature":{"min":None,"max":None,"rating":None},
  "resolution":None,
  "pressure":None,
  "material":{"value":"Stainless steel","unit":None,"confidence":0.8,"sources":[]},
  "features":[
    {"value":"dynamic_load:748","unit":"lbs","confidence":0.85,"sources":[]},
    {"value":"static_load:316","unit":"lbs","confidence":0.85,"sources":[]},
    {"value":"grease_fill:30%","unit":None,"confidence":0.6,"sources":[]}
  ]
}, ensure_ascii=False)

USER_TMPL = """OCR lines (noisy). Return ONLY JSON in the target schema. Use nulls for missing fields.

Schema keys:
part_name, manufacturer, manufacturer_id, function, application, price, weight,
dimensions {{ width, height, depth, diagonal }}, temperature {{ min, max, rating }},
resolution, pressure, material, features (array of objects with value/unit/confidence/sources=[])

LINES:
{lines}

Heuristic candidates (may be incomplete):
{candidates_json}
"""

def _http() -> http.client.HTTPConnection:
    return http.client.HTTPConnection(OLLAMA_HOST, OLLAMA_PORT, timeout=TIMEOUT_SECS)

def _post(conn: http.client.HTTPConnection, path: str, payload: dict) -> tuple[int, str]:
    body = json.dumps(payload)
    conn.request("POST", path, body, {"Content-Type": "application/json"})
    resp = conn.getresponse()
    return resp.status, resp.read().decode("utf-8", errors="ignore")

def _ollama_generate(messages: List[Dict[str,str]], model_name: str) -> str:
    # prefer /api/chat with format=json (works well across models)
    conn = _http()
    status, data = _post(conn, "/api/chat", {
        "model": model_name,
        "messages": messages,
        "stream": False,
        "options": {"temperature": 0.2, "num_predict": NUM_PREDICT, "num_ctx": NUM_CTX, "format":"json"}
    })
    if status == 200:
        parsed = json.loads(data)
        return (parsed.get("message") or {}).get("content","")
    # fallback to /api/generate
    conn = _http()
    prompt = "\n\n".join([m["content"] for m in messages if m["role"] in ("system","user")])
    status2, data2 = _post(conn, "/api/generate", {
        "model": model_name,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2, "num_predict": NUM_PREDICT, "num_ctx": NUM_CTX, "format":"json"}
    })
    if status2 == 200:
        return (json.loads(data2)).get("response","")
    raise RuntimeError(f"Ollama HTTP {status}/{status2}: {data or data2}")

def _keep_relevant_lines(lines: List[str]) -> List[str]:
    # rank by keyword hit + has number/units
    kws = [
        "part", "title", "description", "material", "stainless", "aluminum", "steel",
        "id", "od", "width", "thickness", "diagonal", "diameter", "bore",
        "psi", "pressure", "temperature", "°c", "°f", "rpm", "load", "rating",
        "sku", "p/n", "part no", "manufacturer", "brand", "model"
    ]
    scored = []
    for s in lines:
        s1 = s.lower()
        score = 0
        score += sum(1 for k in kws if k in s1)
        if re.search(r"\d", s1): score += 1
        if re.search(r'(in|mm|psi|rpm|°c|°f|lbs|n)\b', s1): score += 1
        scored.append((score, s))
    scored.sort(key=lambda x: x[0], reverse=True)
    kept = [s[:MAX_LINE_LEN] for _, s in scored[:MAX_LINES]]
    # always keep at least some head lines as context
    head = [l[:MAX_LINE_LEN] for l in lines[:8]]
    return list(dict.fromkeys(head + kept))  # de-dupe, keep order

def _try_parse_json(text: str) -> Optional[dict]:
    text = text.strip().strip("`").strip()
    try:
        return json.loads(text)
    except Exception:
        # salvage: biggest {...}
        starts = [m.start() for m in re.finditer(r"\{", text)]
        ends   = [m.start() for m in re.finditer(r"\}", text)]
        for s in starts:
            for e in ends:
                if e > s:
                    frag = text[s:e+1]
                    try:
                        return json.loads(frag)
                    except Exception:
                        pass
        return None

def extract_with_llm(
    ocr_text: str,
    blocks: List[Dict[str, Any]],
    model_override: Optional[str] = None
) -> ExtractResponse:
    # heuristics first
    heur = heuristics_from_blocks(blocks)
    candidates_json = json.dumps(heur.dict(), ensure_ascii=False)

    # build ranked lines from blocks (preserve quick context + best hits)
    lines = [b.get("text","") for b in blocks if (b.get("text") or "").strip()]
    lines = _keep_relevant_lines(lines)

    messages = [
        {"role":"system", "content": SYSTEM},
        {"role":"user", "content": FEW_SHOT_USER},
        {"role":"assistant", "content": FEW_SHOT_ASSIST},
        {"role":"user", "content": USER_TMPL.format(
            lines=json.dumps(lines, ensure_ascii=False, indent=0),
            candidates_json=candidates_json
        )},
    ]
    model_name = model_override or OLLAMA_MODEL

    try:
        raw = _ollama_generate(messages, model_name=model_name)
    except Exception as e:
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes=str(e))

    parsed = _try_parse_json(raw)
    if not parsed:
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes="LLM returned non-JSON")

    try:
        part = ExtractedPart(**parsed)
    except Exception as e:
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes=f"JSON schema mismatch: {e}")

    return ExtractResponse(model_used="ollama-llm", part=part, raw_text=ocr_text)
