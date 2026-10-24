/// Google is the only sign-in method. (Older saved sessions may say
/// "phone"; they are read as Google.)
enum SignInMethod { google }

class AppUser {
  const AppUser({required this.uid, required this.method, this.name, this.email});

  final String uid;
  final SignInMethod method;
  final String? name;
  final String? email;

  /// What to show as the account identifier.
  String get handle => email ?? 'Signed in';

  Map<String, dynamic> toJson() => {'uid': uid, 'method': method.name, 'name': ?name, 'email': ?email};

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    uid: j['uid'] as String,
    method: SignInMethod.google,
    name: j['name'] as String?,
    email: j['email'] as String?,
  );
}

/// A user-facing sign-in error.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
