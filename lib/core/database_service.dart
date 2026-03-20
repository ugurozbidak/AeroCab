import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aerocab/core/booking_models.dart';
import 'package:aerocab/core/purchases_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum UserRole { passenger, driver }

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User Management
  Future<void> createUser(
    String uid,
    String fullName,
    String email,
    UserRole role, {
    String? phone,
    String? plate,
    String? photoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'fullName': fullName,
      'email': email,
      'role': role.toString().split('.').last,
      if (phone != null) 'phone': phone,
      if (plate != null) 'plate': plate,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserRole> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return (doc.data()!['role'] == 'driver')
          ? UserRole.driver
          : UserRole.passenger;
    }
    return UserRole.passenger;
  }

  // Subscription Management
  Future<bool> hasActiveSubscription(String uid) async {
    try {
      log('[SUB] Checking entitlement for uid: $uid');
      final isPremium = await PurchasesService.isPremium();
      log('[SUB] isPremium: $isPremium');
      return isPremium;
    } catch (e) {
      log('[SUB] ERROR: $e');
      return false;
    }
  }

  // Driver Location Management
  Future<void> updateDriverLocation(String driverId, GeoPoint position) async {
    await _firestore.collection('driver_locations').doc(driverId).set({
      'position': position,
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeDriverLocation(String driverId) async {
    await _firestore.collection('driver_locations').doc(driverId).delete();
  }

  Stream<QuerySnapshot> getDriversStream() {
    return _firestore.collection('driver_locations').snapshots();
  }

  // Reservation Management
  Future<DocumentReference> createReservation(
    String passengerId,
    GeoPoint pickup,
    GeoPoint destination, {
    required RideType rideType,
    required PassengerCount passengerCount,
    DateTime? scheduledTime,
    GeoPoint? destination2,
    double? price,
    String? pricingZone,
    String? pickupAddress,
    String? destinationAddress,
    String? destination2Address,
  }) async {
    return await _firestore.collection('reservations').add({
      'passenger_id': passengerId,
      'driver_id': null,
      'pickup_location': pickup,
      'destination_location': destination,
      'destination2_location': destination2,
      'ride_type': rideType.name,
      'passenger_count': passengerCount.name,
      'price': price,
      'pricing_zone': pricingZone,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'destination2_address': destination2Address,
      'scheduled_time': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime)
          : null,
      'status': 'created',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Aktif rezervasyonu varsa döndürür (yolcu).
  Future<DocumentSnapshot?> getActiveReservationForPassenger(
    String uid,
  ) async {
    final snap = await _firestore
        .collection('reservations')
        .where('passenger_id', isEqualTo: uid)
        .where('status', whereIn: ['created', 'accepted', 'heading_to_pickup', 'on_route'])
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  /// Aktif rezervasyonu varsa döndürür (sürücü).
  Future<DocumentSnapshot?> getActiveReservationForDriver(String uid) async {
    final snap = await _firestore
        .collection('reservations')
        .where('driver_id', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'heading_to_pickup', 'on_route'])
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  Future<bool> hasActiveReservation(String passengerId) async {
    final snapshot = await _firestore
        .collection('reservations')
        .where('passenger_id', isEqualTo: passengerId)
        .where('status', whereIn: ['created', 'accepted', 'heading_to_pickup', 'on_route'])
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Stream<QuerySnapshot> getCreatedReservationsStream(String driverId) {
    return _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'created')
        .where('current_offer_driver', isEqualTo: driverId)
        .snapshots();
  }

  Future<bool> acceptReservation(String reservationId, String driverId) async {
    final reservationRef = _firestore
        .collection('reservations')
        .doc(reservationId);

    return _firestore
        .runTransaction<bool>((transaction) async {
          final snapshot = await transaction.get(reservationRef);

          if (!snapshot.exists) {
            throw Exception("Reservation does not exist!");
          }

          final data = snapshot.data() as Map<String, dynamic>;
          if (data['status'] == 'created') {
            transaction.update(reservationRef, {
              'status': 'accepted',
              'driver_id': driverId,
            });
            return true;
          } else {
            // Another driver already accepted it
            return false;
          }
        })
        .catchError((error) {
          log("Transaction failed: $error");
          return false;
        });
  }

  Stream<DocumentSnapshot> getReservationStream(String reservationId) {
    return _firestore.collection('reservations').doc(reservationId).snapshots();
  }

  Future<void> cancelReservation(String reservationId) async {
    DocumentSnapshot doc = await _firestore
        .collection('reservations')
        .doc(reservationId)
        .get();
    if (doc.exists && doc.get('driver_id') == null) {
      await _firestore.collection('reservations').doc(reservationId).update({
        'status': 'cancelled',
      });
    }
  }

  Future<void> updateReservationStatus(
    String reservationId,
    String status,
  ) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': status,
    });
  }

  Future<List<QueryDocumentSnapshot>> getRideHistory(String userId) async {
    final passengerRides = await _firestore
        .collection('reservations')
        .where('passenger_id', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .get();

    final driverRides = await _firestore
        .collection('reservations')
        .where('driver_id', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .get();

    final allRides = [...passengerRides.docs, ...driverRides.docs];
    allRides.sort((a, b) {
      Timestamp timeA = a.get('created_at') as Timestamp;
      Timestamp timeB = b.get('created_at') as Timestamp;
      return timeB.compareTo(timeA);
    });

    return allRides;
  }

  // Saved Address Management
  Future<List<SavedAddress>> getSavedAddresses(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_addresses')
        .orderBy('created_at')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final geo = data['location'] as GeoPoint;
      return SavedAddress(
        id: doc.id,
        name: data['name'] as String,
        address: data['address'] as String,
        location: LatLng(geo.latitude, geo.longitude),
      );
    }).toList();
  }

  Future<void> saveAddress(
    String uid,
    String name,
    String address,
    GeoPoint location,
  ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_addresses')
        .add({
      'name': name,
      'address': address,
      'location': location,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAddress(String uid, String addressId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_addresses')
        .doc(addressId)
        .delete();
  }

  // User Profile Management
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteUserAccount(String uid) async {
    // 1. Aktif rezervasyonları iptal et
    try {
      final activeRes = await _firestore
          .collection('reservations')
          .where('passenger_id', isEqualTo: uid)
          .where('status', whereIn: ['created', 'accepted', 'heading_to_pickup', 'on_route'])
          .get();
      for (final doc in activeRes.docs) {
        await doc.reference.update({'status': 'cancelled'});
      }
    } catch (_) {}

    // 2. Subcollection ve user dokümanını sil
    final addresses = await _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_addresses')
        .get();
    final subs = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .get();

    final batch = _firestore.batch();
    for (final doc in addresses.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in subs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('users').doc(uid));
    await batch.commit();

    // 3. Driver location sil
    try {
      await _firestore.collection('driver_locations').doc(uid).delete();
    } catch (_) {}

    // 4. Profil fotoğrafını Storage'dan sil
    try {
      await FirebaseStorage.instance
          .ref()
          .child('profile_photos/$uid.jpg')
          .delete();
    } catch (_) {}
  }

  Future<List<QueryDocumentSnapshot>> getDriverEarnings(String driverId) async {
    final snap = await _firestore
        .collection('reservations')
        .where('driver_id', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .get();
    return snap.docs;
  }

  // Subscription Management - Cancel
  Future<void> cancelSubscription(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'status': 'cancelled'});
    }
  }

  Future<Map<String, dynamic>?> getSubscriptionData(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .orderBy('ends_at', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  // Rating Management
  Future<void> saveRating({
    required String reservationId,
    required String raterUid,
    required String ratedUid,
    required int stars,
    required List<String> tags,
  }) async {
    await _firestore.collection('ratings').add({
      'reservation_id': reservationId,
      'rater_uid': raterUid,
      'rated_uid': ratedUid,
      'stars': stars,
      'tags': tags,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasRated(String reservationId, String raterUid) async {
    final snap = await _firestore
        .collection('ratings')
        .where('reservation_id', isEqualTo: reservationId)
        .where('rater_uid', isEqualTo: raterUid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getUserRatingStats(String uid) async {
    final snap = await _firestore
        .collection('ratings')
        .where('rated_uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return null;
    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['stars'] as num).toDouble();
    }
    return {'avg': total / snap.docs.length, 'count': snap.docs.length};
  }

  Future<Set<String>> getRatedReservationIds(String uid) async {
    final snap = await _firestore
        .collection('ratings')
        .where('rater_uid', isEqualTo: uid)
        .get();
    return snap.docs
        .map((d) => d.data()['reservation_id'] as String)
        .toSet();
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
