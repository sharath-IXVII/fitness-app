import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import 'auth_providers.dart';
import 'domain/app_user.dart';
import 'widgets/auth_scaffold.dart';

class OtpArgs {
  const OtpArgs({required this.phone, required this.verificationId, this.resendToken});

  final String phone;
  final String verificationId;
  final int? resendToken;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;
  static const _resendAfter = 30;

  final _code = TextEditingController();
  final _focus = FocusNode();
  late String _verificationId = widget.args.verificationId;
  late int? _resendToken = widget.args.resendToken;
  Timer? _timer;
  int _secondsLeft = _resendAfter;
  bool _busy = false;
  String? _error;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != _length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authServiceProvider).verifyCode(_verificationId, _code.text);
      HapticFeedback.mediumImpact();
      ref.read(authProvider.notifier).signedIn(user);
    } on AuthFailure catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = e.message;
        _shake++;
        _code.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final r = await ref.read(authServiceProvider).sendCode(widget.args.phone, resendToken: _resendToken);
      if (r.autoSignedIn != null) {
        ref.read(authProvider.notifier).signedIn(r.autoSignedIn!);
        return;
      }
      _verificationId = r.verificationId ?? _verificationId;
      _resendToken = r.resendToken;
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code sent')));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: 'Enter the code',
      subtitle: 'Sent to ${widget.args.phone}.',
      footer: GradientButton(
        label: _busy ? 'Verifying…' : 'Verify',
        onPressed: _code.text.length == _length && !_busy ? _verify : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One hidden field drives six display boxes, so paste and SMS
          // autofill work naturally.
          GestureDetector(
            onTap: _focus.requestFocus,
            child: Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _code,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    onChanged: (v) {
                      setState(() => _error = null);
                      if (v.length == _length) _verify();
                    },
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _length; i++) ...[
                      Expanded(child: _box(i)),
                      if (i < _length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ).animate(key: ValueKey(_shake), target: _shake == 0 ? 0 : 1).shakeX(hz: 5, amount: 6, duration: 350.ms),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text("Didn't get it?", style: text.bodyMedium),
              TextButton(
                onPressed: _secondsLeft > 0 ? null : _resend,
                child: Text(_secondsLeft > 0 ? 'Resend in ${_secondsLeft}s' : 'Resend code'),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Change number'),
          ),
        ],
      ),
    );
  }

  Widget _box(int i) {
    final value = _code.text;
    final filled = i < value.length;
    final active = i == value.length && _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _error != null
              ? AppColors.danger
              : active
              ? AppColors.primary
              : AppColors.stroke,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Text(filled ? value[i] : '', style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
