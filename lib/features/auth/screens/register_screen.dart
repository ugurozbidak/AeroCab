import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/core/database_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  UserRole _userRole = UserRole.passenger;
  File? _photoFile;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  // ── Fotoğraf seç ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (picked != null && mounted) {
      setState(() => _photoFile = File(picked.path));
    }
  }

  // ── Kayıt ol ──────────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir profil fotoğrafı seçin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. E-posta + şifre ile kayıt
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user!;

      // 2. E-posta doğrulama maili gönder
      await user.sendEmailVerification();

      // 3. Profil fotoğrafı yükle (başarısız olsa kayıt devam eder)
      String? photoUrl;
      if (_photoFile != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_photos/${user.uid}.jpg');
          await storageRef.putFile(_photoFile!);
          photoUrl = await storageRef.getDownloadURL();
        } catch (e) {
          debugPrint('Fotoğraf yüklenemedi: $e');
        }
      }

      // 4. Firestore kullanıcı dokümanı
      await ref.read(databaseServiceProvider).createUser(
            user.uid,
            _fullNameController.text.trim(),
            _emailController.text.trim(),
            _userRole,
            phone: _phoneController.text.trim(),
            plate: _userRole == UserRole.driver
                ? _plateController.text.trim().toUpperCase()
                : null,
            photoUrl: photoUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hesabınız oluşturuldu! E-posta adresinizi doğrulayın.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authError(e.code))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullanın.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'invalid-verification-code':
        return 'Doğrulama kodu hatalı.';
      case 'credential-already-in-use':
        return 'Bu telefon numarası zaten kullanımda.';
      default:
        return 'Bir hata oluştu: $code';
    }
  }

  // ── Dekorasyon ─────────────────────────────────────────────────────────────
  InputDecoration _dec(String label, IconData icon, ColorScheme cs,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDriver = _userRole == UserRole.driver;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.flight_takeoff_rounded, size: 40, color: cs.primary),
              const SizedBox(height: 18),
              Text(
                'Hesap Oluştur',
                style: tt.displayLarge?.copyWith(
                  fontSize: 32,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AeroCab\'e katılın',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 28),

              // ── Profil Fotoğrafı ─────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: cs.surfaceContainerHighest,
                        backgroundImage: _photoFile != null
                            ? FileImage(_photoFile!)
                            : null,
                        child: _photoFile == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 48,
                                color: cs.onSurface.withValues(alpha: 0.3),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: cs.surface, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _photoFile == null
                        ? 'Profil fotoğrafı seçin (zorunlu)'
                        : 'Fotoğraf seçildi ✓',
                    style: TextStyle(
                      fontSize: 12,
                      color: _photoFile == null
                          ? cs.error
                          : Colors.green.shade600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Ad Soyad
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Ad Soyad', Icons.person_outline, cs),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Adınızı ve soyadınızı girin'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // E-posta
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec('E-posta', Icons.email_outlined, cs),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'E-posta adresinizi girin';
                        }
                        if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                        if (_userRole == UserRole.passenger &&
                            !v.trim().toLowerCase().endsWith('@thy.com')) {
                          return 'Yolcu kaydı için @thy.com e-postası gereklidir';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Şifre
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _dec('Şifre', Icons.lock_outline, cs)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Şifrenizi girin';
                        if (v.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Telefon (+90 prefix)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      decoration: _dec(
                        'Telefon Numarası',
                        Icons.phone_outlined,
                        cs,
                        hint: '5XX XXX XX XX',
                      ).copyWith(
                        counterText: '',
                        prefixIcon: null,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 8),
                          child: Text(
                            '+90',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Telefon numaranızı girin';
                        }
                        if (v.trim().length < 10) {
                          return '10 haneli numara girin (5XX...)';
                        }
                        if (!v.startsWith('5')) {
                          return 'Numara 5 ile başlamalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Kullanıcı Tipi
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          _RoleTab(
                            label: 'Yolcu',
                            icon: Icons.person_rounded,
                            selected: _userRole == UserRole.passenger,
                            onTap: () =>
                                setState(() => _userRole = UserRole.passenger),
                          ),
                          _RoleTab(
                            label: 'Sürücü',
                            icon: Icons.drive_eta_rounded,
                            selected: _userRole == UserRole.driver,
                            onTap: () =>
                                setState(() => _userRole = UserRole.driver),
                          ),
                        ],
                      ),
                    ),

                    // Plaka (sadece sürücü)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      child: isDriver
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: TextFormField(
                                controller: _plateController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9 ]')),
                                  UpperCaseTextFormatter(),
                                ],
                                decoration: _dec(
                                  'Araç Plakası',
                                  Icons.directions_car_outlined,
                                  cs,
                                  hint: '34 ABC 123',
                                ),
                                validator: isDriver
                                    ? (v) => (v == null || v.trim().isEmpty)
                                        ? 'Araç plakasını girin'
                                        : null
                                    : null,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 28),

                    // Kayıt Ol butonu
                    if (_isLoading)
                      const SizedBox(
                        height: 52,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Kayıt Ol',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Zaten hesabınız var mı? Giriş yapın',
                        style: TextStyle(color: cs.primary, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rol seçici tab ────────────────────────────────────────────────────────────
class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Büyük harf formatter ──────────────────────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
