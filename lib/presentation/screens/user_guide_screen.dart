import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  static const _passengerSteps = [
    (
      icon: Icons.app_registration_rounded,
      title: 'Kayıt & Giriş',
      desc:
          'Uygulamayı indirin, e-posta adresinizle kayıt olun ve giriş yapın.',
    ),
    (
      icon: Icons.flight_takeoff_rounded,
      title: 'Yolculuk Türü Seçin',
      desc:
          '"Evden Terminale" veya "Terminalden Eve" seçeneklerinden birini seçin.',
    ),
    (
      icon: Icons.people_rounded,
      title: 'Yolcu Sayısı',
      desc:
          '1 Kişi, 2 Kişi veya Aile seçeneğini belirleyin. 2 kişilik yolculuklarda sürücü uygun 2. yolcu arar.',
    ),
    (
      icon: Icons.location_on_rounded,
      title: 'Konum Belirleyin',
      desc:
          'Haritadan alınış veya varış noktanızı seçin. Kayıtlı adreslerinizi de kullanabilirsiniz.',
    ),
    (
      icon: Icons.payments_outlined,
      title: 'Fiyat Görüntüleme',
      desc:
          'Konumunuza göre tahmini fiyat otomatik olarak hesaplanır.',
    ),
    (
      icon: Icons.directions_car_rounded,
      title: 'Yolculuk Talep Et',
      desc:
          '"Yolculuk Talep Et" butonuna basın. Sürücü kabul ettiğinde bildirim alırsınız.',
    ),
  ];

  static const _driverSteps = [
    (
      icon: Icons.login_rounded,
      title: 'Sürücü Girişi',
      desc: 'Sürücü hesabınızla giriş yapın.',
    ),
    (
      icon: Icons.wifi_rounded,
      title: 'Çevrimiçi Olun',
      desc:
          'Ana paneldeki butona dokunarak çevrimiçi olun. Konum paylaşımı başlar.',
    ),
    (
      icon: Icons.notifications_active_rounded,
      title: 'Yolculuk Talepleri',
      desc:
          'Yeni yolculuk talepleri sesli ve titreşimli bildirimle gelir. Kabul etmek için "Kabul Et" butonuna basın.',
    ),
    (
      icon: Icons.person_pin_rounded,
      title: 'Yolcuyu Alın',
      desc:
          'Yolcunun adı ve telefonu ekranda görünür. Navigasyonu başlatın ve yolcuyu alın.',
    ),
    (
      icon: Icons.flag_rounded,
      title: 'Yolculuğu Tamamlayın',
      desc:
          'Varış noktasına ulaştığınızda "Yolculuğu Tamamla" butonuna basın.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanım Kılavuzu'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: 'Yolcu Rehberi', icon: Icons.person_rounded, color: cs.primary),
          const SizedBox(height: 12),
          ..._passengerSteps.indexed.map(
            (e) => _StepCard(
              step: e.$1 + 1,
              icon: e.$2.icon,
              title: e.$2.title,
              desc: e.$2.desc,
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Sürücü Rehberi', icon: Icons.drive_eta_rounded, color: Colors.orange),
          const SizedBox(height: 12),
          ..._driverSteps.indexed.map(
            (e) => _StepCard(
              step: e.$1 + 1,
              icon: e.$2.icon,
              title: e.$2.title,
              desc: e.$2.desc,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, required this.color});
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.desc,
    this.color,
  });
  final int step;
  final IconData icon;
  final String title;
  final String desc;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: c,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: c),
                    const SizedBox(width: 6),
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
