import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../profile/profile_providers.dart';
import '../scan/scan_screen.dart' show pickImageProvider;
import 'wellness.dart';

Widget _page(String title, Widget body) => PageBackground(
  child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
    body: SafeArea(child: body),
  ),
);

// ===================================================================== report

/// What a finished test shows: the result, what it means, how exact it is,
/// earlier results and tips.
class TestReport {
  const TestReport({
    required this.title,
    required this.value,
    required this.unit,
    required this.summary,
    required this.meaning,
    required this.accuracy,
    required this.tips,
    required this.kind,
    this.format,
  });

  final String title;
  final String value;
  final String unit;
  final String summary;
  final String meaning;
  final String accuracy;
  final List<String> tips;

  /// Wellness kind, for the history.
  final String kind;

  /// How a stored value is shown in the history.
  final String Function(WellnessEntry e)? format;
}

class TestReportScreen extends ConsumerWidget {
  const TestReportScreen({super.key, required this.report, required this.retake});

  final TestReport report;
  final Widget Function() retake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final history = [
      for (final e in ref.watch(wellnessProvider).reversed)
        if (e.kind == report.kind) e,
    ].take(6).toList();
    Widget section(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(body, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return _page(
      tr('Your report'),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [AppColors.primary, Color.lerp(AppColors.primary, Colors.black, 0.3)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title.toUpperCase(),
                  style: text.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      report.value,
                      style: text.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Text(report.unit, style: text.titleMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(report.summary, style: text.bodyMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy, h:mm a').format(clock.now()),
                  style: text.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          section(Icons.insights_rounded, tr('What it means'), report.meaning),
          section(Icons.straighten_rounded, tr('How exact is this?'), report.accuracy),
          if (report.tips.isNotEmpty)
            section(Icons.tips_and_updates_outlined, tr('Tips'), report.tips.map((t) => '• $t').join('\n')),
          if (history.length > 1) ...[
            const SizedBox(height: 18),
            Text(tr('Your results'), style: text.titleMedium),
            const SizedBox(height: 6),
            for (final e in history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(report.format?.call(e) ?? '${e.value}'),
                trailing: Text(DateFormat('d MMM').format(e.at), style: text.bodySmall),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            tr('A general fitness reference for your own tracking, not a medical assessment.'),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => retake())),
                  child: Text(tr('Test again')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Done'))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showReport(BuildContext context, TestReport r, Widget Function() retake) => Navigator.of(context).pushReplacement(
  MaterialPageRoute<void>(
    builder: (_) => TestReportScreen(report: r, retake: retake),
  ),
);

// ===================================================================== height

/// Height in cm from four marks on a photo, using a reference of known
/// length beside the person at the same distance from the camera.
double heightFromMarks({
  required double refTop,
  required double refBottom,
  required double head,
  required double feet,
  required double refCm,
}) {
  final ref = (refBottom - refTop).abs();
  if (ref <= 0) return 0;
  return (feet - head).abs() / ref * refCm;
}

/// About how far off the result may be, in cm, if each mark is off by
/// [markPx] pixels (plus a little for the camera angle).
double heightError({required double refPx, required double personPx, required double heightCm, double markPx = 3}) {
  if (refPx <= 0 || personPx <= 0) return heightCm;
  final rel = math.sqrt(math.pow(2 * markPx / refPx, 2) + math.pow(2 * markPx / personPx, 2)) + 0.01;
  return heightCm * rel;
}

/// Height without a measuring tape: a photo with an A4 sheet on the wall.
class HeightTestScreen extends ConsumerStatefulWidget {
  const HeightTestScreen({super.key});

  @override
  ConsumerState<HeightTestScreen> createState() => _HeightTestScreenState();
}

class _HeightTestScreenState extends ConsumerState<HeightTestScreen> {
  Uint8List? _photo;
  Size? _size;

  /// Marks as fractions of the shown photo's height.
  final _marks = <double>[0.30, 0.42, 0.08, 0.92];
  static const _names = ['Top of the paper', 'Bottom of the paper', 'Top of the head', 'Floor at the heels'];
  static const _colors = [Color(0xFF2E7DD7), Color(0xFF2E7DD7), Color(0xFFE0762A), Color(0xFFE0762A)];
  double _refCm = 29.7;

  Future<void> _pick(ImageSource source) async {
    final p = await ref.read(pickImageProvider)(source);
    if (p == null || !mounted) return;
    final img = await decodeImageFromList(p.bytes);
    setState(() {
      _photo = p.bytes;
      _size = Size(img.width.toDouble(), img.height.toDouble());
    });
  }

  void _finish() {
    final h = _size!.height;
    final cm = heightFromMarks(
      refTop: _marks[0],
      refBottom: _marks[1],
      head: _marks[2],
      feet: _marks[3],
      refCm: _refCm,
    );
    final err = heightError(
      refPx: (_marks[1] - _marks[0]).abs() * h,
      personPx: (_marks[3] - _marks[2]).abs() * h,
      heightCm: cm,
    );
    if (cm < 50 || cm > 250) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('That doesn\'t look right. Check the four lines and try again.'))));
      return;
    }
    ref.read(wellnessProvider.notifier).add('height', (cm * 10).round(), extra: (err * 10).round());
    final profile = ref.read(profileProvider);
    _showReport(
      context,
      TestReport(
        title: tr('Height'),
        value: cm.toStringAsFixed(1),
        unit: 'cm',
        summary: '± ${err.toStringAsFixed(1)} cm',
        meaning: profile == null
            ? tr('Use this as your height in the app to make calories and stride length more accurate.')
            : '${tr('Your profile says')} ${profile.heightCm.toStringAsFixed(0)} cm. ${tr('If this is closer, update it in your profile for more accurate calories and stride length.')}',
        accuracy: tr(
          'Usually within 1–3 cm when the paper is flat on the wall at your height, you stand straight against the same wall, and the phone is held level about 2–3 m away. Leaning, shoes or a tilted phone add error.',
        ),
        tips: [
          tr('Take off your shoes and stand with your heels against the wall.'),
          tr('Hold the phone level, at about chest height.'),
          tr('Measure twice and use the average.'),
        ],
        kind: 'height',
        format: (e) => '${(e.value / 10).toStringAsFixed(1)} cm',
      ),
      () => const HeightTestScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_photo == null) {
      return _page(
        tr('Measure height'),
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(tr('No tape needed: a sheet of A4 paper is your ruler.'), style: text.titleMedium),
            const SizedBox(height: 12),
            for (final (i, s) in [
              tr('Tape an A4 sheet (29.7 cm tall, standing upright) on a wall, around your chest height.'),
              tr('Stand barefoot with your heels, back and head against the wall, next to the paper.'),
              tr(
                'Ask someone to take a photo from 2–3 m away, phone held level, your whole body and the paper in the photo.',
              ),
              tr('Then move four lines: the top and bottom of the paper, the top of your head and the floor.'),
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primarySoft,
                      child: Text('${i + 1}', style: text.labelMedium),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: text.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            GradientButton(
              label: tr('Take photo'),
              icon: Icons.photo_camera_rounded,
              onPressed: () => _pick(ImageSource.camera),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(tr('Choose from gallery')),
            ),
          ],
        ),
      );
    }
    return _page(
      tr('Mark the lines'),
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              tr('Drag each line to its spot. Blue: the paper. Orange: head and floor.'),
              style: text.bodySmall,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final aspect = _size!.width / _size!.height;
                var w = c.maxWidth, h = w / aspect;
                if (h > c.maxHeight) {
                  h = c.maxHeight;
                  w = h * aspect;
                }
                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      children: [
                        Positioned.fill(child: Image.memory(_photo!, fit: BoxFit.fill)),
                        for (var i = 0; i < 4; i++)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _marks[i] * h - 18,
                            height: 36,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (d) =>
                                  setState(() => _marks[i] = (_marks[i] + d.delta.dy / h).clamp(0.0, 1.0)),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(height: 2, color: _colors[i]),
                                  Positioned(
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _colors[i],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tr(_names[i]),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(tr('Paper'), style: text.bodySmall),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('A4 · 29.7 cm'),
                  selected: _refCm == 29.7,
                  onSelected: (_) => setState(() => _refCm = 29.7),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('A4 sideways · 21 cm'),
                  selected: _refCm == 21.0,
                  onSelected: (_) => setState(() => _refCm = 21.0),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: GradientButton(label: tr('See my height'), icon: Icons.straighten_rounded, onPressed: _finish),
          ),
        ],
      ),
    );
  }
}

// ===================================================================== reaction

/// Reaction time: tap as soon as the screen turns green, five times.
class ReactionTestScreen extends ConsumerStatefulWidget {
  const ReactionTestScreen({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<ReactionTestScreen> createState() => _ReactionTestScreenState();
}

enum _RState { idle, waiting, go, early }

class _ReactionTestScreenState extends ConsumerState<ReactionTestScreen> {
  static const rounds = 5;
  late final _rng = widget.random ?? math.Random();
  final _times = <int>[];
  _RState _state = _RState.idle;
  Timer? _timer;
  DateTime? _shown;

  void _arm() {
    setState(() => _state = _RState.waiting);
    _timer = Timer(Duration(milliseconds: 1500 + _rng.nextInt(2500)), () {
      setState(() {
        _state = _RState.go;
        _shown = clock.now();
      });
    });
  }

  void _tap() {
    switch (_state) {
      case _RState.idle || _RState.early:
        _arm();
      case _RState.waiting:
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _state = _RState.early);
      case _RState.go:
        HapticFeedback.lightImpact();
        _times.add(clock.now().difference(_shown!).inMilliseconds);
        if (_times.length >= rounds) {
          _done();
        } else {
          _arm();
        }
    }
  }

  void _done() {
    final sorted = [..._times]..sort();
    final avg = (_times.reduce((a, b) => a + b) / _times.length).round();
    ref.read(wellnessProvider.notifier).add('reaction', avg, extra: sorted.first);
    final band = avg < 250
        ? tr('Quick. Faster than most people.')
        : avg < 350
        ? tr('Typical. Most people tap in 250–350 ms.')
        : tr('A bit slower than typical. Sleep, focus and practice all help.');
    _showReport(
      context,
      TestReport(
        title: tr('Reaction time'),
        value: '$avg',
        unit: 'ms',
        summary: '${tr('Best')}: ${sorted.first} ms · $rounds ${tr('taps')}',
        meaning: band,
        accuracy: tr(
          'Phone screens and touch add about 20–60 ms, so compare your results on the same phone. The average of five taps is steadier than one.',
        ),
        tips: [
          tr('Test at the same time of day to see trends.'),
          tr('Tiredness and screen brightness change the result.'),
        ],
        kind: 'reaction',
        format: (e) => '${e.value} ms (${tr('best')} ${e.extra} ms)',
      ),
      () => const ReactionTestScreen(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (color, label) = switch (_state) {
      _RState.idle => (AppColors.primary, tr('Tap to start')),
      _RState.waiting => (const Color(0xFFC0392B), tr('Wait for green…')),
      _RState.go => (const Color(0xFF2E8B57), tr('TAP!')),
      _RState.early => (const Color(0xFFD9A100), tr('Too soon! Tap to try again')),
    };
    return _page(
      tr('Reaction time'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            Text(tr('Tap the box the moment it turns green. Five rounds.'), style: text.bodyMedium),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => _tap(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28)),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: text.headlineSmall?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text('${_times.length} / $rounds', style: text.titleMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== balance

/// Phone movement while balancing (user acceleration, m/s²). Overridden in tests.
final balanceSensorProvider = Provider<Stream<(double, double, double)>>(
  (ref) => userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) => (e.x, e.y, e.z)),
);

/// Steadiness 0–100 from the root-mean-square sway in m/s².
int steadiness(double rmsSway) => (100 - rmsSway * 55).clamp(0, 100).round();

/// One-leg balance: hold the phone to your chest and stand on one leg.
class BalanceTestScreen extends ConsumerStatefulWidget {
  const BalanceTestScreen({super.key});

  @override
  ConsumerState<BalanceTestScreen> createState() => _BalanceTestScreenState();
}

class _BalanceTestScreenState extends ConsumerState<BalanceTestScreen> {
  static const limit = 60;
  StreamSubscription<(double, double, double)>? _sub;
  Timer? _timer;
  int _countdown = 0;
  double _secs = 0;
  double _sumSq = 0;
  int _n = 0;
  bool _running = false;

  void _start() {
    setState(() => _countdown = 3);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      HapticFeedback.selectionClick();
      if (_countdown > 1) {
        setState(() => _countdown--);
        return;
      }
      t.cancel();
      HapticFeedback.heavyImpact();
      setState(() {
        _countdown = 0;
        _running = true;
        _secs = 0;
        _sumSq = 0;
        _n = 0;
      });
      _sub = ref.read(balanceSensorProvider).listen((v) {
        _sumSq += v.$1 * v.$1 + v.$2 * v.$2 + v.$3 * v.$3;
        _n++;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() => _secs += 0.1);
        if (_secs >= limit) _stop();
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _sub?.cancel();
    if (!_running) return;
    _running = false;
    final held = _secs.round();
    final rms = _n == 0 ? 0.0 : math.sqrt(_sumSq / _n);
    final steady = steadiness(rms);
    ref.read(wellnessProvider.notifier).add('balance', held, extra: steady);
    _showReport(
      context,
      TestReport(
        title: tr('One-leg balance'),
        value: '$held',
        unit: tr('seconds'),
        summary: '${tr('Steadiness')}: $steady / 100',
        meaning: held >= 30
            ? tr('Strong balance. Many adults under 60 can hold 30 seconds or more.')
            : held >= 10
            ? tr('Fair balance. With practice most people reach 30 seconds.')
            : tr('Balance can improve quickly with a few minutes of practice a day.'),
        accuracy: tr(
          'Time is exact to about a tenth of a second. Steadiness comes from the phone\'s motion sensor held to your chest, so compare results taken the same way.',
        ),
        tips: [
          tr('Stand near a wall or chair for safety.'),
          tr('Fix your eyes on one point in front of you.'),
          tr('Test each leg and practise the weaker one.'),
        ],
        kind: 'balance',
        format: (e) => '${e.value} s · ${tr('steadiness')} ${e.extra}',
      ),
      () => const BalanceTestScreen(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _page(
      tr('One-leg balance'),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            tr(
              'Hold the phone flat against your chest. Stand on one leg and tap Stop (or put your foot down) when you lose balance. Up to 60 seconds.',
            ),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
                border: Border.all(color: AppColors.primary, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                _countdown > 0 ? '$_countdown' : (_running ? _secs.toStringAsFixed(1) : '0.0'),
                style: text.displayMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_running)
            GradientButton(label: tr('Stop'), icon: Icons.stop_rounded, onPressed: _stop)
          else if (_countdown == 0)
            GradientButton(label: tr('Start'), icon: Icons.accessibility_new_rounded, onPressed: _start),
          const SizedBox(height: 14),
          Text(tr('Stand near a wall or chair for safety.'), style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
