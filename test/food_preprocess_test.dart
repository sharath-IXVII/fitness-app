import 'package:fitalarm/features/scan/tflite_food_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('preprocess cuts the whole plate plus five regions at the model size', () {
    final photo = img.encodeJpg(img.Image(width: 400, height: 300));
    final views = TfliteFoodRecognizer.preprocess(photo, 192, 192);
    expect(views, hasLength(6));
    expect(views.every((v) => v.length == 192 * 192 * 3), isTrue);
  });
}
