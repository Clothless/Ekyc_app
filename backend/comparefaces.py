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

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all HTTP methods
    allow_headers=["*"],  # Allows all headers
)

# Load detector, embedder, and model
detector = MTCNN()
embedder = FaceNet()
model = joblib.load('C:/Users/adelc/OneDrive/Desktop/face_verification_model.pkl')

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

@app.post("/compare-faces")
async def compare_faces(idCardFace: UploadFile = File(...), selfie: UploadFile = File(...)):
    idCardFace_path = "temp_id.jpg"
    selfie_path = "temp_selfie.jpg"

    try:
        # Save uploaded files
        with open(idCardFace_path, "wb") as f1:
            shutil.copyfileobj(idCardFace.file, f1)

        with open(selfie_path, "wb") as f2:
            shutil.copyfileobj(selfie.file, f2)

        # Extract and embed faces
        face1 = extract_face(idCardFace_path)
        face2 = extract_face(selfie_path)

        emb1 = embedder.embeddings([face1])[0]
        emb2 = embedder.embeddings([face2])[0]

        diff = np.abs(emb1 - emb2).reshape(1, -1)
        prediction = model.predict(diff)[0]
        confidence = model.predict_proba(diff)[0][1]  # probability for "same"

        # Clean up
        os.remove(idCardFace_path)
        os.remove(selfie_path)

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
