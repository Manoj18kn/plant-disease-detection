import io
import os
import sqlite3
import threading

import numpy as np
import uvicorn
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps

# ---------------------------------------------------------------- CONFIG
MODEL_PATH = os.environ.get("MODEL_PATH", r"C:\CropGuard_ML\crop_disease_model.tflite")
LABELS_PATH = os.environ.get("LABELS_PATH", r"C:\CropGuard_ML\class_names.txt")
CONF_THRESHOLD = 0.85   # below this confidence, the image is rejected
MIN_LEAF_RATIO = 0.20   # at least 20% of pixels must look like leaf colours
IMG_SIZE = (224, 224)
DB = "cropguard.db"

# ---------------------------------------------------------------- MODEL
try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError:
    try:
        from tflite_runtime.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter

interpreter = Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()[0]
output_details = interpreter.get_output_details()[0]
model_lock = threading.Lock()

with open(LABELS_PATH, encoding="utf-8") as f:
    CLASS_NAMES = [line.strip() for line in f if line.strip()]

print(f"Model loaded. {len(CLASS_NAMES)} classes: {CLASS_NAMES}")

# ---------------------------------------------------------------- TREATMENTS
# class name -> (severity, medicine, dosage, frequency, tip)
TREATMENTS = {
    "Corn_Common_Rust": ("Medium", "Mancozeb or Azoxystrobin", "2g per litre (Mancozeb)", "Every 10 days", "Spray at first signs of pustules. Plant resistant hybrids."),
    "Corn_Gray_Leaf_Spot": ("High", "Azoxystrobin + Propiconazole", "1ml per litre", "Every 14 days", "Rotate crops and remove crop residue after harvest."),
    "Corn_Healthy": ("None", "None needed", "-", "-", "Plant looks healthy. Keep monitoring weekly."),
    "Corn_Northern_Blight": ("High", "Propiconazole", "1ml per litre", "Every 14 days", "Use resistant hybrids and avoid dense planting."),
    "Tomato_Bacterial_Spot": ("High", "Copper hydroxide", "2.5g per litre", "Every 7 days", "Avoid overhead watering. Use disease-free seeds."),
    "Tomato_Early_Blight": ("Medium", "Chlorothalonil or Mancozeb", "2g per litre", "Every 10 days", "Remove lower infected leaves. Mulch the soil."),
    "Tomato_Healthy": ("None", "None needed", "-", "-", "Plant looks healthy. Keep monitoring weekly."),
    "Tomato_Late_Blight": ("High", "Metalaxyl + Mancozeb", "2g per litre", "Every 5 days", "Destroy infected plants. Spread is fast in cool, wet weather."),
    "Tomato_Leaf_Mold": ("Medium", "Chlorothalonil", "2g per litre", "Every 10 days", "Improve air circulation and reduce humidity."),
    "Tomato_Mosaic_Virus": ("High", "No chemical cure", "-", "-", "Remove and destroy infected plants. Disinfect tools and wash hands."),
    "Tomato_Septoria_Leaf_Spot": ("Medium", "Copper fungicide or Chlorothalonil", "3g per litre", "Every 7 days", "Remove infected leaves. Rotate crops yearly."),
    "Tomato_Spider_Mites": ("Medium", "Neem oil or Abamectin", "5ml per litre (Neem oil)", "Every 5 days", "Spray the underside of leaves. Avoid dusty, dry conditions."),
    "Tomato_Target_Spot": ("Medium", "Azoxystrobin or Chlorothalonil", "1ml per litre", "Every 10 days", "Prune for airflow and remove infected debris."),
    "Tomato_Yellow_Leaf_Curl": ("High", "Imidacloprid (controls whitefly)", "0.5ml per litre", "Every 10 days", "Control whiteflies and remove infected plants early."),
}

# ---------------------------------------------------------------- APP
app = FastAPI(title="Crop Guard API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def db():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = db()
    conn.execute(
        "CREATE TABLE IF NOT EXISTS users ("
        "id TEXT PRIMARY KEY, phone TEXT UNIQUE, name TEXT DEFAULT '')"
    )
    conn.execute(
        "CREATE TABLE IF NOT EXISTS scans ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, disease TEXT, "
        "crop TEXT, confidence REAL, severity TEXT, medicine TEXT, "
        "dosage TEXT, frequency TEXT, tip TEXT, "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP)"
    )
    conn.commit()
    conn.close()


def leaf_ratio(img):
    """Fraction of pixels in leaf-like colours (yellow-green to green)."""
    hsv = np.asarray(img.convert("HSV"), dtype=np.int32)
    h, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    mask = (h >= 18) & (h <= 120) & (sat >= 50) & (val >= 40)
    return float(mask.mean())


def run_model(image_bytes: bytes):
    img = Image.open(io.BytesIO(image_bytes))
    img = ImageOps.exif_transpose(img).convert("RGB").resize(IMG_SIZE)
    ratio = leaf_ratio(img)
    arr = np.asarray(img, dtype=np.float32) / 255.0  # same as training: rescale=1/255
    arr = np.expand_dims(arr, axis=0).astype(input_details["dtype"])
    with model_lock:
        interpreter.set_tensor(input_details["index"], arr)
        interpreter.invoke()
        probs = interpreter.get_tensor(output_details["index"])[0]
    order = np.argsort(probs)[::-1][:3]
    top3 = [(CLASS_NAMES[int(i)], round(float(probs[i]), 3)) for i in order]
    return int(order[0]), float(probs[order[0]]), ratio, top3


@app.get("/")
def root():
    return {"message": "Crop Guard API Running", "status": "online", "classes": len(CLASS_NAMES)}


@app.post("/register")
def register(phone: str = Form(...)):
    phone = phone.strip()
    user_id = f"user_{phone}"
    conn = db()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        conn.execute("INSERT INTO users (id, phone) VALUES (?, ?)", (user_id, phone))
        conn.commit()
        name = ""
    else:
        name = row["name"] or ""
    conn.close()
    return {"user_id": user_id, "phone": phone, "name": name}


@app.post("/profile")
def profile(user_id: str = Form(...), name: str = Form(...)):
    conn = db()
    conn.execute("UPDATE users SET name = ? WHERE id = ?", (name, user_id))
    conn.commit()
    conn.close()
    return {"status": "ok", "user_id": user_id, "name": name}


@app.post("/predict")
async def predict(user_id: str = Form(...), file: UploadFile = File(...)):
    data = await file.read()
    try:
        idx, conf, ratio, top3 = run_model(data)
    except Exception as e:
        return {"recognized": False, "message": f"Could not read the image: {e}"}

    print(f"[predict] top3={top3} leaf_ratio={ratio:.2f}")
    debug = {"top3": top3, "leaf_ratio": round(ratio, 2)}

    if ratio < MIN_LEAF_RATIO:
        return {
            "recognized": False,
            "message": "No leaf detected. Please take a clear, close photo of a tomato or corn leaf.",
            "debug": debug,
        }
    if conf < CONF_THRESHOLD:
        return {
            "recognized": False,
            "confidence": round(conf * 100, 1),
            "message": "Could not recognize the crop. Please take a clear photo of a tomato or corn leaf.",
            "debug": debug,
        }

    class_name = CLASS_NAMES[idx]
    crop, _, disease = class_name.partition("_")
    disease = disease.replace("_", " ")
    severity, medicine, dosage, frequency, tip = TREATMENTS.get(
        class_name, ("Unknown", "Consult an agriculture officer", "-", "-", "-")
    )
    confidence = round(conf * 100, 1)

    conn = db()
    conn.execute(
        "INSERT INTO scans (user_id, disease, crop, confidence, severity, "
        "medicine, dosage, frequency, tip) VALUES (?,?,?,?,?,?,?,?,?)",
        (user_id, disease, crop, confidence, severity, medicine, dosage, frequency, tip),
    )
    conn.commit()
    conn.close()

    return {
        "recognized": True,
        "disease": disease,
        "crop": crop,
        "confidence": confidence,
        "severity": severity,
        "medicine": medicine,
        "dosage": dosage,
        "frequency": frequency,
        "tip": tip,
        "debug": debug,
    }


@app.get("/history")
def history(user_id: str):
    conn = db()
    rows = conn.execute(
        "SELECT * FROM scans WHERE user_id = ? ORDER BY id DESC LIMIT 10",
        (user_id,),
    ).fetchall()
    conn.close()
    return {"scans": [dict(r) for r in rows]}


@app.get("/weather")
def weather():
    return {"temp": 28, "condition": "Sunny", "humidity": 60}


@app.get("/market")
def market():
    return {"prices": [{"crop": "Tomato", "price": 25}, {"crop": "Corn", "price": 18}]}


if __name__ == "__main__":
    init_db()
    print("Crop Guard Backend Starting...")
    uvicorn.run(app, host="0.0.0.0", port=8000)