import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/photo_store.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import 'domain/food_snap.dart';
import 'snaps_providers.dart';
import 'widgets/snap_card.dart';

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

  Future<void> _share(FoodSnap snap) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.selectionClick();
    try {
      final png = await _png();
      if (png != null) {
        await ref.read(shareSnapProvider)(
          png,
          '${snap.meal.label}: about ${snap.total.kcal.round()} kcal. Snapped with FittArc, fittarc.in',
        );
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
        title: const Text('Delete this snap?'),
        content: const Text('The meal stays in your diet log.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Delete')),
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
        title: const Text('Food snap'),
        actions: [
          if (snap != null)
            IconButton(
              tooltip: 'Delete snap',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(snap),
            ),
        ],
      ),
      body: PageBackground(
        child: snap == null
            ? const Center(child: Text('This snap is no longer on this phone.'))
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
                            child: SnapCard(snap: snap, photo: _photo),
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
                          GradientButton(
                            label: _sharing ? 'Preparing…' : 'Share to story or friends',
                            icon: Icons.ios_share_rounded,
                            onPressed: _sharing ? null : () => _share(snap),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saved on this phone only. Sharing sends the picture to the app you pick.',
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
