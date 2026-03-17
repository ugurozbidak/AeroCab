import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yasal Bilgiler'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LegalCard(
            title: 'Kullanıcı Sözleşmesi',
            icon: Icons.description_outlined,
            content: '''AeroCab Kullanıcı Sözleşmesi

Son güncelleme: Mart 2025

1. Genel Hükümler
AeroCab uygulamasını kullanarak bu sözleşmenin tüm hükümlerini kabul etmiş sayılırsınız.

2. Hizmet Kapsamı
AeroCab, yolcular ile sürücüleri bir araya getiren bir aracılık platformudur. Şirketimiz doğrudan taşımacılık hizmeti sunmamaktadır.

3. Kullanıcı Yükümlülükleri
Kullanıcılar, platformu yasal amaçlar doğrultusunda kullanmakla yükümlüdür. Gerçek dışı bilgi vermek yasaktır.

4. Ödeme ve İptal Politikası
Yolculuk ücretleri sürücü ile yolcu arasında anlaşmaya göre belirlenir. İptal politikaları uygulama içinde belirtilmiştir.

5. Sorumluluk Sınırlaması
AeroCab, yolculuk sırasında meydana gelen olaylardan doğan zararlardan sorumlu tutulamaz.

6. Değişiklikler
Bu sözleşme önceden bildirim yapılmaksızın değiştirilebilir.''',
          ),
          const SizedBox(height: 16),
          _LegalCard(
            title: 'KVKK Aydınlatma Metni',
            icon: Icons.privacy_tip_outlined,
            content: '''KVKK Aydınlatma Metni

6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca hazırlanmıştır.

1. Veri Sorumlusu
AeroCab, kişisel verilerinizin işlenmesinde veri sorumlusu sıfatını taşımaktadır.

2. İşlenen Kişisel Veriler
• Ad-Soyad
• E-posta adresi
• Telefon numarası
• Konum bilgisi
• Yolculuk geçmişi

3. Kişisel Verilerin İşlenme Amacı
Verileriniz; hizmet sunumu, güvenlik, yasal yükümlülükler ve hizmet kalitesinin iyileştirilmesi amacıyla işlenmektedir.

4. Haklarınız
KVKK kapsamında kişisel verilerinize erişim, düzeltme, silme ve itiraz haklarına sahipsiniz. Talepleriniz için: kvkk@aerocab.com

5. Veri Güvenliği
Verileriniz Firebase altyapısı kullanılarak güvenli şekilde saklanmaktadır.''',
          ),
          const SizedBox(height: 16),
          _LegalCard(
            title: 'Gizlilik Politikası',
            icon: Icons.lock_outline_rounded,
            content: '''Gizlilik Politikası

AeroCab olarak gizliliğinize değer veriyoruz. Topladığımız veriler yalnızca hizmetin sağlanması amacıyla kullanılmakta ve üçüncü taraflarla paylaşılmamaktadır.

• Konum verileriniz yalnızca aktif yolculuk süresince kullanılır.
• Ödeme bilgileriniz uygulama içinde saklanmaz.
• Verilerinizi istediğiniz zaman silebilirsiniz.

Daha fazla bilgi için: gizlilik@aerocab.com''',
          ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatefulWidget {
  const _LegalCard({
    required this.title,
    required this.icon,
    required this.content,
  });
  final String title;
  final IconData icon;
  final String content;

  @override
  State<_LegalCard> createState() => _LegalCardState();
}

class _LegalCardState extends State<_LegalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
