# app/ocr.py
import cv2
import numpy as np
import pytesseract
from PIL import Image

# You confirmed this path exists:
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

def read_image(file_bytes: bytes):
    """Bytes -> OpenCV image (BGR). Returns None if decode fails."""
    arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    return img

def preprocess(img):
    """Grayscale + denoise + adaptive threshold."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.bilateralFilter(gray, 9, 75, 75)
    thr = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY,
        35, 11
    )
    return thr

def ocr(img_bin, lang: str = "eng") -> str:
    """Run Tesseract on a binarized image."""
    pil = Image.fromarray(img_bin)
    config = r'--oem 3 --psm 6'
    text = pytesseract.image_to_string(pil, lang=lang, config=config)
    return text
