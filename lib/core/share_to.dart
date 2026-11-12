import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'i18n/i18n.dart';
import 'theme/app_colors.dart';

/// Where a picture is shared.
enum ShareApp {
  whatsapp('WhatsApp', 'com.whatsapp', Color(0xFF25D366)),
  instagram('Instagram', 'com.instagram.android', Color(0xFFE1306C)),
  more('More', null, null);

  const ShareApp(this.label, this.package, this.color);

  final String label;
  final String? package;
  final Color? color;
}

const _channel = MethodChannel('fittarc/share');

/// Shares [png] to [app] directly (Android), or through the phone's share
/// sheet when that app isn't installed or for "More". Overridden in tests.
final shareToAppProvider = Provider<Future<void> Function(Uint8List png, String text, ShareApp app)>(
  (ref) => (png, text, app) async {
    if (app.package != null && !kIsWeb && Platform.isAndroid) {
      try {
        final dir = Directory('${(await getTemporaryDirectory()).path}/share');
        await dir.create(recursive: true);
        final file = File('${dir.path}/fittarc-${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(png, flush: true);
        final ok = await _channel.invokeMethod<bool>('shareTo', {
          'path': file.path,
          'package': app.package,
          'text': text,
        });
        if (ok == true) return;
      } catch (e) {
        debugPrint('share to ${app.label}: $e');
      }
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: 'fittarc.png')],
        text: text,
      ),
    );
  },
);

/// WhatsApp · Instagram · More, for sharing a card.
class ShareRow extends StatelessWidget {
  const ShareRow({super.key, required this.onShare, this.busy = false, this.apps = ShareApp.values});

  final void Function(ShareApp app) onShare;
  final List<ShareApp> apps;
  final bool busy;

  /// A darker shade of [c], readable on its pale tint.
  static Color _deep(Color c) => Color.lerp(c, Colors.black, 0.28)!;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final (i, app) in apps.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              // Light, soft buttons: a pale tint of the app's colour with its
              // colour for the icon and text.
              style: FilledButton.styleFrom(
                backgroundColor: Color.lerp(Colors.white, app.color ?? AppColors.primary, 0.14),
                foregroundColor: _deep(app.color ?? AppColors.primary),
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: (app.color ?? AppColors.primary).withValues(alpha: 0.35)),
                ),
              ),
              onPressed: busy ? null : () => onShare(app),
              icon: Icon(switch (app) {
                ShareApp.whatsapp => Icons.chat_rounded,
                ShareApp.instagram => Icons.camera_alt_rounded,
                ShareApp.more => Icons.ios_share_rounded,
              }, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  app == ShareApp.more ? tr('More') : app.label,
                  style: text.labelLarge?.copyWith(color: _deep(app.color ?? AppColors.primary)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
