import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TadarabApp());
}

/// Root widget. Initializes Firebase before showing any real UI, since every
/// screen from Phase B onward depends on Auth/Firestore/Storage being ready.
class TadarabApp extends StatelessWidget {
  const TadarabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tadarab',
      theme: AppTheme.themeData,
      home: const _FirebaseBootstrap(),
    );
  }
}

/// Waits on [Firebase.initializeApp] and shows a retry option on failure,
/// per the NFR that no network/API call may fail silently or freeze the UI.
class _FirebaseBootstrap extends StatefulWidget {
  const _FirebaseBootstrap();

  @override
  State<_FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<_FirebaseBootstrap> {
  late Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  void _retry() {
    setState(() {
      _initialization = Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not connect to Tadarab services.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const _AuthGate();
      },
    );
  }
}

/// Routes between signed-out (the auth flow) and signed-in. There's no Home
/// screen yet — Home & Courses is a separate design handoff not built in
/// this pass — so a signed-in student sees a temporary placeholder rather
/// than nothing reachable after a successful login/create-account.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const WelcomeScreen();
        return _SignedInPlaceholder(
          email: user.email ?? '',
          onSignOut: () => authService.signOut(),
        );
      },
    );
  }
}

class _SignedInPlaceholder extends StatelessWidget {
  const _SignedInPlaceholder({required this.email, required this.onSignOut});

  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in as $email'),
            const SizedBox(height: 12),
            const Text('Home screen coming in the next design handoff.'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onSignOut, child: const Text('Log out')),
          ],
        ),
      ),
    );
  }
}
