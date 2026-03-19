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

Son güncelleme: Mart 2026

1. Genel Hükümler
AeroCab uygulamasını indirerek veya kullanarak bu sözleşmenin tüm hükümlerini okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan etmiş sayılırsınız. Kabul etmiyorsanız uygulamayı kullanmayınız.

2. Hizmet Kapsamı
AeroCab, yolcular ile sürücüleri bir araya getiren bir dijital aracılık platformudur. AeroCab doğrudan taşımacılık hizmeti sunmamakta olup yolculuk ilişkisi yolcu ile sürücü arasında kurulmaktadır.

3. Kullanıcı Yükümlülükleri
• Kullanıcılar platformu yalnızca yasal amaçlar doğrultusunda kullanmakla yükümlüdür.
• Gerçek dışı kimlik veya iletişim bilgisi vermek kesinlikle yasaktır.
• Sürücüler geçerli sürücü belgesine ve araç sigortasına sahip olmak zorundadır.
• Kullanıcılar diğer kullanıcılara saygılı davranmakla yükümlüdür.

4. Abonelik ve Ödeme Politikası
• Premium abonelik ücretleri App Store üzerinden tahsil edilir.
• Deneme süresi sona erdiğinde abonelik otomatik olarak yenilenir.
• İptal işlemi mevcut dönem bitmeden en az 24 saat önce yapılmalıdır.
• Kullanılmayan dönemler için iade yapılmaz.

5. Sorumluluk Sınırlaması
AeroCab, yolculuk sırasında meydana gelen kaza, kayıp veya zararlardan; sürücünün davranışlarından; üçüncü tarafların eylemlerinden doğan zararlardan sorumlu tutulamaz.

6. Hesap Güvenliği
Hesabınızın güvenliğinden siz sorumlusunuz. Hesabınızın yetkisiz kullanımını fark ederseniz derhal aerocabapp@gmail.com adresine bildirin.

7. Değişiklikler
AeroCab bu sözleşmeyi önceden bildirim yapılmaksızın değiştirme hakkını saklı tutar. Güncel sözleşme her zaman uygulama içinde erişilebilir olacaktır.

8. İletişim
Sorularınız için: aerocabapp@gmail.com''',
          ),
          const SizedBox(height: 16),
          _LegalCard(
            title: 'KVKK Aydınlatma Metni',
            icon: Icons.privacy_tip_outlined,
            content: '''KVKK Aydınlatma Metni

6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında hazırlanmıştır.
Son güncelleme: Mart 2026

1. Veri Sorumlusu
AeroCab, kişisel verilerinizin işlenmesinde veri sorumlusu sıfatını taşımaktadır.
İletişim: aerocabapp@gmail.com

2. İşlenen Kişisel Veriler
• Ad ve soyad
• E-posta adresi
• Telefon numarası
• Konum bilgisi (yolculuk süresince)
• Yolculuk geçmişi
• Araç bilgileri (sürücüler için)
• Uygulama kullanım verileri

3. Kişisel Verilerin İşlenme Amacı
• Hizmetin sağlanması ve yolculuk eşleşmesi
• Hesap güvenliği ve doğrulama
• Yasal yükümlülüklerin yerine getirilmesi
• Hizmet kalitesinin iyileştirilmesi
• Bildirim ve iletişim

4. Verilerin Aktarılması
Kişisel verileriniz; Google Firebase altyapısı ve RevenueCat ödeme altyapısı ile paylaşılmakta olup açık rızanız olmadan üçüncü şahıs pazarlama amaçlı kullanılmamaktadır.

5. Haklarınız
KVKK'nın 11. maddesi kapsamında aşağıdaki haklara sahipsiniz:
• Kişisel verilerinizin işlenip işlenmediğini öğrenme
• İşlenmişse bilgi talep etme
• İşlenme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme
• Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme
• Eksik veya yanlış işlenmiş verilerin düzeltilmesini isteme
• Silinmesini veya yok edilmesini isteme
• İşlemeye itiraz etme

Talepleriniz için: aerocabapp@gmail.com

6. Veri Güvenliği
Verileriniz Google Firebase altyapısı kullanılarak şifrelenerek saklanmaktadır. Firebase, ISO 27001 ve SOC 2/3 sertifikalarına sahiptir.''',
          ),
          const SizedBox(height: 16),
          _LegalCard(
            title: 'Gizlilik Politikası',
            icon: Icons.lock_outline_rounded,
            content: '''Gizlilik Politikası

Son güncelleme: Mart 2026

AeroCab olarak gizliliğinize değer veriyoruz. Bu politika, hangi verileri topladığımızı, nasıl kullandığımızı ve haklarınızı açıklar.

1. Topladığımız Veriler
• Hesap bilgileri: ad, e-posta, telefon
• Konum verisi: yolculuk talep ve teslim noktaları
• Cihaz bilgileri: işletim sistemi, uygulama versiyonu
• Kullanım verileri: açılan ekranlar, yolculuk geçmişi

2. Verilerin Kullanımı
• Yolcu-sürücü eşleşmesi ve yolculuk yönetimi
• Güvenlik doğrulaması ve hesap koruması
• Push bildirimleri
• Uygulama iyileştirme ve hata tespiti

3. Konum Verisi
Konum bilgisi yalnızca aktif yolculuk sırasında ve yolculuk talebinde bulunulduğunda kullanılır. Arka planda sürekli takip yapılmaz.

4. Ödeme Bilgileri
Ödeme işlemleri Apple App Store altyapısı üzerinden gerçekleştirilir. Kart veya ödeme bilgileriniz AeroCab sistemlerinde saklanmaz.

5. Üçüncü Taraf Hizmetler
• Google Firebase: veri depolama ve kimlik doğrulama
• RevenueCat: abonelik yönetimi
• Google Maps: harita ve konum hizmetleri

Bu hizmetler kendi gizlilik politikalarına tabidir.

6. Veri Saklama ve Silme
Hesabınızı sildiğinizde kişisel verileriniz sistemden kaldırılır. Yasal yükümlülükler gerektirmedikçe veriler üçüncü taraflarla paylaşılmaz.

7. İletişim
Gizlilikle ilgili sorularınız için: aerocabapp@gmail.com''',
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
