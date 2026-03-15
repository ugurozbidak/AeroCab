import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core/database_service.dart';

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final dbService = ref.read(databaseServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: user == null
          ? const Center(child: Text("Please log in to see your ride history."))
          : FutureBuilder<List<QueryDocumentSnapshot>>(
              future: dbService.getRideHistory(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text("An error occurred: ${snapshot.error}"),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("You have no past rides."));
                }

                final rides = snapshot.data!;

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index].data() as Map<String, dynamic>;
                    final status = ride['status'] as String;
                    final createdAt = (ride['created_at'] as Timestamp)
                        .toDate();
                    final formattedDate = DateFormat.yMMMd().add_jm().format(
                      createdAt,
                    );

                    final pickup = ride['pickup_location'] as GeoPoint;
                    final destination =
                        ride['destination_location'] as GeoPoint;

                    IconData icon;
                    Color color;
                    switch (status) {
                      case 'completed':
                        icon = Icons.check_circle;
                        color = Colors.green;
                        break;
                      case 'cancelled':
                        icon = Icons.cancel;
                        color = Colors.red;
                        break;
                      default:
                        icon = Icons.history;
                        color = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: ListTile(
                        leading: Icon(icon, color: color, size: 40),
                        title: Text(
                          'Ride on $formattedDate',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'From: (${pickup.latitude.toStringAsFixed(2)}, ${pickup.longitude.toStringAsFixed(2)})\nTo: (${destination.latitude.toStringAsFixed(2)}, ${destination.longitude.toStringAsFixed(2)})',
                        ),
                        trailing: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
