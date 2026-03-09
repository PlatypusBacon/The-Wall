import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  User? get currentUser => supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  // ── Email & password ──────────────────────────────────────────────────────

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // Debug: verify values arriving at the service
    print('=== SIGNUP DEBUG ===');
    print('email: "$email"');
    print('username: "$username"');
    print('username isEmpty: ${username.isEmpty}');
    print('username trimmed: "${username.trim()}"');

    if (username.trim().isEmpty) {
      throw Exception('Username cannot be empty');
    }

    final existing = await supabase
        .from('profiles')
        .select('username')
        .eq('username', username.trim())
        .maybeSingle();

    print('existing username check result: $existing');

    if (existing != null) throw Exception('Username already taken');

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username.trim()},
      );
      print('Sign up response: $response');
    } catch (e, stack) {
      print('Sign up failed: $e');
      print(stack);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  // ── Google ────────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled

    final googleAuth = await googleUser.authentication;
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );

    // Create profile if first Google sign-in (trigger won't have a username)
    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();

    if (profile == null) {
      // Derive a username from their Google display name
      final base = (googleUser.displayName ?? 'climber')
          .toLowerCase()
          .replaceAll(' ', '_');
      await _ensureUniqueProfile(base);
    }
  }

  Future<void> _ensureUniqueProfile(String base) async {
    String username = base;
    int suffix = 1;
    while (true) {
      final existing = await supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      if (existing == null) break;
      username = '${base}_$suffix';
      suffix++;
    }
    await supabase.from('profiles').insert({
      'id': currentUser!.id,
      'username': username,
    });
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<String?> getUsername() async {
    if (!isLoggedIn) return null;
    final data = await supabase
        .from('profiles')
        .select('username')
        .eq('id', currentUser!.id)
        .maybeSingle();
    return data?['username'] as String?;
  }
}