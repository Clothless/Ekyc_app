from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from deepface import DeepFace
import shutil
import os
import traceback

app = FastAPI()

@app.post("/compare-faces")
async def compare_faces(idCardFace: UploadFile = File(...), selfie: UploadFile = File(...)):
    # Save uploaded files to temporary location
    idCardFace_path = "temp1.jpg"
    selfie_path = "temp2.jpg"
    
    try:
        # Write the first uploaded file to disk
        with open(idCardFace_path, "wb") as f1:
            shutil.copyfileobj(idCardFace.file, f1)

        # Write the second uploaded file to disk
        with open(selfie_path, "wb") as f2:
            shutil.copyfileobj(selfie.file, f2)

        # Perform comparison using DeepFace
        result = DeepFace.verify(idCardFace_path, selfie_path, model_name="VGG-Face", enforce_detection=False)


        # Extract the verification status and the similarity percentage
        is_verified = bool(result["verified"])  # Convert numpy.bool_ to native Python bool
        similarity_percentage = result["distance"]  # The 'distance' represents the similarity score

        # Calculate the similarity percentage (DeepFace gives a distance, lower is better)
        similarity_percentage = round((1 - similarity_percentage) * 100, 2)

        # Clean up the temporary files after processing
        os.remove(idCardFace_path)
        os.remove(selfie_path)

        # Return the verification result and similarity percentage
        return JSONResponse(content={
            "verified": is_verified,
            "similarity_percentage": similarity_percentage
        })

    except Exception as e:
        # Log the error details
        error_message = str(e)
        error_traceback = traceback.format_exc()

        # Clean up the temporary files in case of error
        if os.path.exists(idCardFace_path):
            os.remove(idCardFace_path)
        if os.path.exists(selfie_path):
            os.remove(selfie_path)

        # Log the error traceback for debugging
        print(f"Error: {error_message}")
        print(f"Traceback: {error_traceback}")

        # Return a generic error message with status code 500
        return JSONResponse(content={"error": error_message, "traceback": error_traceback}, status_code=500)
