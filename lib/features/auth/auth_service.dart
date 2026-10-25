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

  /// Returns null if the user closed the Google account picker.
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();

  /// Permanently deletes the account. Throws [AuthFailure] if the user must
  /// sign in again first.
  Future<void> deleteAccount();

  /// Deleting an account needs a recent sign-in; false means sign in again.
  bool get recentlySignedIn;
}

class FirebaseAuthService implements AuthService {
  final _auth = FirebaseAuth.instance;

  @override
  bool get recentlySignedIn {
    final at = _auth.currentUser?.metadata.lastSignInTime;
    return at != null && DateTime.now().difference(at) < const Duration(minutes: 4);
  }

  bool _googleReady = false;

  @override
  bool get isDemo => false;

  static AppUser? _map(User? u) {
    if (u == null) return null;
    return AppUser(uid: u.uid, method: SignInMethod.google, name: u.displayName, email: u.email);
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> get changes => _auth.authStateChanges().map(_map);

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
      final why = (e.description ?? '').trim();
      throw AuthFailure('Google sign-in failed (${e.code.name}${why.isEmpty ? '' : ': $why'}).');
    } on FirebaseAuthException catch (e) {
      throw AuthFailure('${_failure(e).message} [${e.code}]');
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure('Sign-in problem: $e');
    }
  }

  @override
  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthFailure('For your security, sign out and sign in again, then delete your account.');
      }
      throw _failure(e);
    }
    await signOut();
  }

  static AuthFailure _failure(FirebaseAuthException e) => AuthFailure(switch (e.code) {
    'too-many-requests' => 'Too many attempts. Please wait a few minutes.',
    'network-request-failed' => 'No internet connection.',
    'account-exists-with-different-credential' => 'This email is already linked to another sign-in method.',
    _ => e.message ?? 'Sign-in failed. Please try again.',
  });
}

/// Works without any backend: Google returns a sample account. The session is remembered on the device.
class DemoAuthService implements AuthService {
  @override
  bool get recentlySignedIn => true;

  DemoAuthService(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

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
    return u ?? const AppUser(uid: '', method: SignInMethod.google);
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

  @override
  Future<void> deleteAccount() async => _set(null);
}
