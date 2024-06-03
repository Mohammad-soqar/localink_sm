import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String description;
  final DateTime dateTime;
  final String organizer;
  final String locationDetails;
  final double longitude;
  final double latitude;
  final List<String> attendees;
  final double radius;
  final String status;
  final String pinUrl;
  final List<String> imageUrls;

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.dateTime,
    required this.organizer,
    required this.locationDetails,
    required this.longitude,
    required this.latitude,
    required this.attendees,
    required this.radius,
    required this.pinUrl,
    required this.imageUrls,
    this.status = 'pending',
  });

  static Event fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Event(
      id: snapshot['id'],
      name: snapshot['name'],
      description: snapshot['description'],
      dateTime: DateTime.parse(snapshot['dateTime']),
      organizer: snapshot['organizer'],
      locationDetails: snapshot['locationDetails'],
      longitude: snapshot['longitude'],
      latitude: snapshot['latitude'],
      attendees: List<String>.from(snapshot['attendees']),
      radius: snapshot['radius'],
      status: snapshot['status'],
      pinUrl: snapshot['pinUrl'],
      imageUrls: List<String>.from(snapshot['imageUrls']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'organizer': organizer,
      'locationDetails': locationDetails,
      "longitude": longitude,
      "latitude": latitude,
      'attendees': attendees,
      'radius': radius,
      'status': status,
      'pinUrl': pinUrl,
      'imageUrls': imageUrls,
    };
  }
}
