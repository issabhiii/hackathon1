import os, json
from typing import Dict, Any, List, Optional
from openai import OpenAI
from app.models import ExtractedPart, ExtractResponse
from app.heuristics import heuristics_from_blocks

DEFAULT_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

SYSTEM = (
    "You are a precise information extraction assistant. "
    "Return ONLY valid JSON that matches the schema. "
    "If you do not know a field, set it to null (or [] for features). "
    "No extra keys, no commentary."
)

def _build_prompt(ocr_text: str, heur_json: str) -> str:
    return (
        "Extract the fields from OCR text. Use heuristics as hints; prefer exact numbers/units seen. "
        "Return ONLY JSON matching the schema.\n\n"
        f"OCR_TEXT:\n```\n{ocr_text}\n```\n\n"
        f"HEURISTIC_CANDIDATES:\n{heur_json}\n"
    )

def extract_with_cloud(ocr_text: str, blocks: List[Dict[str, Any]], model_name: Optional[str] = None) -> ExtractResponse:
    heur = heuristics_from_blocks(blocks)
    heur_json = json.dumps(heur.dict(), ensure_ascii=False)

    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")  # optional (Azure/OpenRouter)
    if not api_key:
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes="OPENAI_API_KEY not set")

    client = OpenAI(api_key=api_key, base_url=base_url) if base_url else OpenAI(api_key=api_key)

    prompt = _build_prompt(ocr_text, heur_json)
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
        return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes=f"cloud parse error: {e}")
