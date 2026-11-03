import os
import sys

import numpy as np
from PIL import Image, ImageOps

try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError:
    try:
        from tflite_runtime.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter

MODEL = r"C:\CropGuard_ML\crop_disease_model.tflite"
LABELS = r"C:\CropGuard_ML\class_names.txt"
DATASET = r"C:\CropGuard_ML\dataset"
PER_CLASS = 20

interp = Interpreter(model_path=MODEL)
interp.allocate_tensors()
inp = interp.get_input_details()[0]
out = interp.get_output_details()[0]
names = [l.strip() for l in open(LABELS, encoding="utf-8") if l.strip()]
print("Input shape:", inp["shape"], "dtype:", inp["dtype"])


def predict(path):
    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB").resize((224, 224))
    arr = (np.asarray(img, dtype=np.float32) / 255.0)[None, ...].astype(inp["dtype"])
    interp.set_tensor(inp["index"], arr)
    interp.invoke()
    probs = interp.get_tensor(out["index"])[0]
    order = np.argsort(probs)[::-1][:3]
    return [(names[i], float(probs[i])) for i in order]


if len(sys.argv) > 1:
    for name, p in predict(sys.argv[1]):
        print(f"{name:30s} {p * 100:5.1f}%")
    sys.exit()

total = correct = 0
for cls in sorted(os.listdir(DATASET)):
    folder = os.path.join(DATASET, cls)
    if not os.path.isdir(folder):
        continue
    files = [f for f in os.listdir(folder)
             if f.lower().endswith((".jpg", ".jpeg", ".png"))][:PER_CLASS]
    ok = 0
    wrong = []
    for f in files:
        top = predict(os.path.join(folder, f))[0]
        if top[0] == cls:
            ok += 1
        else:
            wrong.append(top[0])
    total += len(files)
    correct += ok
    print(f"{cls:30s} {ok}/{len(files)}   wrong -> {sorted(set(wrong))}")

print(f"\nOVERALL: {correct}/{total} = {100 * correct / max(total, 1):.1f}%")