import os
import cv2
import numpy as np
from mtcnn.mtcnn import MTCNN
from keras_facenet import FaceNet
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import (
    confusion_matrix, ConfusionMatrixDisplay,
    roc_curve, roc_auc_score,
    classification_report
)
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt
import seaborn as sns
import joblib
# --- Setup ---
DATASET_PATH = 'C:/Users/adelc/OneDrive/Desktop/dataset'

IMAGE_SIZE = (160, 160)
detector = MTCNN()
# Load FaceNet embedder
embedder = FaceNet()

# Utility function to load and preprocess image
def preprocess_image(img_path):
    img = cv2.imread(img_path)
    if img is None:
        raise ValueError(f"Image not found: {img_path}")
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Detect face
    results = detector.detect_faces(img_rgb)
    if len(results) == 0:
        raise ValueError(f"No face detected in {img_path}")

    # Get the bounding box of the first face
    x, y, w, h = results[0]['box']
    x, y = max(0, x), max(0, y)  # Ensure no negative values
    face = img_rgb[y:y+h, x:x+w]

    # Resize to FaceNet input size
    face = cv2.resize(face, (160, 160))

    return face

# Step 1: Create pairs and labels
X = []
y = []

persons = os.listdir(DATASET_PATH)
persons = [p for p in persons if os.path.isdir(os.path.join(DATASET_PATH, p))]

print("[INFO] Creating image pairs...")
for i, person in tqdm(enumerate(persons), total=len(persons)):
    try:
        selfie_path = os.path.join(DATASET_PATH, person, 'Selfie.jpg')
        id_path = os.path.join(DATASET_PATH, person, 'ID.jpg')

        img_selfie = preprocess_image(selfie_path)
        img_id = preprocess_image(id_path)

        emb_selfie = embedder.embeddings([img_selfie])[0]
        emb_id = embedder.embeddings([img_id])[0]

        # Positive pair (same person)
        X.append(np.abs(emb_selfie - emb_id))
        y.append(1)

        # Create a negative pair (different person)
        for j in range(1):  # One negative pair per person
            neg_person = persons[(i + j + 1) % len(persons)]
            neg_id_path = os.path.join(DATASET_PATH, neg_person, 'id.jpg')
            img_neg = preprocess_image(neg_id_path)
            emb_neg = embedder.embeddings([img_neg])[0]

            X.append(np.abs(emb_selfie - emb_neg))
            y.append(0)

    except Exception as e:
        print(f"[WARN] Skipping {person} due to error: {e}")

X = np.array(X)
y = np.array(y)

# Step 2: Train/test split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Step 3: Train a simple classifier
model = LogisticRegression()
model.fit(X_train, y_train)
joblib.dump(model, "face_verification_model.pkl")
# Step 4: Evaluate
y_pred = model.predict(X_test)
print(classification_report(y_test, y_pred))




cm = confusion_matrix(y_test, y_pred)
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=["Different", "Same"])
disp.plot(cmap=plt.cm.Blues)
plt.title("Confusion Matrix")
plt.show()

# ROC Curve
fpr, tpr, _ = roc_curve(y_test, y_proba)
auc_score = roc_auc_score(y_test, y_proba)

plt.figure()
plt.plot(fpr, tpr, label=f"AUC = {auc_score:.2f}")
plt.plot([0, 1], [0, 1], linestyle="--", color="gray")
plt.xlabel("False Positive Rate")
plt.ylabel("True Positive Rate")
plt.title("ROC Curve")
plt.legend()
plt.grid()
plt.show()

# PCA Visualization (optional)
pca = PCA(n_components=2)
X_pca = pca.fit_transform(X_test)

plt.figure(figsize=(8,6))
sns.scatterplot(x=X_pca[:,0], y=X_pca[:,1], hue=y_test, palette=["red", "green"])
plt.title("PCA of Embedding Differences")
plt.xlabel("PC 1")
plt.ylabel("PC 2")
plt.grid()
plt.show()