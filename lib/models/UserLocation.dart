import 'package:cloud_firestore/cloud_firestore.dart';

class UserLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory UserLocation.fromFirestore(Map<String, dynamic> firestoreDoc) {
    return UserLocation(
      latitude: firestoreDoc['latitude'],
      longitude: firestoreDoc['longitude'],
      timestamp: (firestoreDoc['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
