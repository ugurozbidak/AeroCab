# AeroCab

THY personeline özel havalimanı transfer uygulaması. Yolcular yolculuk talep eder, sürücüler talepleri kabul eder.

## Özellikler

**Yolcu**
- @thy.com e-posta adresiyle kayıt
- Haritadan alınış ve varış noktası seçimi
- 15 dakikalık zaman dilimleriyle yolculuk planlaması (en az 90 dakika öncesinden)
- Aktif yolculuk takibi ve araç animasyonu
- Sürücü puanlama sistemi
- Kayıtlı adres yönetimi

**Sürücü**
- Çevrimiçi/çevrimdışı modu
- Yeni taleplerde tam ekran sesli ve titreşimli uyarı
- Basılı tut ile talep kabul (1 saniye)
- Yolculuk durum yönetimi (yola çıktım, alındı, tamamlandı)
- Kazanç takibi
- Yolcu puanlama sistemi

**Genel**
- Firebase Auth ile e-posta/şifre girişi
- 7 günlük ücretsiz deneme aboneliği
- Aylık ve yıllık abonelik seçenekleri (sürücü / yolcu)

## Teknolojiler

- Flutter / Dart
- Firebase Auth, Firestore, Storage, Cloud Functions
- Google Maps Flutter
- OpenStreetMap Nominatim (adres arama ve ters geocoding)
- Flutter Riverpod
- Flutter Local Notifications

## Kurulum

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
   - `google-services.json` dosyasını `android/app/` altına ekle
   - `GoogleService-Info.plist` dosyasını `ios/Runner/` altına ekle

4. Uygulamayı çalıştır:
   ```bash
   flutter run
   ```

## Abonelik

Abonelik sistemi şu an Firestore üzerinden test edilmektedir. App Store Connect entegrasyonu tamamlandığında RevenueCat ile gerçek ödeme akışına geçilecektir.

| Plan | Aylık | Yıllık |
|------|-------|--------|
| Yolcu | 49 ₺ | 490 ₺ |
| Sürücü | 299 ₺ | 2.990 ₺ |

Yıllık planda 2 ay ücretsiz, tüm planlarda 7 gün ücretsiz deneme.
