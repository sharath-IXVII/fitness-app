enum SignInMethod { phone, google }

class AppUser {
  const AppUser({required this.uid, required this.method, this.name, this.email, this.phone});

  final String uid;
  final SignInMethod method;
  final String? name;
  final String? email;
  final String? phone;

  /// What to show as the account identifier.
  String get handle => email ?? phone ?? 'Signed in';

  Map<String, dynamic> toJson() => {'uid': uid, 'method': method.name, 'name': ?name, 'email': ?email, 'phone': ?phone};

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    uid: j['uid'] as String,
    method: SignInMethod.values.byName(j['method'] as String),
    name: j['name'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
  );
}

/// A user-facing sign-in error.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of asking for an SMS code.
class CodeSent {
  const CodeSent({this.verificationId, this.resendToken, this.autoSignedIn});

  final String? verificationId;
  final int? resendToken;

  /// Set when Android read the SMS itself and sign-in already finished.
  final AppUser? autoSignedIn;
}
