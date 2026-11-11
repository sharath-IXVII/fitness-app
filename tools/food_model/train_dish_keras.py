"""Trains step 2, "which dish is it", with full fine-tuning (EfficientNetV2-B0,
ImageNet start) on DATA_DIR/cls/<food id>/*.jpg. Writes OUT_DIR/food_dish.tflite
(input: 224x224 RGB floats 0-1, output: probabilities), food_dish_labels.csv and
food_dish_accuracy.csv (every dish, on photos the model never trained on).
"""

import csv
import os
import pathlib
import random
import shutil

import time

import numpy as np
import tensorflow as tf
from PIL import Image

DATA = pathlib.Path(os.environ.get("DATA_DIR", "/content/data")) / "cls"
OUT = pathlib.Path(os.environ.get("OUT_DIR", "/content/out"))
EPOCHS = int(os.environ.get("EPOCHS", "15"))
MIN_PHOTOS = int(os.environ.get("MIN_PHOTOS", "8"))
# Stop fine-tuning in time to export (GitHub stops a job after ~6 hours).
BUDGET_MIN = float(os.environ.get("TIME_BUDGET_MIN", "250"))
SIZE = 224
WORK = pathlib.Path("/content/clswork")
OUT.mkdir(parents=True, exist_ok=True)

# Hold back 15% of each dish for an honest test.
random.seed(3)
shutil.rmtree(WORK, ignore_errors=True)
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

kw = dict(image_size=(SIZE, SIZE), batch_size=32, label_mode="int")
train = tf.keras.utils.image_dataset_from_directory(WORK / "train", validation_split=0.1, subset="training", seed=1, **kw)
valid = tf.keras.utils.image_dataset_from_directory(WORK / "train", validation_split=0.1, subset="validation", seed=1, **kw)
labels = train.class_names
n = len(labels)
print("dishes", n, "train batches", len(train), "valid batches", len(valid))

# Rarer dishes count more, so the model doesn't just learn the common ones.
counts = np.array([len(list((WORK / "train" / l).glob("*.jpg"))) for l in labels], dtype=float)
weights = {i: float(counts.mean() / c) for i, c in enumerate(counts)}

AUTOTUNE = tf.data.AUTOTUNE
augment = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal"),
    tf.keras.layers.RandomRotation(0.08),
    tf.keras.layers.RandomZoom((-0.2, 0.1)),
    tf.keras.layers.RandomTranslation(0.08, 0.08),
    tf.keras.layers.RandomContrast(0.2),
    tf.keras.layers.RandomBrightness(0.15, value_range=(0, 255)),
])
onehot = lambda x, y: (x, tf.one_hot(y, n))  # noqa: E731
train = train.map(lambda x, y: (augment(x, training=True), y), num_parallel_calls=AUTOTUNE).map(onehot).prefetch(AUTOTUNE)
valid = valid.map(onehot).prefetch(AUTOTUNE)

# The app feeds pixels as 0-1 floats; the network wants 0-255.
inputs = tf.keras.Input((SIZE, SIZE, 3))
base = tf.keras.applications.EfficientNetV2B0(include_top=False, weights="imagenet", pooling="avg")
x = base(tf.keras.layers.Rescaling(255.0)(inputs), training=False)
x = tf.keras.layers.Dropout(0.3)(x)
outputs = tf.keras.layers.Dense(n, activation="softmax")(x)
model = tf.keras.Model(inputs, outputs)
loss = tf.keras.losses.CategoricalCrossentropy(label_smoothing=0.1)

START = time.time()


class Budget(tf.keras.callbacks.Callback):
    def on_epoch_end(self, epoch, logs=None):
        mins = (time.time() - START) / 60
        per = mins / (epoch + 1 + 4)
        print(f"epoch {epoch + 1}: {mins:.0f} min so far", flush=True)
        if mins + per * 1.2 > BUDGET_MIN:
            print("CHECK stopping early to stay inside the time limit")
            self.model.stop_training = True


# Phase 1: train only the new top.
base.trainable = False
model.compile(tf.keras.optimizers.Adam(1e-3), loss, metrics=["accuracy"])
model.fit(train.map(lambda x, y: (x / 255.0, y)), validation_data=valid.map(lambda x, y: (x / 255.0, y)),
          epochs=4, class_weight=weights, verbose=2)

# Phase 2: fine-tune the whole network (batch-norm layers stay frozen).
base.trainable = True
for layer in base.layers:
    if isinstance(layer, tf.keras.layers.BatchNormalization):
        layer.trainable = False
steps = EPOCHS * len(train)
model.compile(tf.keras.optimizers.Adam(tf.keras.optimizers.schedules.CosineDecay(2e-4, steps)), loss, metrics=["accuracy"])
best = str(WORK / "best.keras")
model.fit(train.map(lambda x, y: (x / 255.0, y)), validation_data=valid.map(lambda x, y: (x / 255.0, y)),
          epochs=EPOCHS, class_weight=weights, verbose=2,
          callbacks=[tf.keras.callbacks.ModelCheckpoint(best, monitor="val_accuracy", save_best_only=True), Budget()])
model = tf.keras.models.load_model(best)

conv = tf.lite.TFLiteConverter.from_keras_model(model)
conv.optimizations = [tf.lite.Optimize.DEFAULT]  # smaller weights, float input and output
(OUT / "food_dish.tflite").write_bytes(conv.convert())
with open(OUT / "food_dish_labels.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "name"])
    for i, name in enumerate(labels):
        w.writerow([i, name])

# Per-dish accuracy with the exported phone model, fed the way the app feeds it.
interp = tf.lite.Interpreter(model_path=str(OUT / "food_dish.tflite"))
interp.allocate_tensors()
inp, out = interp.get_input_details()[0], interp.get_output_details()[0]
print("CHECK input:", inp["shape"].tolist(), inp["dtype"].__name__, "output:", out["shape"].tolist())
stats = {}
for d in sorted((WORK / "test").iterdir()):
    for f in d.glob("*.jpg"):
        x = np.asarray(Image.open(f).convert("RGB").resize((SIZE, SIZE), Image.BILINEAR), dtype=np.float32) / 255.0
        interp.set_tensor(inp["index"], x[None])
        interp.invoke()
        p = interp.get_tensor(out["index"])[0]
        top3 = [labels[i] for i in np.argsort(-p)[:3]]
        s = stats.setdefault(d.name, [0, 0, 0])
        s[0] += 1
        s[1] += top3[0] == d.name
        s[2] += d.name in top3
total = sum(s[0] for s in stats.values())
print(f"CHECK phone model: top-1 {sum(s[1] for s in stats.values()) / total:.3f}, "
      f"top-3 {sum(s[2] for s in stats.values()) / total:.3f} on {total} test photos")
with open(OUT / "food_dish_accuracy.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["dish", "test photos", "top1", "top3"])
    for k, (t, a, b) in sorted(stats.items(), key=lambda kv: kv[1][1] / kv[1][0]):
        w.writerow([k, t, round(a / t, 2), round(b / t, 2)])
        print(f"  {k:18s} {t:3d}  top1 {a / t:.2f}  top3 {b / t:.2f}")
