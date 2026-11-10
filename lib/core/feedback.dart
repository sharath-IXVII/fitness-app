import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_info.dart';

/// Opens the phone's email app with a message to us ready to write. If there
/// is no email app, the address is copied so it can be pasted anywhere.
Future<void> sendFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: AppInfo.feedbackEmail,
    query:
        'subject=${Uri.encodeComponent('${AppInfo.name} feedback')}&body=${Uri.encodeComponent('\n\n(Tell us what you love, what is broken or what you want next.)\n\n---\n${_about()}')}',
  );
  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {}
  if (!opened) {
    await Clipboard.setData(ClipboardData(text: AppInfo.feedbackEmail));
    messenger.showSnackBar(SnackBar(content: Text('Email copied: ${AppInfo.feedbackEmail}')));
  }
}

/// The phone's system, so a bug can be reproduced. No personal data.
String _about() {
  var os = '';
  try {
    os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {}
  return '${AppInfo.name} · $os';
}
