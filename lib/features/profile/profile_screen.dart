import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../snaps/snap_share_providers.dart';
import '../teams/teams_providers.dart';
import '../../core/cloud_backup.dart';
import '../../core/local_data.dart';
import '../../core/app_info.dart';
import '../../core/feedback.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/glass_card.dart';
import '../arcs/widgets/arc_widgets.dart';
import '../auth/auth_providers.dart';
import '../clubs/clubs_providers.dart';
import '../friends/friends_providers.dart';
import '../auth/domain/app_user.dart';
import '../streaks/daily_log_providers.dart';
import '../diet/widgets/sheet_frame.dart';
import 'domain/user_profile.dart';
import 'edit_profile_sheet.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _goalLabel = {
    FitnessGoal.loseWeight: 'Lose weight',
    FitnessGoal.maintain: 'Stay fit',
    FitnessGoal.buildMuscle: 'Build muscle',
  };
  static const _dietLabel = {
    DietType.veg: 'Vegetarian',
    DietType.nonVeg: 'Non-veg',
    DietType.eggetarian: 'Eggetarian',
    DietType.vegan: 'Vegan',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final t = ref.watch(targetsProvider);
    if (p == null || t == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final streak = ref.watch(streakProvider);
    final account = ref.watch(authProvider);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, style: text.titleSmall, textAlign: TextAlign.end),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Profile'))),
      body: PageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                    child: Text(
                      p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                      style: text.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: text.titleLarge),
                        const BadgeTitle(),
                        Text('${streak.current}-day streak · best ${streak.longest}', style: text.bodyMedium),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => SheetFrame.show<void>(context, const EditProfileSheet()),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(tr('Edit')),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.stroke),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 20),
              const ArcBadgeShelf(),
              const SizedBox(height: 22),
              Text(tr('About you'), style: text.titleMedium),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  children: [
                    row('Goal', _goalLabel[p.goal]!),
                    row('Diet', _dietLabel[p.diet]!),
                    row('Height', '${p.heightCm.round()} cm'),
                    row('Weight', '${p.weightKg.toStringAsFixed(1)} kg'),
                    row('BMI', '${t.bmi}'),
                    row('Wake up · sleep', '${p.wakeTime.format(context)} · ${p.sleepTime.format(context)}'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(tr('Daily targets'), style: text.titleMedium),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  children: [
                    row('Calories', '${t.calories} kcal'),
                    row('Protein · carbs · fat', '${t.proteinG} · ${t.carbsG} · ${t.fatG} g'),
                    row('Fiber', '${t.fiberG} g'),
                    row('Water', '${(t.waterMl / 1000).toStringAsFixed(1)} L'),
                    row('Steps', NumberFormat.decimalPattern().format(t.steps)),
                    row('Stride length', '${t.strideM} m'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Your feedback comes first'), style: text.titleSmall),
                          Text(
                            'Every message to ${AppInfo.feedbackEmail} is read, and it decides what we improve next.',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => sendFeedback(context), child: Text(tr('Write'))),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(tr('Account'), style: text.titleMedium),
              const SizedBox(height: 10),
              GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.mail_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Signed in with Google'), style: text.bodySmall),
                          Text(account?.handle ?? '—', style: text.titleSmall),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => ref.read(authProvider.notifier).signOut(), child: Text(tr('Sign out'))),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(tr('Data & privacy'), style: text.titleMedium),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _Action(
                      icon: Icons.translate_rounded,
                      label: '${tr('Language')}: ${(ref.watch(langProvider) ?? AppLang.en).native}',
                      onTap: () => context.push(Routes.languageSettings),
                    ),
                    _Action(
                      icon: Icons.mail_outline_rounded,
                      label: tr('Send feedback'),
                      onTap: () => sendFeedback(context),
                    ),
                    _Action(
                      icon: Icons.shield_outlined,
                      label: tr('Privacy policy'),
                      onTap: () => context.push(Routes.privacy),
                    ),
                    _Action(
                      icon: Icons.description_outlined,
                      label: tr('Terms of use'),
                      onTap: () => context.push(Routes.terms),
                    ),
                    _Action(
                      icon: Icons.restart_alt_rounded,
                      label: tr('Reset data on this device'),
                      onTap: () async {
                        if (await _confirm(
                          context,
                          title: tr('Start over?'),
                          body:
                              'This clears your profile, history, meals and alarms on this device. You stay signed in.',
                          action: 'Reset',
                        )) {
                          await ref.read(localDataProvider).wipe();
                        }
                      },
                    ),
                    _Action(
                      icon: Icons.person_remove_outlined,
                      label: tr('Delete account'),
                      danger: true,
                      onTap: () async {
                        if (!await _confirm(
                          context,
                          title: tr('Delete your account?'),
                          body:
                              'This permanently deletes your sign-in and clears all FittArc data on this device. '
                              'It can\'t be undone.',
                          action: 'Delete',
                        )) {
                          return;
                        }
                        if (!context.mounted) return;
                        // Capture everything now: once signed out, this screen
                        // is gone, so its ref can't be used after the awaits.
                        final auth = ref.read(authProvider.notifier);
                        final service = ref.read(authServiceProvider);
                        final local = ref.read(localDataProvider);
                        final friends = ref.read(friendsBackendProvider);
                        final uid = ref.read(friendsUidProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        if (!service.recentlySignedIn) {
                          if (context.mounted) {
                            await _confirm(
                              context,
                              title: tr('Sign in again first'),
                              body:
                                  'For your security, deleting an account needs a fresh sign-in. '
                                  'Sign in again, then come back here and tap Delete account.',
                              action: 'Sign out',
                            ).then((go) async {
                              if (go) await auth.signOut();
                            });
                          }
                          return;
                        }
                        try {
                          // Online data first, while still signed in.
                          if (friends != null && uid != null) {
                            await ref.read(clubsBackendProvider)?.deleteMe(uid).timeout(const Duration(seconds: 20));
                            await ref.read(teamsBackendProvider)?.leaveAll(uid).timeout(const Duration(seconds: 20));
                            await ref
                                .read(snapShareBackendProvider)
                                ?.deleteMine(uid)
                                .timeout(const Duration(seconds: 20));
                            await friends.deleteMe(uid).timeout(const Duration(seconds: 20));
                            await ref.read(cloudStoreProvider)?.delete(uid).timeout(const Duration(seconds: 20));
                          }
                        } catch (_) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(tr('Connect to the internet to delete your account.'))),
                          );
                          return;
                        }
                        try {
                          await auth.deleteAccount();
                        } on AuthFailure catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text(e.message)));
                          return;
                        }
                        await local.wipe();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    ) ??
    false;

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, color: danger ? AppColors.danger : AppColors.primary),
        title: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
