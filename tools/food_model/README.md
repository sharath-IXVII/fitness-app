# Training the Indian-food model (Google Colab, free)

Goal: a phone-sized model that knows everyday Indian dishes (roti, dal, dosa, paneer…),
to work alongside the built-in one. About 30 minutes, no coding.

1. Open https://colab.research.google.com → **New notebook**.
   **Runtime → Change runtime type → T4 GPU → Save.**
2. Get the photos. Any dataset that has **one folder per dish** works, for example the Kaggle
   "Indian Food Images" dataset (about 80 dishes). **Check its licence allows commercial use**
   (CC0 / CC-BY / similar), and tell me the licence. Upload and unzip it so you end up with
   `/content/food/<dish>/<photo>.jpg`.
   Also add your own phone photos of food you eat into the same folders. They help a lot.
3. Upload `train_indian_food_model.py` (the file in this folder) to Colab, then run in a cell:
   `!python train_indian_food_model.py`
4. When it ends, download `/content/out/food_indian.tflite` and `/content/out/food_indian_labels.csv`
   and send them to me together with the dataset name, its licence and the last "Final validation" line
   (accuracy and top3).

I'll then add the model next to the built-in one, map its dish names to the app's nutrition list,
and test it.


---

# Training the food DETECTOR (exact boxes on the food snap)

The model above names dishes. The detector also finds *where* each dish is, so the food snap draws a box
that fits each one. Same idea: Google Colab, free, about an hour, no coding.

1. Open https://colab.research.google.com → **New notebook** → **Runtime → Change runtime type → T4 GPU → Save**.
2. **Photos with boxes.** On https://universe.roboflow.com search "indian food detection" (or "thali").
   Pick one with many images and **check its licence allows commercial use** (for example CC BY 4.0).
   Click **Download dataset → Format: COCO → Download zip**. Add your own plate photos in Roboflow if you can:
   they help most.
3. In Colab, upload the zip and run in a cell:
   `!unzip -q dataset.zip -d /content/data`
   You should now have `/content/data/train/` and `/content/data/valid/`.
4. Upload `train_food_detector.py` (this folder), then run:
   `!pip install -q mediapipe-model-maker`
   `!python train_food_detector.py`
5. When it ends, download `/content/out/food_detector.tflite` and `/content/out/food_detector_labels.csv`.
6. In GitHub: **fitness-app → Releases → Draft a new release**, tag **`food-detector`**, attach the two files,
   **Publish**. The next build adds them to the app by itself; the scanner then uses the detector.
7. Send me the dataset name, its licence, and the lines starting with **"Final validation"** and **"CHECK"**.
