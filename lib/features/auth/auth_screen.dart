import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/pressable.dart';
import 'auth_providers.dart';
import 'domain/app_user.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_success.dart';

/// First screen for signed-out users: choose Sign up or Log in, then phone
/// or Google. Both modes use the same methods — the first sign-in creates
/// the account — but the copy matches what the user came to do.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _signUp = true;
  bool _googleBusy = false;

  Future<void> _google() async {
    setState(() => _googleBusy = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null) {
        if (mounted) showAuthSuccess(context, name: user.name);
        ref.read(authProvider.notifier).signedIn(user);
      }
    } on AuthFailure catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  /// Staggered entrance that starts as the logo lands from the splash.
  Widget _in(int order, Widget child) => child
      .animate(delay: (280 + order * 70).ms)
      .fadeIn(duration: 420.ms, curve: Curves.easeOut)
      .moveY(begin: 14, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final demo = ref.watch(authServiceProvider).isDemo;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(size: 56),
                    const SizedBox(height: 28),
                    _in(0, _ModeSwitch(signUp: _signUp, onChanged: (v) => setState(() => _signUp = v))),
                    const SizedBox(height: 28),
                    _in(
                      1,
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(_signUp),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_signUp ? 'Create your account' : 'Welcome back', style: text.headlineMedium),
                            const SizedBox(height: 8),
                            Text(
                              _signUp
                                  ? 'Join ${AppInfo.name} and turn every alarm into a workout.'
                                  : 'Log in to pick up your streak where you left it.',
                              style: text.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _in(
                      2,
                      GradientButton(
                        label: 'Continue with phone',
                        icon: Icons.phone_iphone_rounded,
                        onPressed: () => context.push(Routes.authPhone, extra: _signUp),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _in(3, _GoogleButton(busy: _googleBusy, onTap: _google)),
                    const SizedBox(height: 24),
                    _in(
                      4,
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.stroke)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(_signUp ? 'Already have an account?' : 'New here?', style: text.bodySmall),
                          ),
                          Expanded(child: Divider(color: AppColors.stroke)),
                        ],
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _signUp = !_signUp),
                        child: Text(_signUp ? 'Log in' : 'Create an account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (demo) _in(5, const DemoNote()),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: TextButton(
                onPressed: () => context.push(Routes.privacy),
                child: Text(
                  'By continuing you agree to our Privacy Policy',
                  style: text.bodySmall?.copyWith(decoration: TextDecoration.underline),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sign up / Log in segmented control with a sliding white thumb.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.signUp, required this.onChanged});

  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: signUp ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppColors.softShadow(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (value, label) in [(true, 'Sign up'), (false, 'Log in')])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(value);
                    },
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: signUp == value ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Text(
                  'G',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14),
                ),
              ),
            const SizedBox(width: 12),
            Text('Continue with Google', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
