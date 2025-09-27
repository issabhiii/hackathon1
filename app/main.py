# app/main.py

from fastapi import FastAPI, File, UploadFile, Query, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app.ocr import read_image, preprocess, ocr
from app.ocr_easyocr import ocr_structured as easy_ocr_structured

app = FastAPI(title="Image Reader (OCR)")

# CORS so the frontend can call the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

class ParseResponse(BaseModel):
    text: str

# -------- Classic OCR (Tesseract) --------
@app.post("/api/parse", response_model=ParseResponse)
async def parse_image(
    file: UploadFile = File(...),
    lang: str = Query("eng", description="Tesseract language code, e.g. eng or eng+spa")
):
    content = await file.read()
    img = read_image(content)
    if img is None:
        return JSONResponse({"detail": "Unsupported or corrupted image."}, status_code=400)
    img_bin = preprocess(img)
    text = ocr(img_bin, lang=lang)
    return ParseResponse(text=text)

# -------- Structured OCR (EasyOCR) --------
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
        raise HTTPException(status_code=400, detail=str(e))

# -------- Static + index --------
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
def index():
    return FileResponse("static/index.html")
