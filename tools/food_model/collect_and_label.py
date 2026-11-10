"""Builds a food-detection dataset with no hand labelling.

1. Photos: Wikimedia Commons (only free licences: CC0, public domain, CC BY,
   CC BY-SA; every photo's author and licence go into credits.csv) and the
   CC0 Hugging Face dataset bharat-raghunathan/indian-foods-dataset.
2. Boxes: the open-source OWLv2 model (Apache 2.0) finds each dish by name.
3. Output: COCO folders DATA_DIR/train and DATA_DIR/valid, ready for
   train_food_detector.py.
"""

import csv
import io
import json
import os
import pathlib
import random
import re
import time

import requests
import torch
from PIL import Image
from transformers import Owlv2ForObjectDetection, Owlv2Processor

DATA = pathlib.Path(os.environ.get("DATA_DIR", "/content/data"))
PER_DISH = int(os.environ.get("PER_DISH", "40"))
HF_PER_CLASS = int(os.environ.get("HF_PER_CLASS", "30"))
UA = {"User-Agent": "FoodDatasetBuilder/1.0 (https://github.com/sharath-IXVII; dataset script) python-requests"}


def get(url, **kw):
    """GET with polite retries: Wikimedia answers 429 when we go too fast."""
    for attempt in range(6):
        try:
            r = requests.get(url, headers=UA, timeout=60, **kw)
            if r.status_code == 200:
                return r
            print("http", r.status_code, "waiting", flush=True)
        except requests.RequestException as e:
            print("net", e)
        time.sleep(5 * 2 ** attempt)
    return None

# label in the app -> (what OWLv2 is asked to find, Commons searches)
DISHES = {
    "roti": ("a round roti flatbread", ["roti chapati", "chapati bread", "phulka"]),
    "white rice": ("a mound of white rice", ["steamed rice India", "rice thali"]),
    "dal": ("a bowl of yellow dal lentil curry", ["dal tadka", "dal fry", "lentil dal"]),
    "sabzi": ("a vegetable sabzi curry", ["sabzi", "aloo sabzi", "bhindi masala", "mixed vegetable curry India"]),
    "curd": ("a bowl of white curd yogurt", ["dahi curd", "raita"]),
    "salad": ("sliced salad vegetables", ["kachumber salad", "Indian salad onion cucumber"]),
    "gulab jamun": ("a gulab jamun sweet ball", ["gulab jamun"]),
    "halwa": ("orange carrot halwa", ["gajar halwa", "halwa sweet"]),
    "jalebi": ("orange jalebi", ["jalebi"]),
    "idli": ("a white idli", ["idli"]),
    "dosa": ("a dosa crepe", ["dosa", "masala dosa"]),
    "sambar": ("a bowl of sambar", ["sambar"]),
    "poha": ("a plate of poha", ["poha"]),
    "upma": ("a plate of upma", ["upma"]),
    "biryani": ("a plate of biryani", ["biryani"]),
    "chole": ("chickpea chole curry", ["chole", "chana masala"]),
    "rajma": ("red kidney bean rajma curry", ["rajma"]),
    "paratha": ("a paratha flatbread", ["paratha", "aloo paratha"]),
    "paneer curry": ("paneer curry", ["paneer butter masala", "palak paneer", "kadai paneer"]),
    "chicken curry": ("chicken curry", ["chicken curry India", "butter chicken"]),
    "samosa": ("a samosa", ["samosa"]),
    "pakora": ("fried pakora fritters", ["pakora", "bhaji fritter"]),
    "dhokla": ("yellow dhokla pieces", ["dhokla"]),
}
THALI_SEARCHES = ["thali", "Indian thali", "South Indian meal banana leaf", "Gujarati thali", "North Indian thali", "Indian lunch plate"]
# CC0 Hugging Face classes we can use, with the app label.
HF_CLASSES = {"biryani": "biryani", "dal": "dal", "dhokla": "dhokla", "dosa": "dosa", "jalebi": "jalebi",
              "pakora": "pakora", "paneer": "paneer curry", "cholebhature": "chole", "naan": "roti"}
FREE = re.compile(r"^(cc0|public domain|pd|cc by(-sa)? [0-9.]+)", re.I)

LABELS = list(DISHES)
IMG = DATA / "all"
IMG.mkdir(parents=True, exist_ok=True)
items = []  # (file, hint label or None)
credits = []


def commons(query: str, limit: int):
    r = get("https://commons.wikimedia.org/w/api.php", params={
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6,
        "gsrsearch": f"{query} filetype:bitmap", "gsrlimit": limit, "prop": "imageinfo",
        "iiprop": "url|extmetadata", "iiurlwidth": 800})
    if r is None:
        return
    try:
        data = r.json()
    except ValueError:
        return
    for p in (data.get("query", {}).get("pages", {}) or {}).values():  # noqa
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata", {})
        lic = meta.get("LicenseShortName", {}).get("value", "")
        if not FREE.match(lic.strip()) or "nc" in lic.lower() or "nd" in lic.lower():
            continue
        artist = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
        yield ii.get("thumburl") or ii.get("url"), p.get("title"), lic, artist, ii.get("descriptionurl")


def save(url: str, name: str) -> pathlib.Path | None:
    try:
        r = get(url)
        if r is None:
            return None
        b = r.content
        im = Image.open(io.BytesIO(b)).convert("RGB")
        if min(im.size) < 200:
            return None
        im.thumbnail((800, 800))
        f = IMG / name
        im.save(f, quality=90)
        return f
    except Exception as e:  # noqa: BLE001
        print("skip", url, e)
        return None


seen = set()
n = 0
for label, (_, searches) in DISHES.items():
    got = 0
    for q in searches:
        for url, title, lic, artist, page in commons(q, 50):
            if got >= PER_DISH or title in seen:
                continue
            seen.add(title)
            f = save(url, f"c{n:05d}.jpg")
            time.sleep(1.0)
            if f:
                n += 1
                got += 1
                items.append((f.name, label))
                credits.append([f.name, title, artist, lic, page])
    print(label, "commons photos:", got)
for q in THALI_SEARCHES:
    for url, title, lic, artist, page in commons(q, 50):
        if title in seen:
            continue
        seen.add(title)
        f = save(url, f"c{n:05d}.jpg")
        time.sleep(1.0)
        if f:
            n += 1
            items.append((f.name, None))
            credits.append([f.name, title, artist, lic, page])
print("commons total:", n)

# CC0 Hugging Face photos.
from datasets import load_dataset  # noqa: E402

ds = load_dataset("bharat-raghunathan/indian-foods-dataset", split="train")
names = ds.features["label"].names
count = {}
for row in ds.shuffle(seed=1):
    cls = names[row["label"]]
    if cls not in HF_CLASSES or count.get(cls, 0) >= HF_PER_CLASS:
        continue
    count[cls] = count.get(cls, 0) + 1
    name = f"h{len(items):05d}.jpg"
    row["image"].convert("RGB").save(IMG / name, quality=90)
    items.append((name, HF_CLASSES[cls]))
    credits.append([name, "bharat-raghunathan/indian-foods-dataset", "", "CC0-1.0", "https://huggingface.co/datasets/bharat-raghunathan/indian-foods-dataset"])
print("hf total:", sum(count.values()))

with open(DATA / "credits.csv", "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["file", "source", "author", "licence", "page"])
    w.writerows(credits)

# Boxes with OWLv2.
torch.set_num_threads(os.cpu_count() or 4)
proc = Owlv2Processor.from_pretrained("google/owlv2-base-patch16-ensemble")
model = Owlv2ForObjectDetection.from_pretrained("google/owlv2-base-patch16-ensemble").eval()
queries = [DISHES[l][0] for l in LABELS]


def iou(a, b):
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    u = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / u if u else 0


labelled = []
t0 = time.time()
for i, (name, hint) in enumerate(items):
    im = Image.open(IMG / name)
    w, h = im.size
    with torch.no_grad():
        inp = proc(text=[queries], images=im, return_tensors="pt")
        out = model(**inp)
    side = max(w, h)  # OWLv2 pads to a square
    res = proc.post_process_object_detection(out, threshold=0.08, target_sizes=torch.tensor([[side, side]]))[0]
    cand = []
    for s, l, b in zip(res["scores"].tolist(), res["labels"].tolist(), res["boxes"].tolist()):
        lab = LABELS[l]
        need = 0.12 if lab == hint else 0.3  # trust the photo's own dish more
        if s < need:
            continue
        b = [max(0, b[0]), max(0, b[1]), min(w, b[2]), min(h, b[3])]
        if (b[2] - b[0]) < 0.06 * w or (b[3] - b[1]) < 0.06 * h or (b[2] - b[0]) * (b[3] - b[1]) > 0.95 * w * h:
            continue
        cand.append((s, lab, b))
    cand.sort(key=lambda c: -c[0])
    keep = []
    for c in cand:
        if all(iou(c[2], k[2]) < 0.5 for k in keep):
            keep.append(c)
    if hint and not any(k[1] == hint for k in keep):
        keep = []  # the dish it's meant to show wasn't found: skip the photo
    if keep:
        labelled.append((name, w, h, keep[:8]))
    if i % 50 == 0:
        print(f"{i}/{len(items)} labelled={len(labelled)} {time.time() - t0:.0f}s", flush=True)

random.seed(7)
random.shuffle(labelled)
cut = max(1, len(labelled) // 8)
cats = [{"id": i + 1, "name": l} for i, l in enumerate(LABELS)]
cid = {c["name"]: c["id"] for c in cats}
counts = {}
for split, rows in [("valid", labelled[:cut]), ("train", labelled[cut:])]:
    d = DATA / split
    (d / "images").mkdir(parents=True, exist_ok=True)
    coco = {"images": [], "annotations": [], "categories": cats}
    for j, (name, w, h, boxes) in enumerate(rows):
        (d / "images" / name).write_bytes((IMG / name).read_bytes())
        coco["images"].append({"id": j, "file_name": name, "width": w, "height": h})
        for s, lab, b in boxes:
            counts[lab] = counts.get(lab, 0) + 1
            coco["annotations"].append({"id": len(coco["annotations"]), "image_id": j, "category_id": cid[lab],
                                        "bbox": [b[0], b[1], b[2] - b[0], b[3] - b[1]],
                                        "area": (b[2] - b[0]) * (b[3] - b[1]), "iscrowd": 0})
    (d / "labels.json").write_text(json.dumps(coco))
print("boxes per dish:", json.dumps(counts, indent=1))
print("CHECK images train/valid:", len(labelled) - cut, cut)
