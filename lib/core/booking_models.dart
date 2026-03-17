import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─── Kayıtlı Adres ──────────────────────────────────────────────────────────
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
  });

  final String id;
  final String name;
  final String address;
  final LatLng location;
}

enum RideType { homeToTerminal, terminalToHome }

enum PassengerCount { one, two, family }

// ─── Terminal Konumu ────────────────────────────────────────────────────────
const kTerminalLatLng = LatLng(41.249570, 28.720001);
const kTerminalAddress = 'Ekip Terminali';

// ─── Fiyatlandırma Noktası ──────────────────────────────────────────────────
// Her bölgenin merkez koordinatı ve fiyatı.
// priceFamily null ise UI'da "Fiyat için iletişime geçin" gösterilir.
class PricingPoint {
  const PricingPoint({
    required this.name,
    required this.lat,
    required this.lng,
    required this.priceOne,
    required this.priceTwo,
  });

  final String name;
  final double lat;
  final double lng;
  final double priceOne;
  final double priceTwo;
}

// ─── Bölge Veritabanı ───────────────────────────────────────────────────────
const List<PricingPoint> kPricingPoints = [
  // ── Arnavutköy ──────────────────────────────────────────────────────────
  PricingPoint(name: 'Arnavutköy', lat: 41.1869, lng: 28.7393, priceOne: 500, priceTwo: 700),

  // ── Göktürk ─────────────────────────────────────────────────────────────
  PricingPoint(name: 'Göktürk', lat: 41.1820, lng: 28.8175, priceOne: 600, priceTwo: 700),

  // ── Kemerburgaz ─────────────────────────────────────────────────────────
  PricingPoint(name: 'Kemerburgaz', lat: 41.1903, lng: 28.8725, priceOne: 650, priceTwo: 800),

  // ── Kayaşehir ───────────────────────────────────────────────────────────
  PricingPoint(name: 'Kayaşehir', lat: 41.0835, lng: 28.7557, priceOne: 800, priceTwo: 800),

  // ── Başakşehir / Hadımköy ───────────────────────────────────────────────
  PricingPoint(name: 'Başakşehir', lat: 41.0920, lng: 28.8044, priceOne: 850, priceTwo: 1100),
  PricingPoint(name: 'Hadımköy',   lat: 41.2100, lng: 28.7035, priceOne: 850, priceTwo: 1100),

  // ── Halkalı ─────────────────────────────────────────────────────────────
  PricingPoint(name: 'Halkalı', lat: 41.0190, lng: 28.7950, priceOne: 900, priceTwo: 1200),

  // ── Merkez Bölgeler (900 TL Grubu) ──────────────────────────────────────
  PricingPoint(name: 'İkitelli',      lat: 41.0582, lng: 28.8005, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Altınşehir',    lat: 41.0120, lng: 28.7850, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Mahmutbey',     lat: 41.0530, lng: 28.7940, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Sultangazi',    lat: 41.1025, lng: 28.8780, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Bahçeşehir',   lat: 41.0682, lng: 28.7012, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Ispartakule',   lat: 41.0430, lng: 28.7450, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Kağıthane',    lat: 41.0895, lng: 28.9680, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Seyrantepe',   lat: 41.0930, lng: 28.9670, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Ayazağa',      lat: 41.1114, lng: 28.9941, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: '5. Levent',    lat: 41.0830, lng: 29.0110, priceOne: 900, priceTwo: 1200),
  PricingPoint(name: 'Vadi İstanbul', lat: 41.1100, lng: 28.9920, priceOne: 900, priceTwo: 1200),

  // ── Avrupa Yakası Genel (1000 TL Sabit) ─────────────────────────────────
  PricingPoint(name: 'Bakırköy',      lat: 40.9800, lng: 28.8720, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Ataköy',        lat: 40.9850, lng: 28.8650, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Güneşli',       lat: 41.0370, lng: 28.8640, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Sefaköy',       lat: 41.0050, lng: 28.8600, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Esenler',       lat: 41.0490, lng: 28.8900, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Merter',        lat: 41.0080, lng: 28.8950, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Güngören',      lat: 41.0163, lng: 28.8817, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Şirinevler',    lat: 41.0029, lng: 28.8715, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Yenibosna',     lat: 41.0050, lng: 28.8550, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Bağcılar',      lat: 41.0388, lng: 28.8560, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Davutpaşa',     lat: 41.0290, lng: 28.9010, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Bayrampaşa',    lat: 41.0455, lng: 28.9257, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Zeytinburnu',   lat: 41.0080, lng: 28.9127, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Bahçelievler',  lat: 40.9985, lng: 28.8652, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Topkapı',       lat: 41.0175, lng: 28.9268, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Fatih',         lat: 41.0190, lng: 28.9390, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Eyüp',          lat: 41.0478, lng: 28.9329, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Balat',         lat: 41.0380, lng: 28.9410, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'G.O.Paşa',      lat: 41.0640, lng: 28.9147, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Cevizlibağ',    lat: 41.0115, lng: 28.9060, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Halıcıoğlu',    lat: 41.0355, lng: 28.9570, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Sütlüce',       lat: 41.0420, lng: 28.9580, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Okmeydanı',     lat: 41.0600, lng: 28.9590, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Alibeyköy',     lat: 41.0780, lng: 28.9290, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Yeşilpınar',    lat: 41.0820, lng: 28.8990, priceOne: 1000, priceTwo: 1000),
  PricingPoint(name: 'Kasımpaşa',     lat: 41.0490, lng: 28.9560, priceOne: 1000, priceTwo: 1000),

  // ── Şişli, Beşiktaş & Beyoğlu Hattı ────────────────────────────────────
  PricingPoint(name: 'Taksim',        lat: 41.0370, lng: 28.9850, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Cihangir',      lat: 41.0280, lng: 28.9780, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Beyoğlu',       lat: 41.0337, lng: 28.9742, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Nişantaşı',     lat: 41.0497, lng: 29.0019, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Şişli',         lat: 41.0607, lng: 28.9877, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Fulya',         lat: 41.0520, lng: 28.9990, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Gültepe',       lat: 41.0610, lng: 28.9800, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Çeliktepe',     lat: 41.0700, lng: 28.9950, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Beşiktaş',      lat: 41.0424, lng: 29.0059, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Etiler',        lat: 41.0780, lng: 29.0280, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Bebek',         lat: 41.0750, lng: 29.0420, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Ulus',          lat: 41.0670, lng: 29.0350, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Levent',        lat: 41.0815, lng: 29.0107, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Maslak',        lat: 41.1115, lng: 29.0214, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Ortaköy',       lat: 41.0480, lng: 29.0230, priceOne: 1000, priceTwo: 1300),
  PricingPoint(name: 'Mecidiyeköy',   lat: 41.0712, lng: 28.9952, priceOne: 1000, priceTwo: 1300),

  // ── Sahil & Batı Hattı ───────────────────────────────────────────────────
  PricingPoint(name: 'Florya',        lat: 40.9770, lng: 28.8090, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Yeşilköy',      lat: 40.9800, lng: 28.8300, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Yeşilyurt',     lat: 40.9940, lng: 28.8220, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Cennet Mah.',   lat: 41.0020, lng: 28.8180, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Küçükçekmece', lat: 41.0000, lng: 28.7820, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Avcılar',       lat: 40.9800, lng: 28.7195, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Ambarlı',       lat: 40.9480, lng: 28.6970, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Esenyurt',      lat: 41.0310, lng: 28.6640, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Beylikdüzü',    lat: 41.0000, lng: 28.6390, priceOne: 1200, priceTwo: 1400),
  PricingPoint(name: 'Çatalca',       lat: 41.1430, lng: 28.4640, priceOne: 1200, priceTwo: 1400),

  // ── Sarıyer & Boğaz Hattı ────────────────────────────────────────────────
  PricingPoint(name: 'Sarıyer',       lat: 41.1700, lng: 29.0440, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Emirgan',       lat: 41.1076, lng: 29.0570, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Tarabya',       lat: 41.1280, lng: 29.0596, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'İstinye',       lat: 41.1156, lng: 29.0520, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Yeniköy',       lat: 41.1380, lng: 29.0580, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Zekeriyaköy',   lat: 41.2180, lng: 29.0390, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Uskumruköy',    lat: 41.2080, lng: 29.0310, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Bahçeköy',      lat: 41.1520, lng: 28.9710, priceOne: 1200, priceTwo: 1600),
  PricingPoint(name: 'Madenler',      lat: 41.1750, lng: 29.0220, priceOne: 1200, priceTwo: 1600),

  // ── Büyükçekmece & Yakuplu ──────────────────────────────────────────────
  PricingPoint(name: 'Büyükçekmece', lat: 41.0190, lng: 28.5800, priceOne: 1300, priceTwo: 1600),
  PricingPoint(name: 'Yakuplu',       lat: 41.0070, lng: 28.6550, priceOne: 1300, priceTwo: 1600),

  // ── Kumburgaz & Çevresi ─────────────────────────────────────────────────
  PricingPoint(name: 'Kumburgaz',     lat: 41.1210, lng: 28.3190, priceOne: 1400, priceTwo: 1800),
  PricingPoint(name: 'Kamiloba',      lat: 41.1350, lng: 28.2510, priceOne: 1400, priceTwo: 1800),
  PricingPoint(name: 'Mimaroba',      lat: 41.1500, lng: 28.2920, priceOne: 1400, priceTwo: 1800),
  PricingPoint(name: 'Sinanoba',      lat: 41.1200, lng: 28.2600, priceOne: 1400, priceTwo: 1800),
  PricingPoint(name: 'Güzelce',       lat: 41.1300, lng: 28.3400, priceOne: 1400, priceTwo: 1800),
  PricingPoint(name: 'Celaliye',      lat: 41.1450, lng: 28.2700, priceOne: 1400, priceTwo: 1800),

  // ── Silivri ──────────────────────────────────────────────────────────────
  PricingPoint(name: 'Silivri', lat: 41.0737, lng: 28.2469, priceOne: 1600, priceTwo: 1800),

  // ── Anadolu Yakası — Grup 1 ──────────────────────────────────────────────
  PricingPoint(name: 'Kadıköy',   lat: 40.9990, lng: 29.0276, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Göztepe',   lat: 40.9730, lng: 29.0640, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Üsküdar',   lat: 41.0240, lng: 29.0145, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Ümraniye',  lat: 41.0234, lng: 29.1174, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Kavacık',   lat: 41.1060, lng: 29.0870, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Ataşehir',  lat: 40.9810, lng: 29.1239, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Bostancı',  lat: 40.9620, lng: 29.0800, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Suadiye',   lat: 40.9490, lng: 29.0850, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Fikirtepe', lat: 40.9980, lng: 29.0640, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Kozyatağı', lat: 40.9800, lng: 29.1065, priceOne: 1300, priceTwo: 1500),
  PricingPoint(name: 'Erenköy',   lat: 40.9630, lng: 29.0735, priceOne: 1300, priceTwo: 1500),

  // ── Anadolu Yakası — Grup 2 ──────────────────────────────────────────────
  PricingPoint(name: 'Çekmeköy',    lat: 41.0350, lng: 29.1790, priceOne: 1400, priceTwo: 1600),
  PricingPoint(name: 'Sultanbeyli', lat: 40.9685, lng: 29.2577, priceOne: 1400, priceTwo: 1600),
  PricingPoint(name: 'Sancaktepe',  lat: 41.0070, lng: 29.2250, priceOne: 1400, priceTwo: 1600),
  PricingPoint(name: 'Taşdelen',    lat: 41.0110, lng: 29.1530, priceOne: 1400, priceTwo: 1600),
  PricingPoint(name: 'Küçükyalı',   lat: 40.9350, lng: 29.1130, priceOne: 1400, priceTwo: 1600),
  PricingPoint(name: 'Maltepe',     lat: 40.9326, lng: 29.1349, priceOne: 1400, priceTwo: 1600),
  PricingPoint(name: 'Kartal',      lat: 40.9128, lng: 29.1865, priceOne: 1400, priceTwo: 1600),

  // ── Anadolu Yakası — Grup 3 ──────────────────────────────────────────────
  PricingPoint(name: 'Pendik',          lat: 40.8770, lng: 29.2300, priceOne: 1600, priceTwo: 1900),
  PricingPoint(name: 'Kurtköy',         lat: 40.9160, lng: 29.2630, priceOne: 1600, priceTwo: 1900),
  PricingPoint(name: 'Tuzla',           lat: 40.8160, lng: 29.2880, priceOne: 1600, priceTwo: 1900),
  PricingPoint(name: 'Sabiha Gökçen',   lat: 40.8984, lng: 29.3092, priceOne: 1600, priceTwo: 1900),
];

// ─── Zone Tespiti ────────────────────────────────────────────────────────────
/// Kullanıcının seçtiği konuma en yakın fiyatlandırma noktasını döndürür.
PricingPoint detectNearestZone(LatLng location) {
  return kPricingPoints.reduce((nearest, point) {
    final d1 = Geolocator.distanceBetween(
      location.latitude, location.longitude, nearest.lat, nearest.lng,
    );
    final d2 = Geolocator.distanceBetween(
      location.latitude, location.longitude, point.lat, point.lng,
    );
    return d2 < d1 ? point : nearest;
  });
}

/// Seçilen konuma ve yolcu sayısına göre fiyat döndürür.
/// Aile fiyatı = 2 kişi fiyatıyla aynıdır.
double getPrice(PricingPoint zone, PassengerCount count) => switch (count) {
  PassengerCount.one    => zone.priceOne,
  PassengerCount.two    => zone.priceTwo,
  PassengerCount.family => zone.priceTwo,
};
