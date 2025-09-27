import os, json, re
from typing import Optional, List
from openai import OpenAI
from app.models_form import SpecPayload

DEFAULT_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

SYSTEM = (
    "You extract structured product specification data from noisy OCR. "
    "Return ONLY a JSON object matching the schema. No extra keys or commentary. "
    "Prefer literal values/units as written. Do not invent data."
)

CONTRACT = """
Return a JSON object with these keys:

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

Guidelines:
- Use text EXACTLY as seen for numbers/units (e.g., '0.8750 in', '12.7mm OD', '1/2\" NPT').
- If multiple SKUs/rows, choose the FIRST clearly named part/SKU near the main section; other values go into 'physical'.
- manufacturer: brand/company in header/footer (e.g., 'Colder Products Company', 'CPC').
- part_name: main series/product (e.g., 'NS6 Series Coupling').
- manufacturer_id: a specific part like 'NS6D10008' if prominent; else null.
- acf.application: usage like 'in-line pipe connection' or 'panel mount' if clear.
- acf.category: coarse category like 'coupling', 'bearing', 'valve', etc., if obvious.
- acf.function: simple role like 'shutoff coupling', 'quick-disconnect coupling'.
- Put measurable/spec lines into 'physical' (Thread Size, Tubing Size, ID/OD/A/B/Width, Material, Ratings, Notes like 'Shutoff', etc.).
- Unknown → null (or [] for physical). Never guess.
"""

# Few-shots tailored to your coupling sheet
FEW1_IN = """Product Dimensions
Coupling Bodies  POLYPROPYLENE
IN-LINE PIPE THREAD  THREAD SIZE: 1/2" NPT  SHUTOFF  A=1.31  B=3.01  Part: NS6D10008
Also shown: 1/2" BSPT  NS6D10008BSPT
"""
FEW1_OUT = {
  "applicant": None,
  "team": None,
  "part_name": "NS6 Series Coupling Body",
  "manufacturer": None,
  "manufacturer_id": "NS6D10008",
  "include_previous_manufacturer_info": None,
  "acf": {"application": "in-line pipe connection", "category": "coupling", "function": "shutoff coupling"},
  "reason": None,
  "description": None,
  "physical": [
    {"key":"Material","value":"Polypropylene"},
    {"key":"Thread Size","value":"1/2\" NPT"},
    {"key":"Shutoff","value":"Yes"},
    {"key":"A","value":"1.31"},
    {"key":"B","value":"3.01"}
  ],
  "status":"Normal",
  "notes":None
}

FEW2_IN = """Coupling Inserts POLYPROPYLENE
IN-LINE PIPE THREAD THREAD SIZE: 1/2" NPT SHUTOFF A=1.31 B=2.44 Part: NS6D24008
Thread option: 1/2" BSPT  Part: NS6D24008BSPT
"""
FEW2_OUT = {
  "applicant": None,
  "team": None,
  "part_name": "NS6 Series Coupling Insert",
  "manufacturer": None,
  "manufacturer_id": "NS6D24008",
  "include_previous_manufacturer_info": None,
  "acf": {"application":"in-line pipe connection","category":"coupling","function":"shutoff insert"},
  "reason": None,
  "description": None,
  "physical": [
    {"key":"Material","value":"Polypropylene"},
    {"key":"Thread Size","value":"1/2\" NPT"},
    {"key":"Shutoff","value":"Yes"},
    {"key":"A","value":"1.31"},
    {"key":"B","value":"2.44"}
  ],
  "status":"Normal",
  "notes": None
}

FEW3_IN = """Footer: Call toll free 1-800-444-2474 or visit www.colder.com
Colder Products Company (CPC) — NS6 SERIES — Accessories: Panel Mount Gasket (EPDM 1884300, FKM 1889600)
"""
FEW3_OUT = {
  "applicant": None,
  "team": None,
  "part_name": "NS6 Series Coupling",
  "manufacturer": "Colder Products Company (CPC)",
  "manufacturer_id": None,
  "include_previous_manufacturer_info": None,
  "acf": {"application": None, "category": "coupling", "function": "quick-disconnect coupling"},
  "reason": None,
  "description": None,
  "physical": [
    {"key":"Accessory","value":"Panel Mount Gasket"},
    {"key":"Material","value":"EPDM (1884300) / FKM (1889600)"}
  ],
  "status":"Normal",
  "notes":None
}

def _filter_relevant_lines(ocr_text: str) -> str:
    keep: List[str] = []
    for raw in (ocr_text or "").splitlines():
        line = raw.strip()
        if not line:
            continue
        low = line.lower()
        if any(k in low for k in [
            "coupling", "insert", "body", "product dimensions", "polypropylene",
            "thread", "tubing", "hose", "barb", "compression", "panel mount",
            "shutoff", "part", "ns6", "id", "od", "a", "b", "material", "accessor",
            "colder", "cpc", "series", "dimensions"
        ]):
            keep.append(line); continue
        if re.search(r'(\d|\")', line):
            keep.append(line)
    head = (ocr_text or "").splitlines()[:6]
    return "\n".join(list(dict.fromkeys([*head, *keep])))

def extract_spec_with_cloud(ocr_text: str, model_name: Optional[str] = None) -> SpecPayload:
    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")
    if not api_key:
        return SpecPayload()

    client = OpenAI(api_key=api_key, base_url=base_url) if base_url else OpenAI(api_key=api_key)
    filtered = _filter_relevant_lines(ocr_text)

    user_prompt = (
        CONTRACT
        + "\n\nExamples:\n"
        + "INPUT:\n" + FEW1_IN + "\nOUTPUT JSON:\n" + json.dumps(FEW1_OUT, ensure_ascii=False)
        + "\n\nINPUT:\n" + FEW2_IN + "\nOUTPUT JSON:\n" + json.dumps(FEW2_OUT, ensure_ascii=False)
        + "\n\nINPUT:\n" + FEW3_IN + "\nOUTPUT JSON:\n" + json.dumps(FEW3_OUT, ensure_ascii=False)
        + "\n\nNow extract from this OCR text (filtered for relevance):\n```\n"
        + filtered
        + "\n```"
    )

    res = client.chat.completions.create(
        model=model_name or DEFAULT_MODEL,
        temperature=0.2,
        response_format={"type": "json_object"},
        messages=[{"role": "system", "content": SYSTEM},
                  {"role": "user", "content": user_prompt}],
        max_tokens=800,
    )
    content = res.choices[0].message.content or "{}"

    try:
        data = json.loads(content)
        return SpecPayload(**data)
    except Exception:
        try:
            d = json.loads(content)
            d.setdefault("acf", {})
            d.setdefault("physical", [])
            d.setdefault("status", "Normal")
            return SpecPayload(**d)
        except Exception:
            return SpecPayload()
