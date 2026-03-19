# AeroCab

THY personeline özel havalimanı transfer uygulaması. Yolcular yolculuk talep eder, sürücüler talepleri kabul eder.

## Özellikler

**Yolcu**
- `@thy.com` e-posta adresiyle kayıt ve e-posta doğrulama
- Haritadan alınış ve varış noktası seçimi
- 15 dakikalık zaman dilimleriyle yolculuk planlaması (en az 90 dakika öncesinden)
- Aktif yolculuk takibi ve araç animasyonu
- Sürücü puanlama sistemi
- Kayıtlı adres yönetimi

**Sürücü**
- Çevrimiçi / çevrimdışı modu
- Yeni taleplerde tam ekran sesli ve titreşimli uyarı
- Basılı tut ile talep kabul (1 saniye)
- Yolculuk durum yönetimi (yola çıktım → alındı → tamamlandı)
- Kazanç takibi
- Yolcu puanlama sistemi

**Abonelik & Bildirimler**
- RevenueCat entegrasyonu (App Store üzerinden gerçek ödeme)
- 7 günlük ücretsiz deneme, aylık ve yıllık plan seçenekleri (sürücü / yolcu)
- Firebase Cloud Functions ile push bildirim zinciri:
  - Yeni rezervasyonda tüm çevrimiçi sürücülere bildirim
  - Kabul, yola çıkma, yolculuk başlangıcı ve tamamlanma bildirimleri
  - İptal durumunda sürücü ve yolcuya ayrı bildirimler

## Teknolojiler

| Katman | Teknoloji |
|--------|-----------|
| Mobil | Flutter / Dart |
| Auth | Firebase Auth (e-posta + şifre, e-posta doğrulama) |
| Veritabanı | Cloud Firestore |
| Depolama | Firebase Storage |
| Backend | Firebase Cloud Functions (Node.js, europe-west1) |
| Harita | Google Maps Flutter |
| Adres | OpenStreetMap Nominatim |
| Durum Yönetimi | Flutter Riverpod |
| Bildirimler | Firebase Cloud Messaging + Flutter Local Notifications |
| Abonelik | RevenueCat (`purchases_flutter`) |

## Kurulum

### Gereksinimler
- Flutter 3.x
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js 18+

### Adımlar

1. Repoyu klonla:
   ```bash
   git clone https://github.com/ugurozbidak/AeroCab.git
   cd AeroCab
   ```

2. Bağımlılıkları yükle:
   ```bash
   flutter pub get
   ```

3. Firebase yapılandırması:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`

4. Cloud Functions'ı deploy et:
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

5. Firestore kural ve indexlerini deploy et:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

6. Uygulamayı çalıştır:
   ```bash
   flutter run
   ```

## Abonelik Planları

| Plan | Aylık | Yıllık |
|------|-------|--------|
| Yolcu | 299,99 ₺ | — |
| Sürücü | 299,99 ₺ | — |

- Tüm planlarda **7 gün ücretsiz** deneme
- Yıllık planda **2 ay ücretsiz** (yapılandırıldığında)
- Abonelik App Store üzerinden yönetilir

## İletişim

**Destek:** aerocabapp@gmail.com
**Telefon / WhatsApp:** +90 530 353 07 72
