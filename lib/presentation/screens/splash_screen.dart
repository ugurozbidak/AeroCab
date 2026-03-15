import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/database_service.dart';
import 'package:myapp/features/auth/screens/auth_gate.dart';
import 'package:myapp/features/subscription/screens/subscription_paywall_screen.dart';
import 'package:myapp/presentation/screens/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        // User is signed out
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      } else {
        // User is signed in, check for active subscription
        _checkSubscriptionAndNavigate(user.uid);
      }
    });
  }

  Future<void> _checkSubscriptionAndNavigate(String uid) async {
    final hasActiveSub = await ref
        .read(databaseServiceProvider)
        .hasActiveSubscription(uid);
    if (mounted) {
      // Check if the widget is still in the tree
      if (hasActiveSub) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SubscriptionPaywallScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
