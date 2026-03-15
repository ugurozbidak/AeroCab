import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRole { passenger, driver }

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User Management
  Future<void> createUser(
    String uid,
    String fullName,
    String email,
    UserRole role,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'fullName': fullName,
      'email': email,
      'role': role.toString().split('.').last,
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
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .where('status', isEqualTo: 'active')
        .where('ends_at', isGreaterThan: Timestamp.now())
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
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
    GeoPoint destination,
  ) async {
    return await _firestore.collection('reservations').add({
      'passenger_id': passengerId,
      'driver_id': null,
      'pickup_location': pickup,
      'destination_location': destination,
      'status': 'created', // created, accepted, on_route, completed, cancelled
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasActiveReservation(String passengerId) async {
    final snapshot = await _firestore
        .collection('reservations')
        .where('passenger_id', isEqualTo: passengerId)
        .where('status', whereIn: ['created', 'accepted', 'on_route'])
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Stream<QuerySnapshot> getCreatedReservationsStream() {
    return _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'created')
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
        .orderBy('created_at', descending: true)
        .get();

    final driverRides = await _firestore
        .collection('reservations')
        .where('driver_id', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .orderBy('created_at', descending: true)
        .get();

    final allRides = [...passengerRides.docs, ...driverRides.docs];
    allRides.sort((a, b) {
      Timestamp timeA = a.get('created_at') as Timestamp;
      Timestamp timeB = b.get('created_at') as Timestamp;
      return timeB.compareTo(timeA);
    });

    return allRides;
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
