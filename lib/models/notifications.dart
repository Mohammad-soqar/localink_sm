import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
  });

  factory NotificationModel.fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return NotificationModel(
      id: snap.id,
      title: snapshot['title'],
      body: snapshot['body'],
      data: snapshot['data'],
      timestamp: (snapshot['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'data': data,
        'timestamp': timestamp,
      };
}
