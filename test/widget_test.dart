import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database_service.dart';
import 'package:myapp/features/auth/screens/login_screen.dart';
import 'package:myapp/features/auth/screens/register_screen.dart';

Widget wrapWithProviders(Widget child) {
  return ProviderScope(child: MaterialApp(home: child));
}

void main() {
  group('LoginScreen', () {
    testWidgets('Login formu görüntülenir', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const LoginScreen()));

      expect(find.text('Login'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Boş form submit edildiğinde validation hatası gösterilir',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const LoginScreen()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Register sayfasına geçiş butonu mevcut',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const LoginScreen()));

      expect(find.text("Don't have an account? Register"), findsOneWidget);
    });

    testWidgets('Email ve şifre alanlarına metin girilebilir',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const LoginScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123456');

      expect(find.text('test@test.com'), findsOneWidget);
    });
  });

  group('RegisterScreen', () {
    testWidgets('Register formu görüntülenir', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const RegisterScreen()));

      expect(find.text('Register'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Boş form submit edildiğinde validation hataları gösterilir',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const RegisterScreen()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Kullanıcı rolü dropdown mevcut', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const RegisterScreen()));

      expect(find.byType(DropdownButtonFormField<UserRole>), findsOneWidget);
      expect(find.text('Passenger'), findsOneWidget);
    });

    testWidgets('Login sayfasına dönüş butonu mevcut',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const RegisterScreen()));

      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('Tüm alanlara metin girilebilir', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const RegisterScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'John Doe');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'john@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'secret123');

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('john@example.com'), findsOneWidget);
    });
  });
}
