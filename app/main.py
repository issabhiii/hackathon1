# app/main.py

from fastapi import FastAPI, File, UploadFile, Query, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import os, json, http.client, traceback

# load .env if present (for OPENAI_API_KEY, USE_CLOUD, OPENAI_MODEL, etc.)
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

# ---- app modules ----
from app.ocr import read_image, preprocess, ocr                   # Tesseract path
from app.ocr_easyocr import ocr_structured as easy_ocr_structured # EasyOCR path
from app.models import ExtractResponse
from app.extractor_llm import extract_with_llm                    # local (Ollama)
from app.extractor_cloud import extract_with_cloud                # cloud (OpenAI-compatible)

app = FastAPI(title="Image Reader (OCR)", debug=True)

# ---- CORS: open for local dev ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# ---- static site (index.html + css/js) ----
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
def index():
    return FileResponse("static/index.html")

# ---- small response model for /api/parse ----
class ParseResponse(BaseModel):
    text: str

# ===============================
#            ENDPOINTS
# ===============================

# 1) Classic OCR via Tesseract (single string)
@app.post("/api/parse", response_model=ParseResponse)
async def parse_image(
    file: UploadFile = File(...),
    lang: str = Query("eng", description="Tesseract language code, e.g. eng or eng+spa")
):
    try:
        content = await file.read()
        img = read_image(content)
        if img is None:
            raise HTTPException(status_code=400, detail="Unsupported or corrupted image.")
        img_bin = preprocess(img)
        text = ocr(img_bin, lang=lang)
        return ParseResponse(text=text)
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": "parse failed", "detail": str(e)})

# 2) Structured OCR via EasyOCR (blocks + columns)
@app.post("/api/parse-structured")
async def parse_image_structured(
    file: UploadFile = File(...),
    lang: str = Query("en", description="EasyOCR languages, e.g. 'en' or 'en,es'")
):
    try:
        content = await file.read()
        data = easy_ocr_structured(content, langs=lang)
        return data
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=400, content={"error": "structured OCR error", "detail": str(e)})

# 3) Extract: OCR -> heuristics -> LLM (local or cloud)
@app.post("/api/extract", response_model=ExtractResponse)
async def extract_endpoint(
    file: UploadFile = File(...),
    lang: str = Query("en", description="EasyOCR languages, e.g. 'en' or 'en,es'"),
    debug: int = Query(0, description="set to 1 to return heuristics-only (skip LLM)"),
    cloud: int = Query(0, description="set to 1 to force cloud LLM if configured"),
    model: str = Query(None, description="optional LLM model override (local or cloud)")
):
    try:
        # --- (A) OCR first (structured) ---
        content = await file.read()
        ocr_data = easy_ocr_structured(content, langs=lang)

        # flatten blocks
        blocks = [{
            "text": it["text"],
            "confidence": it["confidence"],
            "bbox": it["bbox"],
            "quad": it["quad"],
        } for col in ocr_data.get("columns", []) for it in col.get("items", [])]

        # build readable text (for UI / cloud prompt)
        lines = [(it["text"] or "").strip() for col in ocr_data.get("columns", []) for it in col.get("items", [])]
        ocr_text = "\n".join([t for t in lines if t])

        # optional early return to verify OCR + heuristics only
        if debug == 1:
            from app.heuristics import heuristics_from_blocks
            heur = heuristics_from_blocks(blocks)
            return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes="(debug=1) returned before LLM")

        # --- (B) Choose LLM path ---
        use_cloud_env = os.getenv("USE_CLOUD", "0") == "1"
        if cloud == 1 or use_cloud_env:
            # Cloud GPU model (OpenAI compatible)
            result = extract_with_cloud(ocr_text=ocr_text, blocks=blocks, model_name=model)
        else:
            # Local Ollama model
            result = extract_with_llm(ocr_text=ocr_text, blocks=blocks, model_override=model)

        return result

    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": "extract endpoint failed", "detail": str(e)})

# ===============================
#           HEALTH CHECKS
# ===============================

# Ollama health (local LLM daemon)
@app.get("/api/ollama-health")
def ollama_health():
    try:
        conn = http.client.HTTPConnection("localhost", 11434, timeout=5)
        conn.request("GET", "/api/tags")
        resp = conn.getresponse()
        data = resp.read().decode("utf-8", errors="ignore")
        ok = (resp.status == 200)
        body = json.loads(data) if ok else data
        return {"ok": ok, "status": resp.status, "body": body}
    except Exception as e:
        return {"ok": False, "error": str(e)}

# Minimal OCR smoke test (EasyOCR path)
@app.post("/api/ocr-health")
async def ocr_health(file: UploadFile = File(...)):
    try:
        content = await file.read()
        data = easy_ocr_structured(content, langs="en")
        n_cols = len(data.get("columns") or [])
        n_items = sum(len(c.get("items") or []) for c in (data.get("columns") or []))
        return {"columns": n_cols, "items": n_items}
    except Exception as e:
        return JSONResponse(status_code=400, content={"error": "ocr-health failed", "detail": str(e)})
