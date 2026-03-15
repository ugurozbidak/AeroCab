import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/database_service.dart';
import 'package:myapp/core/notification_service.dart';
import 'package:myapp/features/auth/screens/login_screen.dart';
import 'package:myapp/presentation/screens/home_screen.dart';
import 'package:myapp/features/subscription/screens/subscription_paywall_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // Initialize notifications and check for subscription
        return FutureBuilder<bool>(
          future: _initServicesAndCheckSubscription(ref, user.uid),
          builder: (context, servicesSnapshot) {
            if (servicesSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (servicesSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${servicesSnapshot.error}')),
              );
            }

            final hasSubscription = servicesSnapshot.data ?? false;

            if (hasSubscription) {
              return const HomeScreen();
            } else {
              return const SubscriptionPaywallScreen();
            }
          },
        );
      },
    );
  }

  Future<bool> _initServicesAndCheckSubscription(
    WidgetRef ref,
    String userId,
  ) async {
    // Initialize notifications and save FCM token
    await NotificationService().initNotifications(userId);

    // Check for active subscription
    final hasSubscription = await ref
        .read(databaseServiceProvider)
        .hasActiveSubscription(userId);

    return hasSubscription;
  }
}
