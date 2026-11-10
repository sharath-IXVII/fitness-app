"""Builds the food datasets with no hand labelling (two-step approach).

Step 1 data, "where is food": every dish on a photo gets a box (one class,
"food"), found by the open-source OWLv2 model (Apache 2.0).
Step 2 data, "which dish is it": each box is cut out and named. A photo found
by searching for a dish keeps the cut-out only if the open-source SigLIP model
(Apache 2.0) agrees it looks like that dish; on thali photos SigLIP names
each cut-out and only confident ones are kept.

Photos: Wikimedia Commons (free licences only; author and licence of every
photo go into credits.csv) and the CC0 Hugging Face dataset
bharat-raghunathan/indian-foods-dataset.

MODE=label (default): part PART of PARTS -> DATA_DIR/partK/
MODE=merge: combines the parts -> DATA_DIR/det/{train,valid} (COCO) and
DATA_DIR/cls/<food id>/*.jpg, plus credits.csv.
"""

import csv
import io
import json
import os
import pathlib
import random
import re
import shutil
import sys
import time

import requests
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from dishes import DISHES, HF_CLASSES, THALI_SEARCHES  # noqa: E402

DATA = pathlib.Path(os.environ.get("DATA_DIR", "/content/data"))
PER_DISH = int(os.environ.get("PER_DISH", "80"))
HF_PER_CLASS = int(os.environ.get("HF_PER_CLASS", "120"))
PART, PARTS = int(os.environ.get("PART", "0")), int(os.environ.get("PARTS", "1"))
MODE = os.environ.get("MODE", "label")
ONLY = [d for d in os.environ.get("ONLY", "").split(",") if d]  # quick test runs
UA = {"User-Agent": "FoodDatasetBuilder/1.0 (https://github.com/sharath-IXVII; dataset script) python-requests"}
FREE = re.compile(r"^(cc0|public domain|pd|cc by(-sa)? [0-9.]+)", re.I)
IDS = list(DISHES)
OUT = DATA / f"part{PART}"


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
        time.sleep(5 * 2**attempt)
    return None


def commons(query, limit=50):
    r = get("https://commons.wikimedia.org/w/api.php", params={
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6,
        "gsrsearch": f"{query} filetype:bitmap", "gsrlimit": limit, "prop": "imageinfo",
        "iiprop": "url|extmetadata", "iiurlwidth": 800})
    try:
        pages = (r.json().get("query", {}).get("pages", {}) or {}).values() if r else []
    except ValueError:
        pages = []
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata", {})
        lic = meta.get("LicenseShortName", {}).get("value", "").strip()
        if not FREE.match(lic) or "nc" in lic.lower() or "nd" in lic.lower():
            continue
        artist = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
        yield ii.get("thumburl") or ii.get("url"), p.get("title"), lic, artist, ii.get("descriptionurl")


def iou(a, b):
    x1, y1, x2, y2 = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    u = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / u if u else 0


# ---------------------------------------------------------------- merge
def merge():
    rows, creds = [], []
    for part in sorted(DATA.glob("part*")):
        if (part / "boxes.json").exists():
            for name, w, h, boxes in json.loads((part / "boxes.json").read_text()):
                rows.append((f"{part.name}/img/{name}", w, h, boxes))
        if (part / "credits.csv").exists():
            creds += list(csv.reader((part / "credits.csv").open()))[1:]
        for d in (part / "cls").glob("*"):
            dst = DATA / "cls" / d.name
            dst.mkdir(parents=True, exist_ok=True)
            for f in d.glob("*.jpg"):
                shutil.copy(f, dst / f"{part.name}_{f.name}")
    with open(DATA / "credits.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["file", "source", "author", "licence", "page"])
        w.writerows(creds)
    random.seed(7)
    random.shuffle(rows)
    cut = max(1, len(rows) // 8)
    for split, part in [("valid", rows[:cut]), ("train", rows[cut:])]:
        d = DATA / "det" / split
        (d / "images").mkdir(parents=True, exist_ok=True)
        coco = {"images": [], "annotations": [], "categories": [{"id": 1, "name": "food"}]}
        for j, (name, w, h, boxes) in enumerate(part):
            flat = name.replace("/", "_")
            shutil.copy(DATA / name, d / "images" / flat)
            coco["images"].append({"id": j, "file_name": flat, "width": w, "height": h})
            for b in boxes:
                coco["annotations"].append({"id": len(coco["annotations"]), "image_id": j, "category_id": 1,
                                            "bbox": [b[0], b[1], b[2] - b[0], b[3] - b[1]],
                                            "area": (b[2] - b[0]) * (b[3] - b[1]), "iscrowd": 0})
        (d / "labels.json").write_text(json.dumps(coco))
    counts = {d.name: len(list(d.glob("*.jpg"))) for d in (DATA / "cls").glob("*")}
    print("CHECK detector photos train/valid:", len(rows) - cut, cut)
    print("CHECK dish photos per dish:", json.dumps(dict(sorted(counts.items(), key=lambda x: x[1]))))
    print("CHECK dishes with fewer than 15 photos:", [i for i in IDS if counts.get(i, 0) < 15])


if MODE == "merge":
    merge()
    raise SystemExit(0)

# ---------------------------------------------------------------- collect
(OUT / "img").mkdir(parents=True, exist_ok=True)
items, credits, seen = [], [], set()  # items: (file, food id or None)


def keep_photo(url, title, lic, artist, page, hint):
    if title in seen:
        return False
    seen.add(title)
    r = get(url)
    time.sleep(1.0)
    if r is None:
        return False
    try:
        im = Image.open(io.BytesIO(r.content)).convert("RGB")
    except Exception:  # noqa: BLE001
        return False
    if min(im.size) < 200:
        return False
    im.thumbnail((800, 800))
    name = f"c{len(items):05d}.jpg"
    im.save(OUT / "img" / name, quality=90)
    items.append((name, hint))
    credits.append([f"part{PART}/img/{name}", title, artist, lic, page])
    return True


mine = [d for k, d in enumerate(IDS) if k % PARTS == PART and (not ONLY or d in ONLY)]
for dish in mine:
    got = 0
    for q in DISHES[dish][1]:
        for hit in commons(q):
            if got >= PER_DISH:
                break
            got += keep_photo(*hit, dish)
    print(dish, "photos:", got, flush=True)
if PART == 0 and not ONLY:
    for q in THALI_SEARCHES:
        for hit in commons(q):
            keep_photo(*hit, None)
    from datasets import load_dataset

    ds = load_dataset("bharat-raghunathan/indian-foods-dataset", split="train").shuffle(seed=1)
    names = ds.features["label"].names
    count = {}
    for row in ds:
        cls = names[row["label"]]
        if cls not in HF_CLASSES or count.get(cls, 0) >= HF_PER_CLASS:
            continue
        count[cls] = count.get(cls, 0) + 1
        name = f"h{len(items):05d}.jpg"
        row["image"].convert("RGB").save(OUT / "img" / name, quality=90)
        items.append((name, HF_CLASSES[cls]))
        credits.append([f"part{PART}/img/{name}", "bharat-raghunathan/indian-foods-dataset", "", "CC0-1.0",
                        "https://huggingface.co/datasets/bharat-raghunathan/indian-foods-dataset"])
print("photos:", len(items), flush=True)
with open(OUT / "credits.csv", "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["file", "source", "author", "licence", "page"])
    w.writerows(credits)

# ---------------------------------------------------------------- label
import torch  # noqa: E402
from transformers import AutoModel, AutoProcessor, Owlv2ForObjectDetection, Owlv2Processor  # noqa: E402

torch.set_num_threads(os.cpu_count() or 4)
owl_p = Owlv2Processor.from_pretrained("google/owlv2-base-patch16-ensemble")
owl = Owlv2ForObjectDetection.from_pretrained("google/owlv2-base-patch16-ensemble").eval()
sig_p = AutoProcessor.from_pretrained("google/siglip-base-patch16-224")
sig = AutoModel.from_pretrained("google/siglip-base-patch16-224").eval()
FOOD_Q = ["a serving of food", "a bowl of curry", "a flatbread", "a sweet dessert", "a pile of rice",
          "a fried snack", "a piece of fruit", "a glass of drink"]
post = getattr(owl_p, "post_process_grounded_object_detection", None) or owl_p.post_process_object_detection
with torch.no_grad():
    te = sig.get_text_features(**sig_p(text=[f"a photo of {DISHES[d][0]}, Indian food" for d in IDS],
                                       padding="max_length", return_tensors="pt"))
    te = te / te.norm(dim=-1, keepdim=True)


def food_boxes(im):
    w, h = im.size
    with torch.no_grad():
        out = owl(**owl_p(text=[FOOD_Q], images=im, return_tensors="pt"))
    side = max(w, h)  # OWLv2 pads to a square
    r = post(out, threshold=0.12, target_sizes=torch.tensor([[side, side]]))[0]
    cand = []
    for s, b in sorted(zip(r["scores"].tolist(), r["boxes"].tolist()), key=lambda x: -x[0]):
        b = [max(0, b[0]), max(0, b[1]), min(w, b[2]), min(h, b[3])]
        bw, bh = b[2] - b[0], b[3] - b[1]
        if bw < 0.08 * w or bh < 0.08 * h or bw * bh > 0.9 * w * h:
            continue
        if all(iou(b, c) < 0.4 for c in cand):
            cand.append(b)
    return cand[:10]


def name_crops(crops):
    with torch.no_grad():
        ie = sig.get_image_features(**sig_p(images=crops, return_tensors="pt"))
        ie = ie / ie.norm(dim=-1, keepdim=True)
    return (ie @ te.T * 100).softmax(dim=-1)  # rows: crops, cols: dishes


boxes_out, kept, t0 = [], 0, time.time()
for i, (name, hint) in enumerate(items):
    im = Image.open(OUT / "img" / name).convert("RGB")
    w, h = im.size
    boxes = food_boxes(im)
    if boxes:
        boxes_out.append((name, w, h, [[round(v, 1) for v in b] for b in boxes]))
    crops = [im.crop(tuple(int(v) for v in b)) for b in boxes]
    if hint:
        crops.append(im)  # single-dish photos: the whole photo counts too
    if not crops:
        continue
    probs = name_crops(crops)
    for c, p in zip(crops, probs):
        top = p.topk(5)
        top_ids = [IDS[k] for k in top.indices.tolist()]
        if hint:
            ok = hint in top_ids
            dish = hint
        else:
            ok = top.values[0].item() >= 0.6
            dish = top_ids[0]
        if ok:
            d = OUT / "cls" / dish
            d.mkdir(parents=True, exist_ok=True)
            c.save(d / f"{name[:-4]}_{len(list(d.iterdir()))}.jpg", quality=90)
            kept += 1
            if hint:
                break  # one good cut-out per searched photo
    if i % 25 == 0:
        print(f"{i}/{len(items)} boxed={len(boxes_out)} dish crops={kept} {time.time() - t0:.0f}s", flush=True)

(OUT / "boxes.json").write_text(json.dumps(boxes_out))
print("CHECK part", PART, "photos", len(items), "boxed", len(boxes_out), "dish crops", kept)
