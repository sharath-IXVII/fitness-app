import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../friends/friends_backend.dart' show FriendsFailure;
import '../friends/friends_providers.dart';
import 'clubs_providers.dart';
import 'domain/club.dart';

/// One club: its chat for members, or a Join button for everyone else.
class ClubScreen extends ConsumerStatefulWidget {
  const ClubScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen> {
  final _input = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _say(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<void> Function() action, String failed) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FriendsFailure catch (e) {
      _say(e.message);
    } catch (_) {
      _say(failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final problem = messageProblem(_input.text);
    if (problem != null) return setState(() => _error = problem);
    final me = ref.read(myPublicProfileProvider)!;
    final text = _input.text;
    setState(() => _error = null);
    _input.clear();
    await _run(
      () => ref.read(clubsBackendProvider)!.send(widget.id, uid: me.uid, myName: me.name, text: text),
      "Couldn't send. Check your internet.",
    );
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  Future<void> _messageActions(Club club, ClubMessage m, String me) async {
    final mine = m.uid == me, owner = club.ownerUid == me;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine || owner)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete message'),
                onTap: () => Navigator.of(s).pop('delete'),
              ),
            if (!mine) ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () => Navigator.of(s).pop('report'),
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text('Block ${m.name}'),
                subtitle: const Text("You won't see their messages"),
                onTap: () => Navigator.of(s).pop('block'),
              ),
              if (owner)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: Text('Remove ${m.name} from the club'),
                  onTap: () => Navigator.of(s).pop('remove'),
                ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final b = ref.read(clubsBackendProvider)!;
    switch (choice) {
      case 'delete':
        await _run(() => b.deleteMessage(club.id, m.id), "Couldn't delete. Check your internet.");
      case 'report':
        await _run(() async {
          await b.report(me: me, club: club.id, message: m, reason: 'Reported from the club chat');
          _say('Thanks. We will review it.');
        }, "Couldn't report. Check your internet.");
      case 'block':
        if (!await _confirm('Block ${m.name}?', "You won't see their messages in any club.", 'Block')) return;
        await ref.read(hiddenPeopleProvider.notifier).hide(m.uid);
        await _run(() => ref.read(friendsBackendProvider)!.block(me, m.uid), "Couldn't block. Check your internet.");
      case 'remove':
        if (!await _confirm('Remove ${m.name}?', "They can't join this club again.", 'Remove')) return;
        await _run(() => b.removeMember(club.id, m.uid), "Couldn't remove. Check your internet.");
    }
  }

  Future<void> _menu(Club club, String me, String action) async {
    final b = ref.read(clubsBackendProvider)!;
    if (action == 'leave') {
      if (!await _confirm('Leave ${club.name}?', 'You can join again later.', 'Leave')) return;
      await _run(() => b.leave(club.id, me), "Couldn't leave. Check your internet.");
    } else if (action == 'delete') {
      if (!await _confirm('Delete ${club.name}?', 'The club and its chat are removed for everyone.', 'Delete')) return;
      await _run(() => b.deleteClub(club.id, me), "Couldn't delete. Check your internet.");
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final me = ref.watch(myPublicProfileProvider);
    final club = ref.watch(clubProvider(widget.id));
    final c = club.value;
    if (me == null || c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Club')),
        body: PageBackground(
          child: Center(
            child: club.isLoading
                ? const CircularProgressIndicator()
                : Text('This club is no longer here.', style: text.bodyLarge),
          ),
        ),
      );
    }
    final owner = c.ownerUid == me.uid;
    // Membership is what the club says, so someone removed by the owner sees Join.
    final member = ref.watch(clubMembersProvider(widget.id)).value?.containsKey(me.uid) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (member)
            PopupMenuButton<String>(
              tooltip: 'Club options',
              onSelected: (a) => _menu(c, me.uid, a),
              itemBuilder: (_) => [
                if (!owner) const PopupMenuItem(value: 'leave', child: Text('Leave club')),
                if (owner) const PopupMenuItem(value: 'delete', child: Text('Delete club')),
              ],
            ),
        ],
      ),
      body: PageBackground(child: member ? _chat(c, me.uid) : _about(c, me.uid, me.name)),
    );
  }

  Widget _about(Club c, String uid, String name) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(c.kind.icon, size: 56, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(c.name, style: text.headlineSmall, textAlign: TextAlign.center),
        Text('${c.kind.label} · started by ${c.ownerName}', style: text.bodyMedium, textAlign: TextAlign.center),
        if (c.about.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(c.about, style: text.bodyLarge, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        GradientButton(
          label: _busy ? 'Joining…' : 'Join club',
          icon: Icons.group_add_rounded,
          onPressed: _busy
              ? null
              : () => _run(
                  () => ref
                      .read(clubsBackendProvider)!
                      .join(c.id, uid: uid, myName: name, clubName: c.name, kind: c.kind),
                  "Couldn't join. Check your internet.",
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Be kind. Chats disappear after 24 hours and links are not allowed.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _chat(Club c, String me) {
    final text = Theme.of(context).textTheme;
    final hidden = ref.watch(hiddenPeopleProvider);
    final now = clock.now();
    final messages = [
      for (final m in ref.watch(clubMessagesProvider(c.id)).value ?? const <ClubMessage>[])
        if (!hidden.contains(m.uid) && !m.expired(now)) m,
    ];
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Messages disappear after 24 hours. Links are not allowed.', style: text.bodySmall)),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(child: Text('Say hello to the club!', style: text.bodyLarge))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[messages.length - 1 - i];
                    return _Bubble(message: m, mine: m.uid == me, onLongPress: () => _messageActions(c, m, me));
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.danger)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: ClubLimits.message,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Message the club'),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      iconSize: 26,
                      onPressed: _busy ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.onLongPress});

  final ClubMessage message;
  final bool mine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.selectionClick();
          onLongPress();
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: AppColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) Text(message.name, style: text.labelMedium?.copyWith(color: AppColors.primary)),
              Text(message.text, style: text.bodyLarge?.copyWith(color: mine ? Colors.white : null)),
              Text(
                DateFormat('h:mm a').format(message.at),
                style: text.labelSmall?.copyWith(color: mine ? Colors.white70 : AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
