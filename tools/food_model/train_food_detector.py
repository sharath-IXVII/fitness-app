"""Train a phone-sized FOOD DETECTOR for FittArc: it finds each dish on a
plate and draws an exact box around it (the food snap then shows boxes that
fit each dish). Free: Google Colab + MediaPipe Model Maker (Apache-2.0).

Steps (click-by-click version in README.md next to this file):
  1. Colab: Runtime -> Change runtime type -> T4 GPU.
  2. Get a dataset with BOXES drawn around each food, in COCO format, split
     into train/ and valid/ folders (Roboflow: Export -> "COCO"). Check its
     licence allows commercial use.
  3. Upload it so you have /content/data/train/ and /content/data/valid/,
     each with images and an _annotations.coco.json (Roboflow's names work;
     labels.json also works).
  4. !pip install mediapipe-model-maker
     !python train_food_detector.py
  5. Download /content/out/food_detector.tflite and
     /content/out/food_detector_labels.csv, and the "CHECK" lines printed at
     the end.

What the app expects (lib/features/scan/tflite_food_detector.dart): outputs
boxes [1,N,4], classes [1,N], scores [1,N], count [1]. The script prints the
model's outputs at the end so we can confirm.
"""
import csv
import json
import os
import pathlib
import shutil

DATA = pathlib.Path(os.environ.get("DATA_DIR", "/content/data"))
OUT = pathlib.Path(os.environ.get("OUT_DIR", "/content/out"))
EPOCHS = int(os.environ.get("EPOCHS", "40"))
OUT.mkdir(parents=True, exist_ok=True)


def as_model_maker_folder(split: str) -> pathlib.Path:
    """Model Maker wants <dir>/images/*.jpg and <dir>/labels.json."""
    src = DATA / split
    dst = pathlib.Path("/content/mm") / split
    (dst / "images").mkdir(parents=True, exist_ok=True)
    ann = next((p for p in [src / "_annotations.coco.json", src / "labels.json"] if p.exists()), None)
    if ann is None:
        raise SystemExit(f"No COCO annotations found in {src}")
    coco = json.loads(ann.read_text())
    for img in coco["images"]:
        f = src / img["file_name"]
        if not f.exists():
            f = src / "images" / img["file_name"]
        img["file_name"] = pathlib.Path(img["file_name"]).name
        shutil.copy(f, dst / "images" / img["file_name"])
    # Roboflow adds a parent "food" category with id 0 that has no boxes: drop
    # categories nothing uses, so the app's labels stay clean.
    used = {a["category_id"] for a in coco["annotations"]}
    coco["categories"] = [c for c in coco["categories"] if c["id"] in used]
    (dst / "labels.json").write_text(json.dumps(coco))
    return dst


from mediapipe_model_maker import object_detector  # noqa: E402

train_dir = as_model_maker_folder("train")
valid_dir = as_model_maker_folder("valid")
train = object_detector.Dataset.from_coco_folder(str(train_dir), cache_dir="/content/cache/train")
valid = object_detector.Dataset.from_coco_folder(str(valid_dir), cache_dir="/content/cache/valid")
print("Train images:", train.size, " Valid images:", valid.size)
print("Dishes:", train.label_names)

options = object_detector.ObjectDetectorOptions(
    supported_model=getattr(object_detector.SupportedModels, os.environ.get("DET_MODEL", "MOBILENET_V2_I320")),
    hparams=object_detector.HParams(export_dir=str(OUT), epochs=EPOCHS, batch_size=16, learning_rate=0.3),
)
model = object_detector.ObjectDetector.create(train_data=train, validation_data=valid, options=options)
loss, coco_metrics = model.evaluate(valid, batch_size=4)
print("Final validation: loss", loss, " AP", coco_metrics.get("AP"), " AP50", coco_metrics.get("AP50"))

# Smaller and faster on phones, nearly as accurate.
model.restore_float_ckpt()
model.quantization_aware_training(
    train, valid, qat_hparams=object_detector.QATHParams(learning_rate=0.3, batch_size=16, epochs=min(2, EPOCHS))
)
model.export_model("food_detector.tflite")  # int8 from the quantization-aware training

# Labels in the app's format: "id,name", id = the class number the model outputs.
with open(OUT / "food_detector_labels.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "name"])
    for i, name in enumerate(train.label_names):
        w.writerow([i, name])

import tensorflow as tf  # noqa: E402

interp = tf.lite.Interpreter(model_path=str(OUT / "food_detector.tflite"))
print("CHECK input:", [(d["shape"].tolist(), d["dtype"].__name__) for d in interp.get_input_details()])
print("CHECK outputs:", [(d["name"], d["shape"].tolist()) for d in interp.get_output_details()])
print("Done. Download food_detector.tflite and food_detector_labels.csv from", OUT)

# The app decodes the raw SSD outputs itself: save the anchors (x, y, w, h,
# float32) from the model's metadata as food_detector_anchors.bin. Commit it to
# assets/models/ if the detector's input size or architecture changes.
import numpy as np  # noqa: E402
from mediapipe.tasks.metadata import metadata_schema_py_generated as M  # noqa: E402
from mediapipe.tasks.metadata import object_detector_metadata_schema_py_generated as O  # noqa: E402
from mediapipe.tasks.metadata import schema_py_generated as S  # noqa: E402

buf = (OUT / "food_detector.tflite").read_bytes()
tfl = S.Model.GetRootAsModel(buf, 0)
for i in range(tfl.MetadataLength()):
    md = tfl.Metadata(i)
    if md.Name().decode() != "TFLITE_METADATA":
        continue
    data = tfl.Buffers(md.Buffer()).DataAsNumpy().tobytes()
    sg = M.ModelMetadata.GetRootAsModelMetadata(data, 0).SubgraphMetadata(0)
    for j in range(sg.CustomMetadataLength()):
        od = O.ObjectDetectorOptions.GetRootAsObjectDetectorOptions(bytes(sg.CustomMetadata(j).DataAsNumpy()), 0)
        fa = od.SsdAnchorsOptions().FixedAnchorsSchema()
        a = np.array([[fa.Anchors(k).XCenter(), fa.Anchors(k).YCenter(), fa.Anchors(k).Width(), fa.Anchors(k).Height()]
                      for k in range(fa.AnchorsLength())], dtype="<f4")
        a.tofile(OUT / "food_detector_anchors.bin")
        print("CHECK anchors:", a.shape)
