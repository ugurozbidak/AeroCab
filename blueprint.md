# AeroCab Proje Anayasası

Bu doküman, AeroCab mobil uygulamasının iş mantığını, veritabanı şemasını, durum makinelerini ve abonelik modellerini tanımlar. Tüm geliştirme süreci bu kurallara sıkı sıkıya bağlı kalacaktır.

## 1. VİZYON VE PROJE ÖZETİ
AeroCab, havalimanı ve şehir içi transferler için tasarlanmış kapalı devre, abonelik tabanlı bir "Premium Transfer ve Havuz (Pool) Yolculuk" platformudur. İki ayrı kullanıcı rolü (Yolcu ve Şoför) tek bir kod tabanında (Flutter) çalışır.

## 2. TEKNOLOJİ YIĞINI (TECH STACK)
- **Frontend:** Flutter (Dart) - iOS ve Android desteği.
- **Backend & Veritabanı:** Firebase Cloud Firestore (NoSQL), Firebase Authentication.
- **Backend Mantığı:** Firebase Cloud Functions (Node.js/TypeScript).
- **Gerçek Zamanlı Dinleme:** Firestore `onSnapshot()` listeners.
- **Push Notifications:** Firebase Cloud Messaging (FCM).
- **Ödeme / Abonelik (IAP):** Apple App Store & Google Play Store (RevenueCat).
- **Harita:** Google Maps URL Launcher ve `geolocator`.

## 3. İŞ MODELİ: ABONELİK VE "THE GUARD" (PAYWALL)
### 3.1. Abonelik Ücretleri ve Paketler
- **Şoför (Driver):** Aylık 299.90 TL | Yıllık 2990 TL
- **Yolcu (Passenger):** Aylık 49.90 TL | Yıllık 499 TL
- **Deneme Süresi:** Market üzerinden 15 günlük ücretsiz deneme (Free Trial).

### 3.2. "The Guard" Algoritması (Erişim Kontrolü)
1.  Uygulama açıldığında `FirebaseAuth.instance.currentUser` kontrolü yapılır.
2.  Token varsa, Firestore'daki `subscriptions` koleksiyonundan kullanıcının UID'sine ait aktif (`isActive == true`) ve süresi dolmamış (`endDate > Timestamp.now()`) paketi sorgulanır.
3.  Abonelik yoksa/bitmişse: Kullanıcı `SubscriptionPaywallScreen` ekranına kilitlenir. Hiçbir `Navigator.push` işlemine izin verilmez.

## 4. VERİTABANI ŞEMASI (CLOUD FIRESTORE - NOSQL)
**Önemli Uyarı:** Read maliyetlerini düşürmek için `reservations` koleksiyonunda "Denormalization" yapılmıştır. Şoför, yolcu verisini çekmek için ekstra okuma yapmamalıdır.

- **Collection: `users`** (Document ID = Firebase Auth UID)
    - `email`, `phone`, `fullName` (String)
    - `userType` (String: 'driver' | 'passenger')
    - `fcmToken` (String)
    - `createdAt` (Firestore Timestamp)

- **Collection: `passengers`** (Document ID = Firebase Auth UID - 1:1 mapping with `users`)
    - `employeeId`, `department` (String)
    - `homeAddress` (String), `homeLat`, `homeLng` (Double)

- **Collection: `drivers`** (Document ID = Firebase Auth UID - 1:1 mapping with `users`)
    - `vehiclePlate`, `licenseNumber` (String)
    - `isOnline`, `isApproved` (Boolean)

- **Collection: `reservations`** (Document ID = Auto-generated ID)
    - `passengerId` (String - ref to Auth UID)
    - `driverId` (String - ref to Auth UID, null if unassigned)
    - **[DENORMALIZED DATA]:** `passengerName`, `passengerPhone` (String)
    - `pickupLat`, `pickupLng`, `dropoffLat`, `dropoffLng` (Double)
    - `status` (String: 'created', 'accepted', 'on_route', 'completed', 'cancelled')
    - `isPool` (Boolean), `poolPartnerId` (String, null if single)
    - **Zamanlar:** `scheduledTime`, `pickupTime`, `dropoffTime` (Firestore Timestamp)
    - **Finans:** `basePrice`, `finalPrice`, `poolPrice` (Number)

- **Collection: `subscriptions`** (Document ID = Auto-generated)
    - `userId` (String), `planType` (String), `startDate`, `endDate` (Timestamp), `isActive` (Boolean).

## 5. ÇEKİRDEK ALGORİTMALAR (CORE BUSINESS LOGIC)
### 5.1. Timezone Algoritması
- **Kayıt:** Cihazın lokal `DateTime` objesi Firestore'a yazılırken otomatik olarak `Timestamp`'e dönüşür.
- **Okuma (UI):** `(doc.data()['scheduledTime'] as Timestamp).toDate().toLocal()` kullanılarak kullanıcının cihaz saatine çevrilir ve `intl` paketiyle gösterilir.

### 5.2. Havuz (Pool) Eşleştirme Motoru
- `reservations` koleksiyonunda `isPool == true` ve `status == 'created'` olan kayıtlar sorgulanır. Rota yönü ve zaman (max 30 dk fark) eşleşirse, kayıtlar `poolPartnerId` ile birleştirilir.

### 5.3. Anti-Spam / Race Condition Koruması
- **Yolcu (Anti-Spam):** Aktif bir rezervasyonu (`created`, `accepted`, `on_route`) olan yolcu yeni bir rezervasyon oluşturamaz.
- **Şoför (Race Condition):** İki şoförün aynı işi kabul etmesini önlemek için **Firestore Transaction** kullanılır. Transaction içinde `status` kontrolü yapılarak atomik bir şekilde `accepted` durumuna güncellenir.

### 5.4. Telefon Formatlama Algoritması
- `+90` ülke kodunu içerecek şekilde telefon numaraları normalize edilir.

## 6. DURUM MAKİNESİ (STATE MACHINE) VE EKRANLAR
- `created`: Havuzda listelenir (real-time).
- `accepted`: Şoför kabul etti.
- `on_route`: Şoför "Yola Çıktım" dedi. (Yolcuya FCM bildirimi gider).
- `completed`: Şoför "Tamamla" dedi.

**Not:** Şoför `accepted` veya `on_route` durumundayken `PopScope` ile detay ekranından çıkışı kilitlenir.

## 7. GÜVENLİK (FIRESTORE SECURITY RULES)
- **Kural 1:** Kullanıcılar sadece kendi dökümanlarını okuyabilir/yazabilir.
- **Kural 2:** Şoförler, `status == 'created'` olan tüm rezervasyonları okuyabilir, ancak yalnızca `status`'u `accepted` yapacak şekilde update yapabilirler.
- **Kural 3:** `subscriptions` koleksiyonu client tarafından sadece okunabilir. Yazma işlemleri sadece Cloud Functions (Admin SDK) ile yapılır.
