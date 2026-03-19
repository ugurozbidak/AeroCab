import 'package:flutter/material.dart';
import 'package:aerocab/main.dart';
import 'package:provider/provider.dart' as old_provider;

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = old_provider.Provider.of<ThemeProvider>(context);
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            brightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uygulama Ayarları'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Görünüm',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Karanlık Mod',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: cs.outline.withValues(alpha: 0.1),
                  ),
                  _SettingsTile(
                    icon: Icons.brightness_auto_rounded,
                    title: 'Sistem Temasını Kullan',
                    trailing: Switch(
                      value: themeProvider.themeMode == ThemeMode.system,
                      onChanged: (val) {
                        if (val) {
                          themeProvider.setThemeMode(ThemeMode.system);
                        } else {
                          themeProvider.setThemeMode(isDark
                              ? ThemeMode.dark
                              : ThemeMode.light);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bildirimler',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Bildirim Ayarları',
                subtitle: 'Sistem bildirim ayarlarını aç',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Bildirimler için sistem ayarlarını kullanın.',
                      ),
                    ),
                  );
                },
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)))
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
