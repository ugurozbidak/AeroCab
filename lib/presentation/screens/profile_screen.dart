import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerocab/core/database_service.dart';
import 'package:aerocab/core/notification_service.dart';
import 'package:aerocab/core/purchases_service.dart';
import 'package:aerocab/features/auth/screens/auth_gate.dart';
import 'package:aerocab/features/auth/services/auth_service.dart';
import 'package:aerocab/presentation/widgets/rating_dialog.dart';
import 'package:aerocab/presentation/screens/app_settings_screen.dart';
import 'package:aerocab/presentation/screens/contact_screen.dart';
import 'package:aerocab/presentation/screens/edit_profile_screen.dart';
import 'package:aerocab/presentation/screens/legal_screen.dart';
import 'package:aerocab/presentation/screens/ride_history_screen.dart';
import 'package:aerocab/presentation/screens/subscription_screen.dart';
import 'package:aerocab/presentation/screens/user_guide_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _isDriver = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db = ref.read(databaseServiceProvider);
    final data = await db.getUserData(user.uid);
    final role = await db.getUserRole(user.uid);
    final isPremium = await PurchasesService.isPremium();
    if (mounted) {
      setState(() {
        _userData = data;
        _isDriver = role == UserRole.driver;
        _isPremium = isPremium;
        _loading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz ve tüm verileriniz silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await ref.read(databaseServiceProvider).deleteUserAccount(user.uid);
      await user.delete();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        await _reauthAndDelete(user);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesap silinemedi: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesap silinemedi: $e')),
        );
      }
    }
  }

  Future<void> _reauthAndDelete(User user) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kimliğinizi Doğrulayın'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hesabınızı silmek için şifrenizi girin.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Devam Et',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(authServiceProvider)
          .reauthenticate(passwordController.text);
      await ref.read(databaseServiceProvider).deleteUserAccount(user.uid);
      await user.delete();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesap silinemedi: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationService().clearToken(uid);
      await PurchasesService.logOut();
    }
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _editProfile() async {
    if (_userData == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          userData: _userData!,
          isDriver: _isDriver,
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _userData?['fullName'] as String? ?? user?.email ?? '';
    final email = _userData?['email'] as String? ?? user?.email ?? '';
    final phone = _userData?['phone'] as String?;
    final photoUrl = _userData?['photoUrl'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar & Info ────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            initials,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isDriver
                          ? Colors.orange.withValues(alpha: 0.15)
                          : cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isDriver ? 'Sürücü' : 'Yolcu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isDriver ? Colors.orange.shade700 : cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (user != null)
                    UserRatingWidget(
                      uid: user.uid,
                      dbService: ref.read(databaseServiceProvider),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Hesabım ──────────────────────────────────────────────────
            _SectionLabel(label: 'Hesabım'),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.edit_outlined,
                  title: 'Profili Düzenle',
                  onTap: _editProfile,
                ),
                const _MenuDivider(),
                _MenuItem(
                  icon: Icons.subscriptions_outlined,
                  title: 'Aboneliğim',
                  subtitle: _isPremium ? 'Aktif' : 'Aktif değil',
                  subtitleColor: _isPremium ? Colors.green : null,
                  onTap: () => _push(const SubscriptionScreen()),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Yolculuk ─────────────────────────────────────────────────
            _SectionLabel(label: 'Yolculuk'),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.history_rounded,
                  title: 'Yolculuk Geçmişi',
                  onTap: () => _push(const RideHistoryScreen()),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Yardım & Destek ──────────────────────────────────────────
            _SectionLabel(label: 'Yardım & Destek'),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.menu_book_outlined,
                  title: 'Kullanım Kılavuzu',
                  onTap: () => _push(const UserGuideScreen()),
                ),
                const _MenuDivider(),
                _MenuItem(
                  icon: Icons.headset_mic_outlined,
                  title: 'Bize Ulaşın',
                  onTap: () => _push(const ContactScreen()),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Yasal ────────────────────────────────────────────────────
            _SectionLabel(label: 'Yasal'),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.gavel_rounded,
                  title: 'Kullanıcı Sözleşmesi & KVKK',
                  onTap: () => _push(const LegalScreen()),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Uygulama ─────────────────────────────────────────────────
            _SectionLabel(label: 'Uygulama'),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Uygulama Ayarları',
                  onTap: () => _push(const AppSettingsScreen()),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Danger zone ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Çıkış Yap'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _deleteAccount,
                child: Text(
                  'Hesabı Sil',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    decoration: TextDecoration.underline,
                    decorationColor: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.4),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: cs.primary, size: 20),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor ?? cs.onSurface.withValues(alpha: 0.5)))
          : null,
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.35), size: 20),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: 56,
      color: cs.outline.withValues(alpha: 0.12),
    );
  }
}
