import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerocab/core/notification_service.dart';
import 'package:aerocab/core/purchases_service.dart';
import 'package:aerocab/features/auth/screens/email_verification_screen.dart';
import 'package:aerocab/features/auth/screens/login_screen.dart';
import 'package:aerocab/presentation/screens/home_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        if (!snapshot.data!.emailVerified) {
          return const EmailVerificationScreen();
        }

        NotificationService().init(snapshot.data!.uid).catchError((_) {});

        PurchasesService.logIn(snapshot.data!.uid).catchError((_) {});

        return const HomeScreen();
      },
    );
  }
}
