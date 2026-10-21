import 'dart:typed_data';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'domain/scan_result.dart';

/// Sends a meal photo to the `scanFood` Cloud Function (backend/functions),
/// which asks a vision model for a nutrition estimate. The model API key
/// lives only on the server.
abstract class FoodScanner {
  Future<ScanResult> scan(Uint8List image, String mediaType, {String? hint});
}

class CloudFoodScanner implements FoodScanner {
  final _fn = FirebaseFunctions.instanceFor(region: 'asia-south1')
      .httpsCallable('scanFood', options: HttpsCallableOptions(timeout: const Duration(seconds: 120)));

  @override
  Future<ScanResult> scan(Uint8List image, String mediaType, {String? hint}) async {
    try {
      final res = await _fn.call<Map<String, dynamic>>({
        'image': base64Encode(image),
        'mediaType': mediaType,
        if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim(),
      });
      return ScanResult.fromJson(Map<String, dynamic>.from(res.data));
    } on FirebaseFunctionsException catch (e) {
      throw ScanFailure(switch (e.code) {
        'not-found' => 'The food scanner isn\'t deployed yet. See backend/README.md.',
        'unauthenticated' => 'Sign in again to scan food.',
        'deadline-exceeded' => 'That took too long. Check your connection and try again.',
        _ => e.message ?? 'Couldn\'t scan that photo. Please try again.',
      });
    } catch (_) {
      throw const ScanFailure('Couldn\'t reach the scanner. Check your connection and try again.');
    }
  }
}

/// Null when the app isn't connected to Firebase (demo mode): the scan
/// screen then explains the setup and offers manual entry instead.
final foodScannerProvider = Provider<FoodScanner?>(
  (ref) => ref.watch(authServiceProvider).isDemo ? null : CloudFoodScanner(),
);
