import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bize Ulaşın'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Icon(Icons.support_agent_rounded,
                      size: 56, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Size yardımcı olmaktan mutluluk duyarız.',
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ContactTile(
              icon: Icons.email_outlined,
              title: 'E-posta',
              subtitle: 'aerocabapp@gmail.com',
              onTap: () => _launch('mailto:aerocabapp@gmail.com'),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.phone_outlined,
              title: 'Telefon',
              subtitle: '+90 530 353 07 72',
              onTap: () => _launch('tel:+905303530772'),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'WhatsApp',
              subtitle: '+90 530 353 07 72',
              onTap: () => _launch('https://wa.me/905303530772'),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.schedule_rounded,
              title: 'Çalışma Saatleri',
              subtitle: 'Pazartesi – Pazar, 08:00 – 22:00',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        title: Text(title,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
        trailing: onTap != null
            ? Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.4))
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
