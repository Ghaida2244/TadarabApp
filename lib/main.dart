import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
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
        return const Scaffold(
          body: Center(child: Text('Tadarab — Phase A backend ready')),
        );
      },
    );
  }
}
