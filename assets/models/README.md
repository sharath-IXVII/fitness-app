The food-recognition model is not stored in git. The APK build downloads it
here (see .github/workflows/build-apk.yml):

- food_v1.tflite — Google AIY "Food V1" image classifier (TensorFlow Hub /
  Kaggle Models, Apache-2.0)
- food_labels.csv — its label map

To run food scanning locally, download both into this folder. Without them
the app still works; the scanner offers manual entry instead.
