import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  static const _iosApiKey = 'appl_ZFNrUFVPEwjnTkGCjpemnPPvRKf';
  static const _androidApiKey = ''; // TODO: Android key eklenecek
  static const entitlementId = 'Premium';

  static Future<void> init() async {
    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    if (apiKey.isEmpty) return;
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      return false;
    }
  }

  static Future<Offering?> getOffering(bool isDriver) async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('RC offerings: ${offerings.all.keys.toList()}');
      debugPrint('RC current: ${offerings.current?.identifier}');
      final key = isDriver ? 'driver' : 'yolcu';
      final offering = offerings.getOffering(key);
      debugPrint('RC offering[$key]: $offering');
      return offering;
    } catch (e) {
      debugPrint('RC getOffering error: $e');
      return null;
    }
  }

  static Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      return result.customerInfo.entitlements.active.containsKey(entitlementId);
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> logIn(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (_) {}
  }

  static Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }
}
