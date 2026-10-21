import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/app_user.dart';

/// Sign-in backend. [FirebaseAuthService] is used when Firebase is
/// configured; otherwise [DemoAuthService] lets the whole flow be tried
/// without a backend.
abstract class AuthService {
  bool get isDemo;
  AppUser? get currentUser;
  Stream<AppUser?> get changes;

  /// [phone] is in E.164 form, e.g. +919876543210.
  Future<CodeSent> sendCode(String phone, {int? resendToken});
  Future<AppUser> verifyCode(String verificationId, String code);

  /// Returns null if the user closed the Google account picker.
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  final _auth = FirebaseAuth.instance;
  bool _googleReady = false;

  @override
  bool get isDemo => false;

  static AppUser? _map(User? u) {
    if (u == null) return null;
    final google = u.providerData.any((p) => p.providerId == 'google.com');
    return AppUser(
      uid: u.uid,
      method: google ? SignInMethod.google : SignInMethod.phone,
      name: u.displayName,
      email: u.email,
      phone: u.phoneNumber,
    );
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> get changes => _auth.authStateChanges().map(_map);

  @override
  Future<CodeSent> sendCode(String phone, {int? resendToken}) {
    final done = Completer<CodeSent>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android instant verification / SMS auto-retrieval.
        try {
          final result = await _auth.signInWithCredential(credential);
          if (!done.isCompleted) done.complete(CodeSent(autoSignedIn: _map(result.user)));
        } on FirebaseAuthException catch (e) {
          if (!done.isCompleted) done.completeError(_failure(e));
        }
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(_failure(e));
      },
      codeSent: (id, token) {
        if (!done.isCompleted) done.complete(CodeSent(verificationId: id, resendToken: token));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return done.future;
  }

  @override
  Future<AppUser> verifyCode(String verificationId, String code) async {
    try {
      final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code);
      final result = await _auth.signInWithCredential(cred);
      return _map(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize();
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthFailure('Google did not return a sign-in token. Please try again.');
      final result = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      return _map(result.user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure('Google sign-in failed (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  static AuthFailure _failure(FirebaseAuthException e) => AuthFailure(switch (e.code) {
    'invalid-phone-number' => 'That phone number doesn\'t look right.',
    'invalid-verification-code' => 'That code is incorrect. Check the SMS and try again.',
    'session-expired' || 'code-expired' => 'The code expired. Tap "Resend code".',
    'too-many-requests' => 'Too many attempts. Please wait a few minutes.',
    'network-request-failed' => 'No internet connection.',
    'account-exists-with-different-credential' => 'This email is already linked to another sign-in method.',
    _ => e.message ?? 'Sign-in failed. Please try again.',
  });
}

/// Works without any backend: the SMS code is always [demoCode] and Google
/// returns a sample account. The session is remembered on the device.
class DemoAuthService implements AuthService {
  DemoAuthService(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static const demoCode = '123456';
  static const _key = 'auth.demo.v1';

  final SharedPreferences _prefs;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  bool get isDemo => true;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get changes => _controller.stream;

  Future<AppUser> _set(AppUser? u) async {
    _user = u;
    if (u == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode(u.toJson()));
    }
    _controller.add(u);
    return u ?? const AppUser(uid: '', method: SignInMethod.phone);
  }

  @override
  Future<CodeSent> sendCode(String phone, {int? resendToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return CodeSent(verificationId: 'demo:$phone', resendToken: 1);
  }

  @override
  Future<AppUser> verifyCode(String verificationId, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (code != demoCode) throw const AuthFailure('That code is incorrect. In demo mode the code is 123456.');
    final phone = verificationId.replaceFirst('demo:', '');
    return _set(AppUser(uid: 'demo-$phone', method: SignInMethod.phone, phone: phone));
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _set(
      const AppUser(uid: 'demo-google', method: SignInMethod.google, name: 'Demo User', email: 'demo.user@gmail.com'),
    );
  }

  @override
  Future<void> signOut() async => _set(null);
}
