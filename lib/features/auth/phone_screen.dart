import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import 'auth_providers.dart';
import 'domain/app_user.dart';
import 'otp_screen.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_success.dart';

class Country {
  const Country(this.name, this.flag, this.dial, this.digits);

  final String name;
  final String flag;
  final String dial;

  /// Expected national number length (used for validation).
  final int digits;
}

const countries = [
  Country('India', '🇮🇳', '+91', 10),
  Country('United States', '🇺🇸', '+1', 10),
  Country('United Kingdom', '🇬🇧', '+44', 10),
  Country('United Arab Emirates', '🇦🇪', '+971', 9),
  Country('Singapore', '🇸🇬', '+65', 8),
  Country('Australia', '🇦🇺', '+61', 9),
  Country('Canada', '🇨🇦', '+1', 10),
];

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, this.signUp = true});

  final bool signUp;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _number = TextEditingController();
  Country _country = countries.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  bool get _valid => _number.text.length == _country.digits;
  String get _e164 => '${_country.dial}${_number.text}';

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final country in countries)
              ListTile(
                leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                title: Text(country.name),
                trailing: Text(country.dial, style: Theme.of(c).textTheme.bodyMedium),
                onTap: () => Navigator.pop(c, country),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authServiceProvider).sendCode(_e164);
      if (!mounted) return;
      if (result.autoSignedIn != null) {
        showAuthSuccess(context, name: result.autoSignedIn!.name);
        ref.read(authProvider.notifier).signedIn(result.autoSignedIn!);
        return;
      }
      context.push(
        Routes.authOtp,
        extra: OtpArgs(phone: _e164, verificationId: result.verificationId!, resendToken: result.resendToken),
      );
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: widget.signUp ? 'Your phone number' : 'Log in with phone',
      subtitle: "We'll text you a 6-digit code to verify it's you. Standard SMS rates may apply.",
      footer: GradientButton(label: _busy ? 'Sending…' : 'Send code', onPressed: _valid && !_busy ? _send : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _pickCountry,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Text(_country.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(_country.dial, style: text.titleMedium),
                      const Icon(Icons.expand_more_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _number,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_country.digits),
                  ],
                  style: text.titleMedium?.copyWith(letterSpacing: 1),
                  decoration: InputDecoration(hintText: 'Phone number', errorText: _error),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _valid ? _send() : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Your number is only used to sign you in.', style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
