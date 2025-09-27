from fastapi import FastAPI, File, UploadFile, Query, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import os, json, http.client, traceback

# env
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

# OCR + helpers
from app.ocr import read_image, preprocess, ocr
from app.ocr_easyocr import ocr_structured as easy_ocr_structured
from app.pdf_ingest import pdf_to_blocks

# legacy part-extraction (kept for completeness)
from app.models import ExtractResponse
from app.extractor_llm import extract_with_llm
from app.extractor_cloud import extract_with_cloud

# STEP 3: form-oriented schema + extractor (text-only)
from app.models_form import SpecPayload
from app.extractor_cloud_form import extract_spec_with_cloud

# STEP 4: Vision → form extractor
from app.extractor_cloud_form_vision import extract_spec_with_cloud_vision as extract_spec_form_vision

app = FastAPI(title="Image Reader (OCR)", debug=True)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# static
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
def index():
    return FileResponse("static/index.html")

class ParseResponse(BaseModel):
    text: str

# ---------- OCR basic ----------
@app.post("/api/parse", response_model=ParseResponse)
async def parse_image(file: UploadFile = File(...), lang: str = Query("eng")):
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
        return JSONResponse(status_code=500, content={"error":"parse failed","detail":str(e)})

@app.post("/api/parse-structured")
async def parse_image_structured(file: UploadFile = File(...), lang: str = Query("en")):
    try:
        content = await file.read()
        ctype = file.content_type or ""
        if ctype == "application/pdf" or file.filename.lower().endswith(".pdf"):
            data = pdf_to_blocks(content, ocr_fn=easy_ocr_structured)
        else:
            data = easy_ocr_structured(content, langs=lang)
        return data
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=400, content={"error":"structured OCR error","detail":str(e)})

# ---------- legacy extract (kept) ----------
@app.post("/api/extract", response_model=ExtractResponse)
async def extract_endpoint(
    file: UploadFile = File(...),
    lang: str = Query("en"),
    debug: int = Query(0),
    cloud: int = Query(0),
    model: str = Query(None)
):
    try:
        content = await file.read()
        ctype = file.content_type or ""
        if ctype == "application/pdf" or file.filename.lower().endswith(".pdf"):
            ocr_data = pdf_to_blocks(content, ocr_fn=easy_ocr_structured)
        else:
            ocr_data = easy_ocr_structured(content, langs=lang)

        blocks = [{
            "text": it["text"], "confidence": it["confidence"],
            "bbox": it["bbox"], "quad": it["quad"],
        } for col in ocr_data.get("columns", []) for it in col.get("items", [])]

        lines = [(it["text"] or "").strip()
                 for col in ocr_data.get("columns", [])
                 for it in col.get("items", [])
                 if (it.get("text") or "").strip()]
        ocr_text = "\n".join(lines)

        if debug == 1:
            from app.heuristics import heuristics_from_blocks
            heur = heuristics_from_blocks(blocks)
            return ExtractResponse(model_used="heuristic-only", part=heur, raw_text=ocr_text, notes="(debug=1)")

        use_cloud_env = os.getenv("USE_CLOUD","0") == "1"
        if cloud == 1 or use_cloud_env:
            return extract_with_cloud(ocr_text=ocr_text, blocks=blocks, model_name=model)
        else:
            return extract_with_llm(ocr_text=ocr_text, blocks=blocks, model_override=model)

    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error":"extract endpoint failed","detail":str(e)})

# ---------- STEP 3: Spec JSON (cloud LLM → your form schema) ----------
@app.post("/api/spec", response_model=SpecPayload)
async def spec_endpoint(file: UploadFile = File(...), lang: str = Query("en"), model: str = Query(None)):
    try:
        content = await file.read()
        ctype = file.content_type or ""
        if ctype == "application/pdf" or file.filename.lower().endswith(".pdf"):
            ocr_data = pdf_to_blocks(content, ocr_fn=easy_ocr_structured)
        else:
            ocr_data = easy_ocr_structured(content, langs=lang)

        lines = [(it["text"] or "").strip()
                 for col in ocr_data.get("columns", [])
                 for it in col.get("items", [])
                 if (it.get("text") or "").strip()]
        ocr_text = "\n".join(lines)

        spec = extract_spec_with_cloud(ocr_text=ocr_text, model_name=model)
        return spec
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error":"spec mapping failed","detail":str(e)})

# ---------- STEP 4: Spec JSON via VISION (image-aware) ----------
@app.post("/api/spec-vision", response_model=SpecPayload)
async def spec_vision_endpoint(file: UploadFile = File(...), model: str = Query(None)):
    try:
        content = await file.read()
        ctype = file.content_type or ""
        images: list[bytes] = []
        if ctype == "application/pdf" or file.filename.lower().endswith(".pdf"):
            import fitz, cv2, numpy as np
            doc = fitz.open(stream=content, filetype="pdf")
            for i, page in enumerate(doc):
                if i >= 3: break
                pix = page.get_pixmap(matrix=fitz.Matrix(2,2))
                img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
                if pix.n == 4: img = img[:,:,:3]
                ok, buf = cv2.imencode(".png", cv2.cvtColor(img, cv2.COLOR_RGB2BGR))
                if ok: images.append(buf.tobytes())
            doc.close()
        else:
            images = [content]

        spec = extract_spec_form_vision(images=images, model_name=model)
        return spec
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error":"spec-vision failed","detail":str(e)})

# ---------- health ----------
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

@app.post("/api/ocr-health")
async def ocr_health(file: UploadFile = File(...)):
    try:
        content = await file.read()
        data = easy_ocr_structured(content, langs="en")
        n_cols = len(data.get("columns") or [])
        n_items = sum(len(c.get("items") or []) for c in (data.get("columns") or []))
        return {"columns": n_cols, "items": n_items}
    except Exception as e:
        return JSONResponse(status_code=400, content={"error":"ocr-health failed","detail":str(e)})
