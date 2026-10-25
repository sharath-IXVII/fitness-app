"""Train a small, phone-sized Indian-food classifier and export it for Fittarc.

Run it in Google Colab (free GPU): Runtime -> Change runtime type -> T4 GPU.
Not tested inside the Fittarc build; treat the first run as an experiment.

Steps (see README.md next to this file for the click-by-click version):
  1. Put the photos in /content/food/<dish name>/*.jpg  (one folder per dish).
  2. Run:  python train_indian_food_model.py
  3. Download food_indian.tflite and food_indian_labels.csv from /content/out/.

What the app expects (see lib/features/scan/tflite_food_model.dart):
  * input  [1, H, W, 3], float32, pixel values 0..1
  * output [1, N+1] scores, where class 0 is a never-used "background" slot
  * labels file: a header row, then "id,name" rows, ids starting at 1
"""
import csv
import os
import pathlib

import tensorflow as tf

DATA = pathlib.Path(os.environ.get("FOOD_DIR", "/content/food"))
OUT = pathlib.Path(os.environ.get("OUT_DIR", "/content/out"))
SIZE = int(os.environ.get("IMG_SIZE", "224"))
BATCH = 32
EPOCHS_HEAD = int(os.environ.get("EPOCHS_HEAD", "8"))
EPOCHS_FINE = int(os.environ.get("EPOCHS_FINE", "10"))

OUT.mkdir(parents=True, exist_ok=True)

train = tf.keras.utils.image_dataset_from_directory(
    DATA, validation_split=0.15, subset="training", seed=7, image_size=(SIZE, SIZE), batch_size=BATCH
)
val = tf.keras.utils.image_dataset_from_directory(
    DATA, validation_split=0.15, subset="validation", seed=7, image_size=(SIZE, SIZE), batch_size=BATCH
)
names = train.class_names
n = len(names)
print(f"{n} dishes:", names)

# Class 0 is the app's "background" slot, so real dishes are numbered 1..n.
shift = lambda x, y: (x, y + 1)
train = train.map(shift).prefetch(tf.data.AUTOTUNE)
val = val.map(shift).prefetch(tf.data.AUTOTUNE)

augment = tf.keras.Sequential(
    [
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.08),
        tf.keras.layers.RandomZoom(0.15),
        tf.keras.layers.RandomContrast(0.15),
    ]
)

base = tf.keras.applications.MobileNetV3Large(
    input_shape=(SIZE, SIZE, 3), include_top=False, weights="imagenet", include_preprocessing=True
)
base.trainable = False

# The app feeds pixels as 0..1; MobileNetV3 wants 0..255, so scale inside the model.
inputs = tf.keras.Input((SIZE, SIZE, 3))
x = tf.keras.layers.Rescaling(255.0)(inputs)
x = augment(x)
x = base(x)
x = tf.keras.layers.GlobalAveragePooling2D()(x)
x = tf.keras.layers.Dropout(0.25)(x)
outputs = tf.keras.layers.Dense(n + 1, activation="softmax")(x)
model = tf.keras.Model(inputs, outputs)

# The training data arrives as 0..255 (Keras' loader); scale it down to match the app.
down = lambda x, y: (x / 255.0, y)
train = train.map(down)
val = val.map(down)

model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(3, name="top3")],
)
model.fit(train, validation_data=val, epochs=EPOCHS_HEAD)

# Fine-tune the top of the backbone gently.
base.trainable = True
for layer in base.layers[:-40]:
    layer.trainable = False
model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-5),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy", tf.keras.metrics.SparseTopKCategoricalAccuracy(3, name="top3")],
)
model.fit(train, validation_data=val, epochs=EPOCHS_FINE)
print("Final validation:", dict(zip(model.metrics_names, model.evaluate(val))))

# Export for the phone: float16 weights keep the file small (about 6-8 MB).
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
(OUT / "food_indian.tflite").write_bytes(converter.convert())

with open(OUT / "food_indian_labels.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "name"])
    w.writerow([0, "background"])
    for i, name in enumerate(names, start=1):
        w.writerow([i, name.replace("_", " ").strip().lower()])
print("Done. Download the two files from", OUT)
