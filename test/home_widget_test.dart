import 'package:fitalarm/core/home_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget numbers are short and readable', () {
    final n = widgetNumbers(streak: 12, score: 80, steps: 12450, waterMl: 2250);
    expect(n.streak, '12');
    expect(n.score, '80');
    expect(n.steps, '👟 12,450');
    expect(n.water, '💧 2.3 L');
  });
}
