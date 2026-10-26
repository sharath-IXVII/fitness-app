import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../diet/widgets/sheet_frame.dart';
import '../domain/health.dart';
import '../health_providers.dart';

/// Records one reading. Returns the saved reading, or null if closed.
class AddReadingSheet extends ConsumerStatefulWidget {
  const AddReadingSheet({super.key, required this.kind});

  final ReadingKind kind;

  @override
  ConsumerState<AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends ConsumerState<AddReadingSheet> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _pulse = TextEditingController();
  GlucoseContext _context = GlucoseContext.fasting;
  late DateTime _at = clock.now();
  String? _error;

  bool get _bp => widget.kind == ReadingKind.bloodPressure;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int? _num(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: clock.now().subtract(const Duration(days: 365)),
      lastDate: clock.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _at = picked.isAfter(clock.now()) ? clock.now() : picked);
  }

  void _save() {
    HealthReading r;
    if (_bp) {
      final s = _num(_a), d = _num(_b), p = _num(_pulse);
      if (s == null || d == null) return setState(() => _error = 'Enter both numbers, top and bottom.');
      if (!Ranges.ok(s, Ranges.systolic) || !Ranges.ok(d, Ranges.diastolic)) {
        return setState(() => _error = 'Those numbers look off. Top should be 70 to 250 and bottom 40 to 150. Check the screen.');
      }
      if (s <= d) return setState(() => _error = 'The top number must be higher than the bottom one.');
      if (p != null && !Ranges.ok(p, Ranges.pulse)) return setState(() => _error = 'Pulse should be 30 to 220.');
      r = HealthReading.bloodPressure(at: _at, systolic: s, diastolic: d, pulse: p);
    } else {
      final v = _num(_a);
      final range = switch (widget.kind) {
        ReadingKind.glucose => Ranges.glucose,
        ReadingKind.pulse => Ranges.pulse,
        _ => Ranges.oxygen,
      };
      if (v == null) return setState(() => _error = 'Enter the number shown on your device.');
      if (!Ranges.ok(v, range)) {
        return setState(() => _error = 'That looks off. ${widget.kind.label} should be ${range.$1} to ${range.$2}.');
      }
      r = HealthReading.single(
        kind: widget.kind,
        at: _at,
        value: v,
        context: widget.kind == ReadingKind.glucose ? _context : null,
      );
    }
    ref.read(healthLogProvider.notifier).add(r);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(r);
  }

  Widget _field(TextEditingController c, String label, {String? hint}) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.headlineMedium,
    decoration: InputDecoration(labelText: label, hintText: hint),
    onChanged: (_) => setState(() => _error = null),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final k = widget.kind;
    return SheetFrame(
      title: 'Add ${k.label.toLowerCase()}',
      footer: GradientButton(label: 'Save reading', icon: Icons.check_rounded, onPressed: _save),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        children: [
          Text(
            _bp
                ? 'Type exactly what your blood pressure monitor shows. Sit still for 5 minutes first, with your arm '
                      'resting at heart level.'
                : 'Type exactly what your device shows.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_bp)
            Row(
              children: [
                Expanded(child: _field(_a, 'Top (systolic)', hint: '120')),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('/', style: text.headlineMedium)),
                Expanded(child: _field(_b, 'Bottom (diastolic)', hint: '80')),
              ],
            )
          else
            _field(_a, '${k.label} (${k.unit})'),
          if (_bp) ...[
            const SizedBox(height: 12),
            _field(_pulse, 'Pulse (optional, bpm)'),
          ],
          if (k == ReadingKind.glucose) ...[
            const SizedBox(height: 16),
            Text('When did you measure?', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in GlucoseContext.values)
                  ChoicePill(label: c.label, selected: _context == c, onTap: () => setState(() => _context = c)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                clock.now().difference(_at).inMinutes < 2 ? 'Now' : DateFormat('d MMM, h:mm a').format(_at),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}
