# app/extractor_cloud.py
import os, json
from typing import Dict, Any, List, Optional
from openai import OpenAI
from app.models import ExtractedPart, ExtractResponse
from app.heuristics import heuristics_from_blocks

# Reads:
#   OPENAI_API_KEY   -> your API key
#   OPENAI_BASE_URL  -> optional (e.g., Azure / OpenRouter)
#   OPENAI_MODEL     -> default model name (e.g., gpt-4o-mini)
DEFAULT_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

SYSTEM = (
    "You are a precise information extraction assistant. "
    "Return ONLY valid JSON that matches the schema. "
    "If you do not know a field, set it to null (or [] for features). "
    "No extra keys, no commentary."
)

JSON_SCHEMA = {
  "type": "object",
  "properties": {
    "part_name":      {"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "manufacturer":   {"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "manufacturer_id":{"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "function":       {"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "application":    {"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "price":          {"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "weight":         {"type":"object","properties":{"value":{"type":["string","null"]},"unit":{"type":["string","null"]},"confidence":{"type":"number"},"sources":{"type":"array"}},"required":["value","unit","confidence","sources"]},
    "dimensions": {
      "type":"object",
      "properties":{
        "width":   {"type":["object","null"]},
        "height":  {"type":["object","null"]},
        "depth":   {"type":["object","null"]},
        "diagonal":{"type":["object","null"]}
      },
      "required":["width","height","depth","diagonal"]
    },
    "temperature": {
      "type":"object",
      "properties":{
        "min":    {"type":["object","null"]},
        "max":    {"type":["object","null"]},
        "rating": {"type":["object","null"]}
      },
      "required":["min","max","rating"]
    },
    "resolution": {"type":["object","null"]},
    "pressure":   {"type":["object","null"]},
    "material":   {"type":["object","null"]},
    "features":   {"type":"array"}
  },
  "required": ["part_name","manufacturer","manufacturer_id","function","application","price","weight","dimensions","temperature","resolution","pressure","material","features"],
  "additionalProperties": False
}

def _build_prompt(ocr_text: str, heur_json: str) -> str:
    return (
        "Extract the fields from OCR text. Use heuristics as hints; prefer exact numbers/units seen. "
        "Return ONLY JSON matching the schema.\n\n"
        f"OCR_TEXT:\n```\n{ocr_text}\n```\n\n"
        f"HEURISTIC_CANDIDATES:\n{heur_json}\n"
    )

def extract_with_cloud(
    ocr_text: str,
    blocks: List[Dict[str, Any]],
    model_name: Optional[str] = None
) -> ExtractResponse:
    # Seed with heuristics
    heur = heuristics_from_blocks(blocks)
    heur_json = json.dumps(heur.dict(), ensure_ascii=False)

    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")  # optional (e.g., Azure/OpenRouter)
    if not api_key:
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes="OPENAI_API_KEY not set")

    client = OpenAI(api_key=api_key, base_url=base_url) if base_url else OpenAI(api_key=api_key)

    prompt = _build_prompt(ocr_text, heur_json)
    # Use JSON mode for guaranteed JSON output
    res = client.chat.completions.create(
        model=model_name or DEFAULT_MODEL,
        temperature=0.2,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": prompt},
        ],
        max_tokens=400,
    )
    content = res.choices[0].message.content or "{}"

    try:
        data = json.loads(content)
        part = ExtractedPart(**data)
        return ExtractResponse(model_used="cloud-llm", part=part, raw_text=ocr_text)
    except Exception as e:
        # If parsing fails, fall back to heuristics with a note
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes=f"cloud parse error: {e}")
