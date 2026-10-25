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
