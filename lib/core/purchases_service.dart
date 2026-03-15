import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  static const _apiKey = 'sk_VBQMWudDDAgNrRpQVCknGrqbGrtxF';

  static Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(_apiKey));
    } on PlatformException catch (e) {
      log('Failed to configure Purchases: $e');
    }
  }

  // TODO: Add methods for fetching offerings, making purchases, and checking subscription status
}
