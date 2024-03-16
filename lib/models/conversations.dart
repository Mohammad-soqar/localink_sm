import 'package:cloud_firestore/cloud_firestore.dart';

class Conversations {
  final String id;
  final String? title;
  final List<String> participantIDs;
  final String participantsKey; // New field
  final String? lastMessage;
  final DateTime lastMessageTimestamp;
  final DateTime createdAt;
  final Map<String, int> unreadCounts; // New field

  Conversations({
    required this.id,
    this.title,
    required this.participantIDs,
    required this.participantsKey, // Initialize in constructor
    this.lastMessage,
    required this.lastMessageTimestamp,
    required this.createdAt,
    required this.unreadCounts, // Initialize in constructor
  });

  static Conversations fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Conversations(
      id: snap.id,
      title: snapshot['title'],
      participantIDs: List<String>.from(snapshot['participantIDs']),
      participantsKey: snapshot['participantsKey'], // Retrieve from snapshot
      lastMessage: snapshot['lastMessage'],
      lastMessageTimestamp:
          (snapshot['lastMessageTimestamp'] as Timestamp).toDate(),
      createdAt: (snapshot['createdAt'] as Timestamp).toDate(),
      unreadCounts: Map<String, int>.from(snapshot['unreadCounts'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'participantIDs': participantIDs,
        'participantsKey': participantsKey, // Include in toJson
        'lastMessage': lastMessage,
        'lastMessageTimestamp': lastMessageTimestamp,
        'createdAt': createdAt,
        'unreadCounts': unreadCounts, // Include in toJson
      };
}
