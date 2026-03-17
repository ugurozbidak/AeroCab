import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/core/database_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.isDriver,
  });

  final Map<String, dynamic> userData;
  final bool isDriver;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _plateCtrl;

  File? _pickedImage;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.userData['fullName'] as String? ?? '');
    _phoneCtrl = TextEditingController(
        text: widget.userData['phone'] as String? ?? '');
    _emailCtrl = TextEditingController(
        text: widget.userData['email'] as String? ??
            FirebaseAuth.instance.currentUser?.email ??
            '');
    _plateCtrl = TextEditingController(
        text: widget.userData['plateNumber'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
    );
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_pickedImage == null) return null;
    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');
      await ref.putFile(_pickedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenemedi: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad Soyad boş bırakılamaz.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    String? photoUrl;
    if (_pickedImage != null) {
      photoUrl = await _uploadPhoto(user.uid);
    }

    final data = <String, dynamic>{
      'fullName': name,
    };

    // Passengers can edit phone
    if (!widget.isDriver) {
      data['phone'] = _phoneCtrl.text.trim();
    }

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    await ref.read(databaseServiceProvider).updateUserData(user.uid, data);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profiliniz güncellendi.')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photoUrl = widget.userData['photoUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider
                        : (photoUrl != null ? NetworkImage(photoUrl) : null),
                    child: _pickedImage == null && photoUrl == null
                        ? Text(
                            (_nameCtrl.text.isNotEmpty
                                    ? _nameCtrl.text
                                    : '?')[0]
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          )
                        : (_uploadingPhoto
                            ? const CircularProgressIndicator()
                            : null),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: Icon(Icons.camera_alt_rounded,
                        size: 16, color: cs.onPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fotoğrafı değiştirmek için dokunun',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 28),

            // Name field
            _ProfileField(
              controller: _nameCtrl,
              label: 'Ad Soyad',
              icon: Icons.person_outline_rounded,
              enabled: true,
            ),
            const SizedBox(height: 14),

            // Email - locked for passengers
            _ProfileField(
              controller: _emailCtrl,
              label: 'E-posta',
              icon: Icons.email_outlined,
              enabled: false,
              lockedNote: 'E-posta adresi değiştirilemez.',
            ),
            const SizedBox(height: 14),

            // Phone - locked for drivers
            _ProfileField(
              controller: _phoneCtrl,
              label: 'Telefon Numarası',
              icon: Icons.phone_outlined,
              enabled: !widget.isDriver,
              keyboardType: TextInputType.phone,
              lockedNote: widget.isDriver
                  ? 'Sürücülerde telefon numarası değiştirilemez.'
                  : null,
            ),

            // Plate - drivers only, locked
            if (widget.isDriver) ...[
              const SizedBox(height: 14),
              _ProfileField(
                controller: _plateCtrl,
                label: 'Plaka',
                icon: Icons.directions_car_outlined,
                enabled: false,
                lockedNote: 'Plaka değiştirilemez. Destek ile iletişime geçin.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.lockedNote,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? lockedNote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: !enabled
                ? Icon(Icons.lock_outline_rounded,
                    size: 18, color: cs.onSurface.withValues(alpha: 0.3))
                : null,
            filled: true,
            fillColor: enabled
                ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                : cs.surfaceContainerHighest.withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (lockedNote != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              lockedNote!,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
