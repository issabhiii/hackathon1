import os, json, base64
from typing import Optional, List, Dict, Any
from openai import OpenAI
from app.models_form import SpecPayload

DEFAULT_MODEL_VISION = os.getenv("OPENAI_VISION_MODEL", "gpt-4o-mini")

SYSTEM = (
    "You are an expert at extracting structured product specification data from IMAGES of datasheets. "
    "Return ONLY a JSON object that matches the given schema. No extra keys or commentary. "
    "Prefer literal numeric values and units exactly as shown."
)

CONTRACT = """
Schema:

{
  "applicant": string|null,
  "team": string|null,
  "part_name": string|null,
  "manufacturer": string|null,
  "manufacturer_id": string|null,
  "include_previous_manufacturer_info": boolean|null,
  "acf": {
    "application": string|null,
    "category": string|null,
    "function": string|null
  },
  "reason": string|null,
  "description": string|null,
  "physical": [ { "key": string, "value": string } ],
  "status": "Normal" | "Urgent",
  "notes": string|null
}

Rules:
- Read table headers and cells as keys/values (e.g., 'Thread Size', 'Tubing Size', 'A', 'B', 'Material', 'Shutoff').
- If multiple SKUs/rows, choose the FIRST clearly indicated main part number near the top/main section; others may be listed under 'physical'.
- Manufacturer can be in header/footer (e.g., 'Colder Products Company (CPC)').
- Preserve units exactly (e.g., '1/2\" NPT', '12.7mm OD', '1.31').
- Unknown → null (or [] for physical).
"""

def _b64uri(png_bytes: bytes) -> str:
    return "data:image/png;base64," + base64.b64encode(png_bytes).decode("ascii")

def extract_spec_with_cloud_vision(images: List[bytes], model_name: Optional[str] = None) -> SpecPayload:
    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")
    if not api_key:
        return SpecPayload()

    client = OpenAI(api_key=api_key, base_url=base_url) if base_url else OpenAI(api_key=api_key)

    content: List[Dict[str,Any]] = [{"type":"text","text": CONTRACT}]
    for img in images[:3]:
        content.append({"type":"image_url","image_url":{"url": _b64uri(img)}})

    res = client.chat.completions.create(
        model=model_name or DEFAULT_MODEL_VISION,
        temperature=0.2,
        response_format={"type": "json_object"},
        messages=[{"role":"system","content":SYSTEM},
                  {"role":"user","content":content}],
        max_tokens=800,
    )
    text = res.choices[0].message.content or "{}"
    try:
        data = json.loads(text)
        return SpecPayload(**data)
    except Exception:
        try:
            d = json.loads(text)
            d.setdefault("acf", {})
            d.setdefault("physical", [])
            d.setdefault("status", "Normal")
            return SpecPayload(**d)
        except Exception:
            return SpecPayload()
