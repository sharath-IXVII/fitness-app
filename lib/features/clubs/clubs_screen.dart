import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../friends/friends_backend.dart' show FriendsFailure;
import '../friends/friends_providers.dart';
import 'clubs_providers.dart';
import 'domain/club.dart';
import 'domain/club_challenge.dart' show distanceBetween, formatKm;
import 'gps.dart';

/// Clubs: create your own, browse and join others.
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> {
  String _query = '';
  ClubKind? _kind;

  /// Near me (default) or all clubs.
  bool _near = true;
  bool _locating = false;
  String? _locError;

  Future<void> _findMe() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    final gps = ref.read(gpsProvider);
    final problem = await gps.ensure();
    final fix = problem == null ? await gps.current() : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) {
        ref.read(myAreaProvider.notifier).set(fix.point);
      } else {
        _locError = problem ?? tr("Couldn't find your location. Try again outside.");
      }
    });
  }

  Future<void> _enterCode(BuildContext context) async {
    final controller = TextEditingController();
    String? error;
    final club = await showDialog<Club>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(tr('Join with a code')),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            decoration: InputDecoration(hintText: tr('K7Q2MX'), errorText: error),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(), child: Text(tr('Cancel'))),
            TextButton(
              onPressed: () async {
                try {
                  final c = await ref.read(clubsBackendProvider)!.findByCode(controller.text);
                  if (d.mounted) Navigator.of(d).pop(c);
                } on FriendsFailure catch (e) {
                  setD(() => error = e.message);
                } catch (_) {
                  setD(() => error = "Couldn't check the code. Check your internet.");
                }
              },
              child: Text(tr('Find club')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (club != null && context.mounted) context.push(Routes.club, extra: club.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (ref.watch(clubsBackendProvider) == null || ref.watch(myPublicProfileProvider) == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Clubs'))),
        body: PageBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(tr('Sign in with Google to create and join clubs.'), style: text.bodyLarge),
            ),
          ),
        ),
      );
    }
    final mine = ref.watch(myClubIdsProvider).value ?? const <String>{};
    final all = ref.watch(discoverClubsProvider);
    bool matches(Club c) =>
        (_kind == null || c.kind == _kind) &&
        (_query.isEmpty || '${c.name} ${c.about}'.toLowerCase().contains(_query.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Clubs'))),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(tr('Find your gym, walking or running crew. Chats disappear after 24 hours.'), style: text.bodyMedium),
            const SizedBox(height: 14),
            GradientButton(
              label: tr('Create a club'),
              icon: Icons.add_rounded,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _CreateClubSheet(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => _enterCode(context),
              icon: const Icon(Icons.keyboard_rounded),
              label: Text(tr('Enter club code')),
            ),
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(tr('My clubs'), style: text.titleLarge),
              const SizedBox(height: 10),
              for (final id in mine) _MyClubTile(id: id),
            ],
            const SizedBox(height: 22),
            Text(tr('Discover'), style: text.titleLarge),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('Search clubs')),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final k in [null, ...ClubKind.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(k?.label ?? 'All'),
                        selected: _kind == k,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, icon: const Icon(Icons.near_me_rounded), label: Text(tr('Near me'))),
                ButtonSegment(value: false, icon: const Icon(Icons.public_rounded), label: Text(tr('All clubs'))),
              ],
              selected: {_near},
              onSelectionChanged: (v) => setState(() => _near = v.first),
            ),
            const SizedBox(height: 10),
            if (_near && ref.watch(myAreaProvider) == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      tr('Allow location to see clubs around you.'),
                      style: text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _locating ? null : _findMe,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(_locating ? tr('Finding you…') : tr('Find clubs near me')),
                    ),
                    if (_locError != null) ...[
                      const SizedBox(height: 6),
                      Text(_locError!, style: text.bodySmall, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              )
            else
              (_near ? ref.watch(nearbyClubsProvider) : all).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Column(
                  children: [
                    Text(
                      tr("Couldn't load clubs. Check your internet and try again."),
                      style: text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(_near ? nearbyClubsProvider : discoverClubsProvider),
                      child: Text(tr('Try again')),
                    ),
                  ],
                ),
                data: (clubs) {
                  final here = ref.watch(myAreaProvider);
                  final shown = clubs.where((c) => !mine.contains(c.id) && matches(c)).toList();
                  if (shown.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _near ? tr('No clubs near you yet. Start one!') : tr('No clubs here yet. Start one!'),
                        style: text.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final c in shown)
                        _ClubTile(
                          club: c,
                          away: here == null || c.location == null ? null : distanceBetween(here, c.location!),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MyClubTile extends ConsumerWidget {
  const _MyClubTile({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider(id)).value;
    if (club == null) return const SizedBox.shrink();
    return _ClubTile(club: club, member: true, unread: ref.watch(clubUnreadProvider(id)));
  }
}

class _ClubTile extends StatelessWidget {
  const _ClubTile({required this.club, this.member = false, this.unread = 0, this.away});

  final Club club;
  final bool member;
  final int unread;

  /// Metres from the user, when known.
  final double? away;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => context.push(Routes.club, extra: club.id),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(club.kind.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        if (away != null) '📍 ${formatKm(away!.round())}${club.area.isEmpty ? '' : ' · ${club.area}'}',
                        club.about.isEmpty ? '${club.kind.label} · ${club.ownerName}' : club.about,
                      ].join('\n'),
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    semanticsLabel: '$unread new messages',
                    style: text.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                )
              else
                Icon(
                  member ? Icons.chat_bubble_outline_rounded : Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateClubSheet extends ConsumerStatefulWidget {
  const _CreateClubSheet();

  @override
  ConsumerState<_CreateClubSheet> createState() => _CreateClubSheetState();
}

class _CreateClubSheetState extends ConsumerState<_CreateClubSheet> {
  final _name = TextEditingController();
  final _about = TextEditingController();
  final _area = TextEditingController();
  ClubKind _kind = ClubKind.gym;

  /// Where the club meets, so people nearby find it.
  (double, double)? _where;
  bool _locating = false;

  Future<void> _here() async {
    setState(() => _locating = true);
    final gps = ref.read(gpsProvider);
    final problem = await gps.ensure();
    final fix = problem == null ? await gps.current() : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) {
        _where = fix.point;
        ref.read(myAreaProvider.notifier).set(fix.point);
      } else {
        _error = problem ?? tr("Couldn't find your location. Try again outside.");
      }
    });
  }

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final problem = clubProblem(_name.text, _about.text);
    if (problem != null) return setState(() => _error = problem);
    final me = ref.read(myPublicProfileProvider)!;
    setState(() => _busy = true);
    try {
      final club = await ref
          .read(clubsBackendProvider)!
          .create(
            uid: me.uid,
            myName: me.name,
            name: _name.text,
            about: _about.text,
            kind: _kind,
            location: _where,
            area: _area.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(Routes.club, extra: club.id);
    } on FriendsFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't create the club. Check your internet.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Create a club'), style: text.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: ClubLimits.name.$2,
            decoration: InputDecoration(labelText: tr('Club name'), hintText: tr('Morning Walkers Indiranagar')),
          ),
          TextField(
            controller: _about,
            maxLength: ClubLimits.about,
            maxLines: 2,
            decoration: InputDecoration(labelText: tr('What is it about? (optional)')),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in ClubKind.values)
                ChoiceChip(
                  avatar: Icon(k.icon, size: 16),
                  label: Text(k.label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(tr('Where does the club meet?'), style: text.titleSmall),
          const SizedBox(height: 6),
          if (_where == null)
            OutlinedButton.icon(
              onPressed: _locating ? null : _here,
              icon: const Icon(Icons.my_location_rounded),
              label: Text(_locating ? tr('Finding you…') : tr('Use my location (people nearby find it)')),
            )
          else ...[
            Row(
              children: [
                Icon(Icons.place_rounded, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(tr('Location set. Nearby people will see this club.'), style: text.bodyMedium)),
                TextButton(onPressed: () => setState(() => _where = null), child: Text(tr('Clear'))),
              ],
            ),
            TextField(
              controller: _area,
              maxLength: 40,
              decoration: InputDecoration(labelText: tr('Area name'), hintText: tr('e.g. Indiranagar')),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          GradientButton(label: _busy ? 'Creating…' : 'Create club', onPressed: _busy ? null : _create),
        ],
      ),
    );
  }
}
