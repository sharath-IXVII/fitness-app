import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../clubs/clubs_providers.dart' show shareTextProvider;
import '../friends/friends_backend.dart' show FriendsFailure;
import '../friends/friends_providers.dart';
import 'domain/team.dart';
import 'teams_providers.dart';

/// "Team streaks" on the Friends page: your teams, and create or join one.
class TeamsSection extends ConsumerWidget {
  const TeamsSection({super.key});

  Future<String?> _ask(BuildContext context, String title, String hint, String action) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(d).pop(c.text), child: Text(action)),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  Future<void> _run(BuildContext context, Future<Team> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final t = await action();
      if (context.mounted) context.push(Routes.team, extra: t.id);
    } on FriendsFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't reach FittArc. Check your internet.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final teams = ref.watch(myTeamsProvider).value ?? const <Team>[];
    final me = ref.watch(myPublicProfileProvider);
    final b = ref.watch(teamsBackendProvider);
    if (me == null || b == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Team streaks', style: text.titleLarge),
        const SizedBox(height: 2),
        Text(
          'Up to 6 friends. A day counts only when everyone hits their goals. One miss and the team streak is gone!',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        for (final t in teams) _TeamTile(team: t, me: me.uid),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final name = await _ask(context, 'Name your team', 'Winter Warriors', 'Create');
                  if (name != null && context.mounted) await _run(context, () => b.create(me.uid, me.name, name));
                },
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('Create team'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final code = await _ask(context, 'Join a team', 'Team code, e.g. K7Q2MX', 'Join');
                  if (code != null && context.mounted) await _run(context, () => b.join(me.uid, me.name, code));
                },
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Join team'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamTile extends ConsumerWidget {
  const _TeamTile({required this.team, required this.me});

  final Team team;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final days = ref.watch(teamDaysProvider(team.id)).value ?? const {};
    final streak = teamStreak(team.members, days, clock.now());
    final today = days[teamDayKey(clock.now())] ?? const <String>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push(Routes.team, extra: team.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text('🔥', style: text.headlineSmall),
                const SizedBox(width: 6),
                Text('$streak', style: text.headlineSmall),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team.name, style: text.titleMedium),
                      Text(
                        '${today.length} of ${team.members.length} done today'
                        '${teamBadge(streak) == null ? '' : ' · ${teamBadge(streak)}'}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!today.contains(me)) Icon(Icons.priority_high_rounded, color: AppColors.amber),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One team: today's status for everyone, the streak, the badge and the code.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final team = (ref.watch(myTeamsProvider).value ?? const <Team>[]).where((t) => t.id == id).firstOrNull;
    final me = ref.watch(friendsUidProvider);
    if (team == null || me == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('You are not in this team.')),
      );
    }
    final days = ref.watch(teamDaysProvider(id)).value ?? const {};
    final now = clock.now();
    final streak = teamStreak(team.members, days, now);
    final today = days[teamDayKey(now)] ?? const <String>{};
    final badge = teamBadge(streak);
    final next = teamBadges.where((b) => b.$1 > streak).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) async {
              await ref.read(teamsBackendProvider)?.leave(team.id, me);
              if (context.mounted) Navigator.of(context).pop();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave team'))],
          ),
        ],
      ),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('🔥 $streak', style: text.displaySmall),
                  Text('day team streak', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    badge != null
                        ? 'Badge: $badge 🏅'
                        : next == null
                        ? ''
                        : '${next.$1 - streak} more days for ${next.$2}',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Today', style: text.titleLarge),
            const SizedBox(height: 8),
            for (final m in team.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  today.contains(m) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: today.contains(m) ? AppColors.primary : AppColors.textMuted,
                ),
                title: Text(m == me ? '${team.names[m] ?? 'You'} (you)' : team.names[m] ?? 'Member'),
                subtitle: Text(today.contains(m) ? 'Goals done' : 'Not yet'),
              ),
            if (team.members.length < 2)
              Text('Invite at least one friend: team streaks need 2 or more.', style: text.bodyMedium),
            const SizedBox(height: 16),
            if (team.code != null && team.members.length < Team.maxMembers)
              GradientButton(
                label: 'Invite friends (code ${team.code})',
                icon: Icons.share_rounded,
                onPressed: () => ref.read(shareTextProvider)(
                  'Join my FittArc team "${team.name}"! Friends → Join team → code ${team.code}. '
                  'We keep a streak together: one miss and it\'s gone 🔥',
                ),
              ),
            const SizedBox(height: 8),
            if (team.code != null)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: team.code!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy code'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(nudgesProvider),
              onChanged: (v) => ref.read(nudgesProvider.notifier).set(v),
              title: const Text('Nudges'),
              subtitle: const Text('A friendly push when teammates are done and you are not. Turn off any time.'),
            ),
          ],
        ),
      ),
    );
  }
}
