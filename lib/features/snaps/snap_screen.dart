import '../../core/i18n/i18n.dart';

import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

import '../../core/photo_store.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../friends/friends_providers.dart';
import 'domain/food_snap.dart';
import '../../core/share_to.dart';
import 'snap_share_backend.dart';
import 'snap_share_providers.dart';
import 'snaps_providers.dart';
import 'widgets/snap_card.dart';
import '../arcs/arc_providers.dart' show themeSeasonProvider;

/// Which snap to show; [photo] skips reading the file when the photo was
/// just taken (it may still be being written).
class SnapArgs {
  const SnapArgs(this.id, {this.photo});

  final String id;
  final Uint8List? photo;
}

/// Shares [png] through the phone's share sheet (Instagram story, WhatsApp,
/// and so on). Overridden in tests.
final shareSnapProvider = Provider<Future<void> Function(Uint8List png, String text)>(
  (ref) => (png, text) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: 'fittarc-snap.png')],
        text: text,
      ),
    );
  },
);

/// One food snap as a story card, with Share.
class SnapScreen extends ConsumerStatefulWidget {
  const SnapScreen({super.key, required this.args});

  final SnapArgs args;

  @override
  ConsumerState<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends ConsumerState<SnapScreen> {
  final _boundary = GlobalKey();
  ImageProvider? _photo;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.args.photo case final bytes?) {
      _photo = MemoryImage(bytes);
    } else {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    final name = ref.read(snapByIdProvider(widget.args.id))?.photo;
    if (name == null) return;
    final f = await PhotoStore.file(name);
    if (f != null && mounted) setState(() => _photo = FileImage(f));
  }

  /// The card as a 1080 × 1920 PNG.
  Future<Uint8List?> _png() async {
    final box = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return null;
    final image = await box.toImage(pixelRatio: 1080 / SnapCard.size.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// The card as a small JPEG for sending inside the app (about 100 KB).
  Future<Uint8List?> _jpeg() async {
    final box = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return null;
    final image = await box.toImage(pixelRatio: 1.6);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final (w, h) = (image.width, image.height);
    image.dispose();
    if (data == null) return null;
    final rgba = data.buffer.asUint8List();
    return Isolate.run(() {
      final pic = img.Image.fromBytes(width: w, height: h, bytes: rgba.buffer, numChannels: 4);
      var q = 75;
      var out = img.encodeJpg(pic, quality: q);
      while (out.length > SnapShareBackend.maxBytes && q > 35) {
        q -= 15;
        out = img.encodeJpg(pic, quality: q);
      }
      return out;
    });
  }

  /// Sends the snap to friends inside FittArc; it disappears after 24 hours.
  Future<void> _sendToFriends(FoodSnap snap) async {
    final friends = ref.read(friendsListProvider).value ?? const [];
    final me = ref.read(myPublicProfileProvider);
    final b = ref.read(snapShareBackendProvider);
    if (me == null || b == null) return;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Add friends first (Friends page).'))));
      return;
    }
    final chosen = await showDialog<List<String>>(
      context: context,
      builder: (d) {
        final picked = <String>{};
        return StatefulBuilder(
          builder: (d, setD) => AlertDialog(
            title: Text(tr('Send to friends')),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in friends)
                    CheckboxListTile(
                      value: picked.contains(f.uid),
                      onChanged: (v) => setD(() => v == true ? picked.add(f.uid) : picked.remove(f.uid)),
                      title: Text(f.name),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(d).pop(), child: Text(tr('Cancel'))),
              TextButton(
                onPressed: picked.isEmpty ? null : () => Navigator.of(d).pop(picked.toList()),
                child: Text(tr('Send')),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final jpeg = await _jpeg();
      if (jpeg == null) return;
      await b.send(
        from: me.uid,
        fromName: me.name,
        to: chosen.take(SnapShareBackend.maxFriends).toList(),
        caption: '${snap.meal.label}: about ${snap.total.kcal.round()} kcal',
        jpeg: jpeg,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sent to ${chosen.length} ${chosen.length == 1 ? 'friend' : 'friends'}. Gone in 24 hours.'),
        ),
      );
    } catch (e) {
      debugPrint('snap send: $e');
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't send. Check your internet.")));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _share(FoodSnap snap, [ShareApp app = ShareApp.more]) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.selectionClick();
    try {
      final png = await _png();
      if (png != null) {
        final text = '${snap.meal.label}: about ${snap.total.kcal.round()} kcal. Snapped with FittArc, fittarc.in';
        if (app == ShareApp.more) {
          await ref.read(shareSnapProvider)(png, text);
        } else {
          await ref.read(shareToAppProvider)(png, text, app);
        }
      }
    } catch (e) {
      debugPrint('snap share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't share the snap. Try again.")));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete(FoodSnap snap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete this snap?')),
        content: Text(tr('The meal stays in your diet log.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(tr('Keep'))),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(tr('Delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(snapsProvider.notifier).remove(snap.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(snapByIdProvider(widget.args.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Food snap')),
        actions: [
          if (snap != null)
            IconButton(
              tooltip: tr('Delete snap'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(snap),
            ),
        ],
      ),
      body: PageBackground(
        child: snap == null
            ? Center(child: Text(tr('This snap is no longer on this phone.')))
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: FittedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: RepaintBoundary(
                            key: _boundary,
                            child: SnapCard(snap: snap, photo: _photo, weather: ref.watch(themeSeasonProvider).effect),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        children: [
                          ShareRow(
                            apps: const [ShareApp.whatsapp, ShareApp.instagram],
                            busy: _sharing,
                            onShare: (app) => _share(snap, app),
                          ),
                          const SizedBox(height: 10),
                          GradientButton(
                            label: _sharing ? 'Preparing…' : 'Share to story or other apps',
                            icon: Icons.ios_share_rounded,
                            onPressed: _sharing ? null : () => _share(snap),
                          ),
                          if (ref.watch(snapShareBackendProvider) != null)
                            TextButton.icon(
                              onPressed: _sharing ? null : () => _sendToFriends(snap),
                              icon: const Icon(Icons.send_rounded),
                              label: Text(tr('Send to FittArc friends (24 h)')),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            tr('Saved on this phone only. Sharing sends the picture to the app you pick.'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
