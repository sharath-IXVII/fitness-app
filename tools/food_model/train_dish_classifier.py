"""Trains step 2, "which dish is it": a phone-sized classifier on the dish
cut-outs made by build_dataset.py (DATA_DIR/cls/<food id>/*.jpg).

Writes OUT_DIR/food_dish.tflite and food_dish_labels.csv ("id,name", name =
the app's food id), and prints the accuracy for every dish on photos the
model never trained on.
"""

import csv
import os
import pathlib
import random
import shutil

import numpy as np
from PIL import Image

DATA = pathlib.Path(os.environ.get("DATA_DIR", "/content/data")) / "cls"
OUT = pathlib.Path(os.environ.get("OUT_DIR", "/content/out"))
EPOCHS = int(os.environ.get("EPOCHS", "15"))
MIN_PHOTOS = int(os.environ.get("MIN_PHOTOS", "8"))
WORK = pathlib.Path("/content/clswork")
OUT.mkdir(parents=True, exist_ok=True)

# Hold back 15% of each dish for an honest test.
random.seed(3)
for split in ("train", "test"):
    shutil.rmtree(WORK / split, ignore_errors=True)
skipped = []
for d in sorted(DATA.iterdir()):
    files = sorted(d.glob("*.jpg"))
    if len(files) < MIN_PHOTOS:
        skipped.append((d.name, len(files)))
        continue
    random.shuffle(files)
    n_test = max(2, len(files) * 15 // 100)
    for split, part in (("test", files[:n_test]), ("train", files[n_test:])):
        (WORK / split / d.name).mkdir(parents=True, exist_ok=True)
        for f in part:
            shutil.copy(f, WORK / split / d.name / f.name)
print("CHECK dishes skipped (too few photos):", skipped)

from mediapipe_model_maker import image_classifier  # noqa: E402

data = image_classifier.Dataset.from_folder(str(WORK / "train"))
train, valid = data.split(0.9)
test = image_classifier.Dataset.from_folder(str(WORK / "test"))
print("Train", train.size, "valid", valid.size, "test", test.size, "dishes", len(train.label_names))
options = image_classifier.ImageClassifierOptions(
    supported_model=image_classifier.SupportedModels.EFFICIENTNET_LITE2,
    # Fine-tune the whole network (not just the last layer): slower, much more accurate.
    hparams=image_classifier.HParams(
        export_dir=str(OUT), epochs=EPOCHS, batch_size=min(32, max(2, train.size // 2)),
        learning_rate=float(os.environ.get("LR", "0.001")), do_fine_tuning=True, shuffle=True,
    ),
    model_options=image_classifier.ModelOptions(dropout_rate=0.2),
)
model = image_classifier.ImageClassifier.create(train_data=train, validation_data=valid, options=options)
loss, acc = model.evaluate(test)
print(f"CHECK overall test accuracy: {acc:.3f}")
model.export_model("food_dish.tflite")
labels = list(train.label_names)
with open(OUT / "food_dish_labels.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "name"])
    for i, name in enumerate(labels):
        w.writerow([i, name])

# Per-dish accuracy with the exported phone model, the way the app runs it.
import tensorflow as tf  # noqa: E402

interp = tf.lite.Interpreter(model_path=str(OUT / "food_dish.tflite"))
interp.allocate_tensors()
inp, out = interp.get_input_details()[0], interp.get_output_details()[0]
print("CHECK input:", inp["shape"].tolist(), inp["dtype"].__name__, "output:", out["shape"].tolist())
size = (int(inp["shape"][2]), int(inp["shape"][1]))
stats = {}
for d in sorted((WORK / "test").iterdir()):
    for f in d.glob("*.jpg"):
        x = np.asarray(Image.open(f).convert("RGB").resize(size, Image.BILINEAR), dtype=np.float32) / 255.0
        interp.set_tensor(inp["index"], x[None].astype(inp["dtype"]))
        interp.invoke()
        p = interp.get_tensor(out["index"])[0]
        top3 = [labels[i] for i in np.argsort(-p)[:3]]
        s = stats.setdefault(d.name, [0, 0, 0])
        s[0] += 1
        s[1] += top3[0] == d.name
        s[2] += d.name in top3
n = sum(s[0] for s in stats.values())
print(f"CHECK phone model: top-1 {sum(s[1] for s in stats.values()) / n:.3f}, top-3 {sum(s[2] for s in stats.values()) / n:.3f} on {n} test photos")
with open(OUT / "food_dish_accuracy.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["dish", "test photos", "top1", "top3"])
    for k, (t, a, b) in sorted(stats.items(), key=lambda kv: kv[1][1] / kv[1][0]):
        w.writerow([k, t, round(a / t, 2), round(b / t, 2)])
        print(f"  {k:18s} {t:3d}  top1 {a / t:.2f}  top3 {b / t:.2f}")
