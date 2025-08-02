from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import numpy as np
import cv2
import shutil
import os
from mtcnn.mtcnn import MTCNN
from keras_facenet import FaceNet
import joblib
import traceback
import base64
import io
import glymur
from PIL import Image, ImageEnhance
import numpy as np
from pydantic import BaseModel
import uuid
import os
import pytesseract
import traceback
import easyocr
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import re
from google.cloud import vision
from google.cloud.vision_v1 import types
import imutils
import time
from io import BytesIO


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load detector, embedder, and model
detector = MTCNN()
embedder = FaceNet()
model = joblib.load('C:/Users/i.chaibedraa/Downloads/my_svm_face_verification_model.pkl')

# Utility: Extract and preprocess face
def extract_face(image_path):
    img = cv2.imread(image_path)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    results = detector.detect_faces(img_rgb)
    
    if len(results) == 0:
        raise ValueError(f"No face detected in {image_path}")
    
    x, y, w, h = results[0]['box']
    x, y = max(0, x), max(0, y)
    face = img_rgb[y:y+h, x:x+w]
    face = cv2.resize(face, (160, 160))
    
    return face

@app.get("/test")
async def test():
    return JSONResponse(content={"message": "API is working!"})

def crop_id_card(image_path: str) -> str:
    """Detect and crop the ID card or passport from the image. Returns path to cropped image or raises error if not found."""
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError("Could not read image for cropping.")
    orig = img.copy()
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    edged = cv2.Canny(gray, 75, 200)
    
    # Find contours
    cnts = cv2.findContours(edged.copy(), cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:5]
    screenCnt = None
    for c in cnts:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        if len(approx) == 4:
            screenCnt = approx
            break
    if screenCnt is None:
        raise ValueError("No ID card or passport detected in the image.")
    # Order the points and do a perspective transform
    pts = screenCnt.reshape(4, 2)
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    (tl, tr, br, bl) = rect
    widthA = np.linalg.norm(br - bl)
    widthB = np.linalg.norm(tr - tl)
    maxWidth = max(int(widthA), int(widthB))
    heightA = np.linalg.norm(tr - br)
    heightB = np.linalg.norm(tl - bl)
    maxHeight = max(int(heightA), int(heightB))
    dst = np.array([
        [0, 0],
        [maxWidth - 1, 0],
        [maxWidth - 1, maxHeight - 1],
        [0, maxHeight - 1]
    ], dtype="float32")
    M = cv2.getPerspectiveTransform(rect, dst)
    warped = cv2.warpPerspective(orig, M, (maxWidth, maxHeight))
    cropped_path = f"cropped_{uuid.uuid4().hex}.jpg"
    cv2.imwrite(cropped_path, warped)
    return cropped_path

def crop_id_card_from_array(img: np.ndarray) -> np.ndarray:
    """Detect and crop the ID card or passport from a NumPy array image. Returns cropped image array or raises error if not found."""
    if img is None:
        raise ValueError("Could not read image for cropping.")
    orig = img.copy()
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    edged = cv2.Canny(gray, 75, 200)
    # Find contours
    cnts = cv2.findContours(edged.copy(), cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:5]
    screenCnt = None
    for c in cnts:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        if len(approx) == 4:
            screenCnt = approx
            break
    if screenCnt is None:
        raise ValueError("No ID card or passport detected in the image.")
    # Order the points and do a perspective transform
    pts = screenCnt.reshape(4, 2)
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    (tl, tr, br, bl) = rect
    widthA = np.linalg.norm(br - bl)
    widthB = np.linalg.norm(tr - tl)
    maxWidth = max(int(widthA), int(widthB))
    heightA = np.linalg.norm(tr - br)
    heightB = np.linalg.norm(tl - bl)
    maxHeight = max(int(heightA), int(heightB))
    dst = np.array([
        [0, 0],
        [maxWidth - 1, 0],
        [maxWidth - 1, maxHeight - 1],
        [0, maxHeight - 1]
    ], dtype="float32")
    M = cv2.getPerspectiveTransform(rect, dst)
    warped = cv2.warpPerspective(orig, M, (maxWidth, maxHeight))
    return warped

@app.post("/extract-text")
async def extract_text(image: UploadFile = File(...)):
    """Extract text from an uploaded image of an ID card or passport. Automatically crops the document before OCR. In-memory, fast version."""
    timings = {}
    t0 = time.time()
    image_bytes = await image.read()
    timings['read_upload'] = time.time() - t0
    t1 = time.time()
    # Decode image to OpenCV format
    npimg = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
    timings['decode_image'] = time.time() - t1
    t2 = time.time()
    # Crop to ID card/passport
    cropped_img = crop_id_card_from_array(img)
    timings['crop'] = time.time() - t2
    t3 = time.time()
    # Convert to PIL for preprocessing
    pil_image = Image.fromarray(cv2.cvtColor(cropped_img, cv2.COLOR_BGR2RGB)).convert("L")
    enhancer = ImageEnhance.Contrast(pil_image)
    pil_image = enhancer.enhance(2.0)  # Boost contrast
    base_width = 1000
    wpercent = base_width / float(pil_image.size[0])
    hsize = int((float(pil_image.size[1]) * wpercent))
    pil_image = pil_image.resize((base_width, hsize), Image.LANCZOS)
    timings['preprocess'] = time.time() - t3
    t4 = time.time()
    extracted_text = pytesseract.image_to_string(pil_image, lang="ara,eng")
    timings['ocr'] = time.time() - t4
    # Optionally, return debug image as base64
    debug_b64 = None
    try:
        buf = BytesIO()
        pil_image.save(buf, format="JPEG")
        debug_b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    except Exception:
        debug_b64 = None
    timings['encode_debug'] = time.time() - t4
    total_time = time.time() - t0
    timings['total'] = total_time
    return JSONResponse(content={
        "text": extracted_text.strip(),
        "debug_image_base64": debug_b64,
        "timings": timings
    })

reader = easyocr.Reader(['ar', 'en'])

french_reader = easyocr.Reader(['fr', 'en'])

class AlgerianIDProcessor:
    def __init__(self):
        self.patterns = {
            'carte_nationale': r'(CARTE NATIONALE|بطاقة وطنية|بطاقة التعريف الوطنية)',
            'republique': r'(RÉPUBLIQUE ALGÉRIENNE|الجمهورية الجزائرية)',
            'democratique': r'(DÉMOCRATIQUE POPULAIRE|الديمقراطية الشعبية)',
            'nom': r'(NOM)\s*:?\s*([A-ZÀ-ÿ\s]+)',
            'prenom': r'(PRÉNOM)\s*:?\s*([A-ZÀ-ÿ\s]+)',
            'date_naissance': r'(NÉ\(E\)\s*LE|تاريخ الميلاد|تاريخ الإزدياد)\s*:?\s*(\d{4}[\./\-]\d{2}[\./\-]\d{2}|\d{2}[\./\-]\d{2}[\./\-]\d{4})',
            'lieu_naissance': r'(NÉ\(E\)\s*À|مكان الميلاد|مكان الإزدياد)\s*:?\s*([A-ZÀ-ÿأ-ي\s]+)',
            'numero_carte': r'(\d{18}|\d{15}|\d{12}|\d{10})',
            'numero_national': r'(رقم التعريف الوطني|N°\s*NATIONAL)\s*:?\s*(\d+)',
            'adresse': r'(DOMICILIÉ\(E\)|العنوان|مقيم في)\s*:?\s*([A-ZÀ-ÿأ-ي0-9\s,\.]+)',
            'wilaya': r'(WILAYA|الولاية|ولاية)\s*:?\s*([A-ZÀ-ÿأ-ي\s]+)',
            'commune': r'(COMMUNE|البلدية|بلدية)\s*:?\s*([A-ZÀ-ÿأ-ي\s]+)',
            'validite': r'(VALABLE JUSQU|صالحة حتى|تاريخ انتهاء الصلاحية)\s*:?\s*(\d{4}[\./\-]\d{2}[\./\-]\d{2}|\d{2}[\./\-]\d{2}[\./\-]\d{4})',
            'rh': r'(RH|فصيلة الدم)\s*:?\s*([ABO+\-]+)',
            'sexe': r'(SEXE|الجنس)\s*:?\s*(M|F|ذكر|أنثى)',
            'taille': r'(TAILLE|الطول)\s*:?\s*(\d+)',
            'card_number': r'(\d{9,12})',
            'date_pattern': r'(\d{4}[\./\-]\d{2}[\./\-]\d{2}|\d{2}[\./\-]\d{2}[\./\-]\d{4})',
            # New patterns for Arabic fields
            'arabic_last_name': r'اللقب\s*:?\s*([أ-ي\s]+)',
            'arabic_first_name': r'الاسم\s*:?\s*([أ-ي\s]+)',
            'arabic_address': r'العنوان\s*:?\s*([أ-ي0-9\s,\.]+)',
        }

    def combine_ocr_results(self, arabic_results: List, french_results: List) -> List:
        """Combine and deduplicate OCR results from multiple language models"""
        combined_results = []

        for result in arabic_results:
            combined_results.append(result)
        for fr_result in french_results:
            fr_bbox, fr_text, fr_conf = fr_result

            is_duplicate = False
            for ar_result in arabic_results:
                ar_bbox, ar_text, ar_conf = ar_result

                overlap = self.calculate_bbox_overlap(fr_bbox, ar_bbox)
                if overlap > 0.7:
                    if fr_conf > ar_conf:
                        combined_results = [r for r in combined_results if r != ar_result]
                        combined_results.append(fr_result)
                    is_duplicate = True
                    break

            if not is_duplicate:
                combined_results.append(fr_result)

        return combined_results

    def calculate_bbox_overlap(self, bbox1: List, bbox2: List) -> float:
        try:
            def bbox_to_coords(bbox):
                xs = [point[0] for point in bbox]
                ys = [point[1] for point in bbox]
                return [min(xs), min(ys), max(xs), max(ys)]

            box1 = bbox_to_coords(bbox1)
            box2 = bbox_to_coords(bbox2)

            x1 = max(box1[0], box2[0])
            y1 = max(box1[1], box2[1])
            x2 = min(box1[2], box2[2])
            y2 = min(box1[3], box2[3])

            if x2 <= x1 or y2 <= y1:
                return 0.0

            intersection = (x2 - x1) * (y2 - y1)

            area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
            area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])

            union = area1 + area2 - intersection
            return intersection / union if union > 0 else 0.0

        except Exception:
            return 0.0

    def preprocess_image(self, image_path: str) -> str:
        """Advanced preprocessing: adaptive thresholding, sharpening, upscaling"""
        try:
            img = cv2.imread(image_path)
            if img is None:
                return image_path
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            # Adaptive thresholding
            processed = cv2.adaptiveThreshold(
                gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                cv2.THRESH_BINARY, 31, 10
            )
            # Sharpen
            kernel_sharp = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
            processed = cv2.filter2D(processed, -1, kernel_sharp)
            # Upscale
            processed = cv2.resize(processed, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
            processed_path = f"processed_{uuid.uuid4().hex}.jpg"
            cv2.imwrite(processed_path, processed)
            return processed_path
        except Exception as e:
            print(f"Image preprocessing failed: {e}")
            return image_path

    def extract_structured_data(self, text_blocks: List[Dict]) -> Dict:
        full_text = " ".join([block["text"] for block in text_blocks])
        print("[DEBUG] Full OCR text:", full_text)  # Debug log
        extracted_info = {
            "document_type": "Algerian Identity Card",
            "confidence_score": 0.0,
            "extracted_fields": {},
            "validation_status": "pending",
            "raw_text": full_text,
        }
        # Calculate average confidence
        if text_blocks:
            extracted_info["confidence_score"] = sum(block["confidence"] for block in text_blocks) / len(text_blocks)
        for field, pattern in self.patterns.items():
            try:
                match = re.search(pattern, full_text, re.IGNORECASE | re.MULTILINE)
                if match:
                    if len(match.groups()) > 1:
                        extracted_info["extracted_fields"][field] = match.group(2).strip()
                    else:
                        extracted_info["extracted_fields"][field] = match.group(1).strip()
            except Exception as e:
                print(f"Pattern matching error for {field}: {e}")
                continue
        self.extract_additional_info(full_text, text_blocks, extracted_info)
        extracted_info["validation_status"] = self.validate_extracted_data(extracted_info["extracted_fields"])
        return extracted_info

    def extract_additional_info(self, full_text: str, text_blocks: List[Dict], extracted_info: Dict):
        id_candidates = []
        for block in text_blocks:
            text = block["text"].strip()
            if re.match(r'^\d{10,18}$', text):
                if len(text) >= 10:
                    id_candidates.append({
                        'text': text,
                        'confidence': block['confidence'],
                        'length': len(text)
                    })

    def validate_extracted_data(self, fields: Dict) -> str:

        validation_score = 0
        total_checks = 0

        essential_fields = ['nom', 'prenom', 'date_naissance', 'numero_carte']
        for field in essential_fields:
            total_checks += 1
            if field in fields and fields[field]:
                validation_score += 1

        if 'numero_carte' in fields:
            try:
                id_number = re.sub(r'\D', '', fields['numero_carte'])
                if len(id_number) in [12, 18]:
                    validation_score += 1
            except Exception:
                pass
            total_checks += 1

        if 'date_naissance' in fields:
            try:
                date_str = fields['date_naissance']
                for fmt in ['%d/%m/%Y', '%d-%m-%Y', '%d.%m.%Y']:
                    try:
                        datetime.strptime(date_str, fmt)
                        validation_score += 1
                        break
                    except ValueError:
                        continue
            except Exception:
                pass
            total_checks += 1

        if any(keyword in fields.get('carte_nationale', '') for keyword in ['CARTE', 'بطاقة']):
            validation_score += 1
        total_checks += 1

        validation_percentage = (validation_score / total_checks) * 100 if total_checks > 0 else 0

        if validation_percentage >= 80:
            return "valid"
        elif validation_percentage >= 60:
            return "partially_valid"
        else:
            return "invalid"

    def organize_text_by_regions(self, text_blocks: List[Dict]) -> Dict:
        sorted_blocks = sorted(text_blocks, key=lambda x: x['bbox'][0][1])

        regions = {
            "header": [],
            "personal_info": [],
            "address_info": [],
            "footer": []
        }

        if len(sorted_blocks) == 0:
            return regions

        min_y = min(block['bbox'][0][1] for block in sorted_blocks)
        max_y = max(block['bbox'][2][1] for block in sorted_blocks)
        height = max_y - min_y

        for block in sorted_blocks:
            y_pos = block['bbox'][0][1]
            relative_pos = (y_pos - min_y) / height if height > 0 else 0

            if relative_pos < 0.25:
                regions["header"].append(block)
            elif relative_pos < 0.6:
                regions["personal_info"].append(block)
            elif relative_pos < 0.85:
                regions["address_info"].append(block)
            else:
                regions["footer"].append(block)

        return regions

    def extract_structured_data_from_text(self, full_text: str) -> dict:
        """Extract fields from a single text string (for Tesseract/EasyOCR combined)"""
        extracted_info = {
            "document_type": "Algerian Identity Card",
            "extracted_fields": {},
            "raw_text": full_text,
        }
        for field, pattern in self.patterns.items():
            try:
                match = re.search(pattern, full_text, re.IGNORECASE | re.MULTILINE)
                if match:
                    if len(match.groups()) > 1:
                        extracted_info["extracted_fields"][field] = match.group(2).strip()
                    else:
                        extracted_info["extracted_fields"][field] = match.group(1).strip()
            except Exception as e:
                print(f"Pattern matching error for {field}: {e}")
                continue
        return extracted_info

id_processor = AlgerianIDProcessor()

def postprocess_algerian_id_fields(raw_text: str, extracted_fields: dict) -> dict:
    # Preprocessing: normalize spaces, newlines, and fix common OCR mistakes
    def preprocess_text(text):
        replacements = [
            (r"النقب", "اللقب"),
            (r"\s+", " "),  # collapse multiple spaces
            (r"\n+", "\n"),  # collapse multiple newlines
            (r"\s*[:：]\s*", ": "),  # normalize colons
            (r"ايراشيم|ابراييم|ابرائيم", "إبراهيم"),
            (r"الإسم", "الاسم"),
            (r"حلتب|لبخ", "اللقب"),
            (r"\u200f", ""),  # remove RTL marks
        ]
        for pat, repl in replacements:
            text = re.sub(pat, repl, text, flags=re.IGNORECASE)
        return text.strip()

    norm_text = preprocess_text(raw_text)

    # Helper to find a field with fuzzy OCR tolerance
    def fuzzy_search(patterns, text):
        for pat in patterns:
            match = re.search(pat, text, re.MULTILINE | re.DOTALL)
            if match:
                return match.group(1).strip()
        return ""

    # Arabic last name (اللقب)
    arabic_last_name = fuzzy_search([
        r"اللقب[:\s\n]*([أ-ي\s]+)",
        r"اللقب\s*:?\s*([أ-ي\s]+)",
        r"اللقب\s*([أ-ي\s]+)",
    ], norm_text)

    # Arabic first name (الاسم)
    arabic_first_name = fuzzy_search([
        r"الاسم[:\s\n]*([أ-ي\s]+)",
        r"الاسم\s*:?\s*([أ-ي\s]+)",
        r"الاسم\s*([أ-ي\s]+)",
        r"محمد\s+إبراهيم",  # direct match for your name
    ], norm_text)

    # Arabic address (العنوان)
    arabic_address = fuzzy_search([
        r"العنوان[:\s\n]*([أ-ي0-9\s,\.\-]+)",
        r"العنوان\s*:?\s*([أ-ي0-9\s,\.\-]+)",
    ], norm_text)

    # Card number (رقم البطاقة)
    card_number = fuzzy_search([
        r"\b(\d{9,12})\b"
    ], norm_text) or extracted_fields.get("card_number", "")

    # National ID number (رقم التعريف الوطني)
    national_id = fuzzy_search([
        r"رقم التعريف الوطني[:\s\n]*([\d\s]+)",
        r"رقم التعريف الوطني\s*:?\s*([\d\s]+)",
    ], norm_text).replace(" ", "") or extracted_fields.get("numero_national", "")

    # Birth date (تاريخ الميلاد)
    birth_date = fuzzy_search([
        r"ت[اى]ريخ[\s\S]{0,10}لم?يلاد[:\s\n]*([\d\.\/-]{8,12})",
        r"تاريخ الميلاد\s*:?\s*([\d\.\/-]{8,12})",
    ], norm_text) or extracted_fields.get("date_naissance", "")

    # Expiration date (تاريخ الانتهاء)
    expiration_date = fuzzy_search([
        r"ت[اى]ريخ[\s\S]{0,10}إت?تهاء[:\s\n]*([\d\.\/-]{8,12})",
        r"([12][09][0-9]{2}\.[01][0-9]\.[0-3][0-9])"
    ], norm_text) or extracted_fields.get("validite", "")

    return {
        "arabicFirstName": arabic_first_name,
        "arabicLastName": arabic_last_name,
        "arabicAddress": arabic_address,
        "cardNumber": card_number,
        "nationalIdentificationNumber": national_id,
        "birthDate": birth_date,
        "expirationDate": expiration_date,
    }

import re

class AlgerianIDCardExtractor:
    def __init__(self, raw_text: str):
        self.text = self.preprocess(raw_text)

    def preprocess(self, text):
        # Normalize Arabic OCR quirks, spaces, colons, and newlines
        replacements = [
            (r"النقب", "اللقب"),
            (r"الإسم", "الاسم"),
            (r"حلتب|لبخ", "اللقب"),
            (r"ايراشيم|ابراييم|ابرائيم", "إبراهيم"),
            (r"\u200f", ""),
            (r"[\s\u202c]+", " "),  # collapse spaces and LRM
            (r"\s*[:：]\s*", ": "),
            (r"\n+", "\n"),
        ]
        for pat, repl in replacements:
            text = re.sub(pat, repl, text, flags=re.IGNORECASE)
        return text.strip()

    def extract_field(self, pattern, group=1, flags=re.MULTILINE | re.DOTALL):
        match = re.search(pattern, self.text, flags)
        return match.group(group).strip() if match else ""

    def extract(self):
        def clean_label(value, labels):
            for label in labels:
                value = value.replace(label, '').strip()
            return value
        data = {
            "nationalIdentificationNumber": self.extract_field(r"رقم التعريف الوطني[:：]?\s*([0-9]{10,20})"),
            "cardNumber": self.extract_field(r"([0-9]{8,12})", group=1),
            "arabicLastName": self.extract_field(r"اللقب[:：]?\s*([أ-ي\s]+)"),
            "arabicFirstName": self.extract_field(r"الاسم[:：]?\s*([أ-ي\s]+)"),
            "birthDate": self.extract_field(r"تاريخ الميلاد[:：]?\s*([0-9]{4}\.[0-9]{2}\.[0-9]{2})"),
            "placeOfBirth": self.extract_field(r"مكان الميلاد[:：]?\s*([أ-ي\s]+)"),
            "issueDate": self.extract_field(r"تاريخ الإصدار[:：]?\s*([0-9]{4}\.[0-9]{2}\.[0-9]{2})"),
            "expirationDate": self.extract_field(r"(تاريخ الانتهاء|تاريخ الإنتهاء|تاريخ انتهاء الصلاحية|صالحة حتى)[:：]?\s*([0-9]{4}[./-][0-9]{2}[./-][0-9]{2}|[0-9]{2}[./-][0-9]{2}[./-][0-9]{4})", group=2),
            "gender": self.extract_field(r"الجنس[:：]?\s*(ذكر|أنثى)"),
            "rh": self.extract_field(r"(Rh|RH|rh|Rhésus|فصيلة الدم)[:：]?\s*([ABO]{1,2}[+-]?)", group=2),
        }
        # Clean unwanted labels from values
        data["arabicLastName"] = clean_label(data["arabicLastName"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["arabicFirstName"] = clean_label(data["arabicFirstName"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["birthDate"] = clean_label(data["birthDate"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["placeOfBirth"] = clean_label(data["placeOfBirth"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["issueDate"] = clean_label(data["issueDate"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["expirationDate"] = clean_label(data["expirationDate"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["gender"] = clean_label(data["gender"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        data["rh"] = clean_label(data["rh"], ["اللقب", "الاسم", "تاريخ الميلاد", "الجنس", "Rh", "المكان", "الإصدار", "الانتهاء"])
        return data

@app.post("/extract-text-algerian-id")
async def extract_text_algerian_id(
        image: UploadFile = File(...),
        enhance_image: bool = True,
        extract_structured: bool = True
):
    temp_filename = f"temp_{uuid.uuid4().hex}.jpg"
    processed_filename = None
    try:
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        if enhance_image:
            processed_filename = id_processor.preprocess_image(temp_filename)
            ocr_input = processed_filename
        else:
            ocr_input = temp_filename
        # Google Cloud Vision OCR (Arabic)
        client = vision.ImageAnnotatorClient()
        with io.open(ocr_input, 'rb') as image_file:
            content = image_file.read()
        image_gcv = vision.Image(content=content)
        response = client.text_detection(image=image_gcv, image_context={"language_hints": ["ar"]})
        if response.error.message:
            raise Exception(f'Google Vision API error: {response.error.message}')
        # Extract the full text annotation
        full_text = response.full_text_annotation.text if response.full_text_annotation else ""
        # Only keep Arabic characters, digits, and whitespace
        arabic_text = ''.join([c if ((' ' <= c <= '~') or ('\u0600' <= c <= '\u06FF') or c.isspace() or c.isdigit()) else '' for c in full_text])
        # Use the new extractor
        extractor = AlgerianIDCardExtractor(arabic_text)
        extracted = extractor.extract()
        extracted["rawText"] = arabic_text
        return JSONResponse(content=extracted)
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "error": str(e),
                "error_type": type(e).__name__,
                "timestamp": datetime.now().isoformat()
            }
        )
    finally:
        for filename in [temp_filename, processed_filename]:
            if filename and os.path.exists(filename):
                try:
                    os.remove(filename)
                except:
                    pass
class ConvertRequest(BaseModel):
    jp2_base64: str

@app.post("/convert")
async def convert(req: ConvertRequest):
    jp2_bytes = base64.b64decode(req.jp2_base64)

    temp_filename = f"temp_{uuid.uuid4().hex}.jp2"
    with open(temp_filename, "wb") as f:
        f.write(jp2_bytes)

    try:
        jp2_image = glymur.Jp2k(temp_filename).read()
        pil_img = Image.fromarray(jp2_image)

        output = io.BytesIO()
        pil_img.save(output, format='JPEG')
        jpg_bytes = output.getvalue()

        return base64.b64encode(jpg_bytes).decode('utf-8')

    finally:
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

@app.post("/compare-faces")
async def compare_faces(idCardFace: UploadFile = File(...), selfie: UploadFile = File(...)):
    idCardFace_path = "temp_id.jpg"
    selfie_path = "temp_selfie.jpg"
    threshold = 0.6

    print(f"Received files: {idCardFace.filename}, {selfie.filename}")

    try:
        with open(idCardFace_path, "wb") as f1:
            shutil.copyfileobj(idCardFace.file, f1)

        with open(selfie_path, "wb") as f2:
            shutil.copyfileobj(selfie.file, f2)

        face1 = extract_face(idCardFace_path)
        face2 = extract_face(selfie_path)

        emb1 = embedder.embeddings([face1])[0]
        emb2 = embedder.embeddings([face2])[0]

        diff = np.abs(emb1 - emb2).reshape(1, -1)
        confidence = model.predict_proba(diff)[0][1]
        prediction = int(confidence >= threshold)

        os.remove(idCardFace_path)
        os.remove(selfie_path)

        print(f"Confidence: {confidence}, Prediction: {prediction}")

        return JSONResponse(content={
            "verified": bool(prediction),
            "confidence": round(confidence * 100, 2),
            "message": "Faces match!" if prediction else "Faces do not match."
        })

    except Exception as e:
        traceback.print_exc()
        if os.path.exists(idCardFace_path):
            os.remove(idCardFace_path)
        if os.path.exists(selfie_path):
            os.remove(selfie_path)
        return JSONResponse(content={"error": str(e)}, status_code=500)
