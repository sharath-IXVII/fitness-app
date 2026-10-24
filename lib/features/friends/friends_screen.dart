import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../arcs/arc_providers.dart';
import '../arcs/domain/arc.dart';
import '../arcs/widgets/arc_widgets.dart';
import '../diet/widgets/sheet_frame.dart';
import '../workout/domain/exercise.dart';
import '../workout/domain/routine.dart';
import '../workout/workout_screen.dart';
import 'domain/friends.dart';
import 'friends_backend.dart';
import 'friends_providers.dart';

/// Friends: challenge people with a code, become friends when you both
/// finish, then compare XP, streaks and arc badges on the leaderboard.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final me = ref.watch(myPublicProfileProvider);
    if (ref.watch(friendsBackendProvider) == null || me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: const PageBackground(child: _Unavailable()),
      );
    }
    final challenges = ref.watch(challengesProvider);
    final friends = ref.watch(friendsListProvider).value ?? const <PublicProfile>[];
    final board = [...friends, me]..sort((a, b) => b.xp.compareTo(a.xp));

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: PageBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _MyCard(me: me),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Challenge',
                    icon: Icons.local_fire_department_rounded,
                    onPressed: () => showChallengeSheet(context, ref),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _enterCode(context, ref),
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Enter code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Challenges', style: text.titleLarge),
            const SizedBox(height: 10),
            challenges.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text("Couldn't load challenges. Check your internet.", style: text.bodyMedium),
              data: (list) {
                final shown = list.where((c) => c.status != ChallengeStatus.declined).take(20).toList();
                if (shown.isEmpty) {
                  return Text(
                    'No challenges yet. Tap Challenge, pick an exercise and send the code to a friend.',
                    style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  );
                }
                return Column(
                  children: [
                    for (final c in shown) ...[_ChallengeCard(challenge: c, me: me), const SizedBox(height: 10)],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text('Leaderboard', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              friends.isEmpty ? 'Finish a challenge together and your friend appears here.' : 'Ranked by XP',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final (i, p) in board.indexed)
              _BoardRow(
                rank: i + 1,
                profile: p,
                isMe: p.uid == me.uid,
                onTap: p.uid == me.uid ? null : () => context.push(Routes.friendProfile, extra: p.uid),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterCode(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
    if (code == null || !context.mounted) return;
    final b = ref.read(friendsBackendProvider)!, me = ref.read(myPublicProfileProvider)!;
    try {
      final c = await b.findByCode(code, me: me.uid);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('${c.fromName} challenges you'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.fromTitle != null) ...[_TitleChip(title: c.fromTitle!), const SizedBox(height: 12)],
              Text('${c.task[0].toUpperCase()}${c.task.substring(1)} for the ${c.arcLabel}.'),
              const SizedBox(height: 8),
              const Text('The camera counts your reps. Finish it and you both become friends.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Accept')),
          ],
        ),
      );
      if (ok != true) return;
      final joined = await b.accept(c, me);
      if (context.mounted) startChallengeWorkout(context, joined);
    } on FriendsFailure catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't reach Friends. Check your internet and try again.")));
      }
    }
  }
}

/// Opens the camera workout for a challenge.
void startChallengeWorkout(BuildContext context, FriendChallenge c) => context.push(
  Routes.workout,
  extra: WorkoutArgs(
    routine: Routine(id: 'challenge-${c.id}', name: 'Challenge', steps: [RoutineStep(c.exercise, c.reps)]),
    challenge: c,
  ),
);

/// Pick an exercise and a target, then share the code (or, for a friend,
/// send it straight to them).
Future<void> showChallengeSheet(BuildContext context, WidgetRef ref, {PublicProfile? to}) =>
    SheetFrame.show<void>(context, _ChallengeSheet(to: to));

class _ChallengeSheet extends ConsumerStatefulWidget {
  const _ChallengeSheet({this.to});

  final PublicProfile? to;

  @override
  ConsumerState<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends ConsumerState<_ChallengeSheet> {
  Exercise _exercise = Exercise.pushUp;
  int _reps = 10;
  bool _sending = false;

  void _pick(Exercise e) => setState(() {
    _exercise = e;
    _reps = e.timed ? 30 : e.defaultTarget;
  });

  Future<void> _send() async {
    final b = ref.read(friendsBackendProvider), me = ref.read(myPublicProfileProvider);
    if (b == null || me == null) return;
    setState(() => _sending = true);
    try {
      final c = await b.createChallenge(
        from: me,
        exercise: _exercise,
        reps: _reps,
        arcLabel: ref.read(currentArcProvider).label,
        to: widget.to,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.to == null) {
        // The challenge exists either way; it's listed with its code.
        SharePlus.instance.share(ShareParams(text: c.inviteMessage(AppInfo.storeUrl))).catchError((_) {
          return const ShareResult('', ShareResultStatus.unavailable);
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Challenge sent to ${widget.to!.name}. Your turn too!')));
      }
    } on FriendsFailure catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't send. Check your internet.")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final arc = ref.watch(currentArcProvider);
    final step = _exercise.timed ? 10 : (_reps >= 20 ? 5 : 1);
    return SheetFrame(
      title: widget.to == null ? 'Challenge a friend' : 'Challenge ${widget.to!.name}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For the ${arc.label}. The camera counts every rep, so no cheating!',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in challengeExercises)
                  ChoiceChip(label: Text(e.label), selected: e == _exercise, onSelected: (_) => _pick(e)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Fewer',
                  onPressed: _reps - step >= (_exercise.timed ? 10 : 1) ? () => setState(() => _reps -= step) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    _exercise.timed ? '${_reps}s' : '× $_reps',
                    style: text.displaySmall?.copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'More',
                  onPressed: _reps + step <= (_exercise.timed ? 300 : 200) ? () => setState(() => _reps += step) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: _sending ? 'Sending…' : (widget.to == null ? 'Create & share' : 'Send challenge'),
              icon: Icons.send_rounded,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enter challenge code'),
    content: TextField(
      controller: _c,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      maxLength: 8,
      decoration: const InputDecoration(hintText: 'e.g. K7Q2MX'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Find')),
    ],
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 14),
            Text('Friends is almost here', style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Challenges and the leaderboard need an online account. They turn on in the next update.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// This user's public card: what friends see.
class _MyCard extends StatelessWidget {
  const _MyCard({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _Medal(profile: me, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(me.name, style: text.titleMedium),
                if (me.title != null) _TitleChip(title: me.title!),
                const SizedBox(height: 4),
                Text(
                  'Level ${me.level} · ${me.xp} XP · ${me.streak}-day streak',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: ArcTier.master.ring.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.military_tech_rounded, size: 14, color: AppColors.amber),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// The profile's best badge as a medal, or their initial.
class _Medal extends StatelessWidget {
  const _Medal({required this.profile, required this.size});

  final PublicProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final season = Season.values.asNameMap()[profile.titleSeason];
    final tier = profile.titleTier == null ? null : ArcTier.values[profile.titleTier!.clamp(0, 2)];
    if (season != null && tier != null) return ArcMedal(season: season, tier: tier, size: size, animate: size >= 100);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
      child: Text(
        profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.me});

  final FriendChallenge challenge;
  final PublicProfile me;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = challenge;
    final mine = c.isMine(me.uid);
    final other = c.otherName(me.uid);
    final iDid = c.doneBy(me.uid);
    final (status, color) = switch (c.status) {
      ChallengeStatus.done => ('Done together · friends ✓', AppColors.primary),
      ChallengeStatus.declined => ('Declined', AppColors.textMuted),
      ChallengeStatus.open => ('Waiting for someone to join · code ${c.code}', AppColors.amber),
      ChallengeStatus.accepted when !iDid => ('Your turn!', AppColors.energy),
      ChallengeStatus.accepted => ('Waiting for ${other ?? 'your friend'}', AppColors.textTertiary),
    };
    return GlassCard(
      padding: const EdgeInsets.all(14),
      glow: c.status == ChallengeStatus.accepted && !iDid ? AppColors.energy : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(c.exercise.icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine
                      ? (other == null ? 'You: ${c.task}' : 'You → $other: ${c.task}')
                      : '${c.fromName} → you: ${c.task}',
                  style: text.titleSmall,
                ),
                Text(status, style: text.bodySmall?.copyWith(color: color)),
              ],
            ),
          ),
          if (c.status == ChallengeStatus.open && mine)
            IconButton(
              tooltip: 'Share code again',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => SharePlus.instance.share(ShareParams(text: c.inviteMessage(AppInfo.storeUrl))),
            )
          else if (c.status == ChallengeStatus.accepted && !iDid)
            FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                startChallengeWorkout(context, c);
              },
              child: const Text('Go'),
            ),
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.rank, required this.profile, required this.isMe, this.onTap});

  final int rank;
  final PublicProfile profile;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            _Medal(profile: profile, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isMe ? '${profile.name} (you)' : profile.name, style: text.titleSmall),
                  Text(
                    profile.title ?? 'Level ${profile.level}',
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${profile.xp} XP', style: text.titleSmall?.copyWith(color: AppColors.primary)),
                Text('🔥 ${profile.streak}', style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A friend's profile: badge title, XP, streak, how their arc is going and
/// this week's workouts. Challenge them, or remove, block or report.
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final b = ref.watch(friendsBackendProvider);
    final me = ref.watch(myPublicProfileProvider);
    if (b == null || me == null) return const Scaffold(body: PageBackground(child: _Unavailable()));

    Future<void> menu(String action, PublicProfile p) async {
      final (title, body, verb) = switch (action) {
        'remove' => ('Remove ${p.name}?', 'You can become friends again with a new challenge.', 'Remove'),
        'block' => ('Block ${p.name}?', "They won't be able to challenge you.", 'Block'),
        _ => ('Report ${p.name}?', 'Report a rude name or abuse. We will review it.', 'Report'),
      };
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(verb)),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await switch (action) {
          'remove' => b.removeFriend(me.uid, p.uid),
          'block' => b.block(me.uid, p.uid),
          _ => b.report(me.uid, p.uid, 'reported from profile'),
        }.timeout(const Duration(seconds: 15));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Couldn't do that. Check your internet and try again.")));
        }
        return;
      }
      if (context.mounted) {
        if (action != 'report') context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$verb done.')));
      }
    }

    final async = ref.watch(friendProfileProvider(uid));
    final p = async.value;
    return Builder(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(p?.name ?? 'Friend'),
            actions: [
              if (p != null)
                PopupMenuButton<String>(
                  onSelected: (a) => menu(a, p),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove friend')),
                    PopupMenuItem(value: 'block', child: Text('Block')),
                    PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                ),
            ],
          ),
          body: PageBackground(
            child: p == null
                ? Center(
                    child: async.isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            async.hasError
                                ? "Couldn't load this profile. Check your internet."
                                : 'This person left FitArc.',
                            style: text.bodyMedium,
                          ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Center(child: _Medal(profile: p, size: 110)),
                      const SizedBox(height: 12),
                      Center(child: Text(p.name, style: text.headlineSmall)),
                      if (p.title != null) Center(child: _TitleChip(title: p.title!)),
                      const SizedBox(height: 18),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            _Stat(value: '${p.level}', label: 'Level'),
                            _Stat(value: '${p.xp}', label: 'XP'),
                            _Stat(value: '${p.streak}', label: 'Day streak'),
                            _Stat(value: '${p.bestStreak}', label: 'Best'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.arcLabel.isEmpty ? 'This arc' : p.arcLabel, style: text.titleSmall),
                            const SizedBox(height: 4),
                            Text('${p.arcActive} active days so far', style: text.bodyMedium),
                            const SizedBox(height: 10),
                            Text('Workouts this week', style: text.titleSmall),
                            const SizedBox(height: 4),
                            Text('${p.workoutsWeek} guided workouts', style: text.bodyMedium),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      GradientButton(
                        label: 'Challenge ${p.name}',
                        icon: Icons.local_fire_department_rounded,
                        onPressed: () => showChallengeSheet(context, ref, to: p),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.titleLarge?.copyWith(color: AppColors.primary)),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
