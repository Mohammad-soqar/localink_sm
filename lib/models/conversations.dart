import 'package:cloud_firestore/cloud_firestore.dart';

class Conversations {
  final String id;
  final String? title;
  final String? groupImageUrl; // New field for group image
  final List<String> participantIDs;
  final String participantsKey;
  final String? lastMessage;
  final DateTime lastMessageTimestamp;
  final DateTime createdAt;
  final Map<String, int> unreadCounts;
  final bool isGroup;

  Conversations({
    required this.id,
    this.title,
    this.groupImageUrl, // Initialize in constructor
    required this.participantIDs,
    required this.participantsKey,
    this.lastMessage,
    required this.lastMessageTimestamp,
    required this.createdAt,
    required this.unreadCounts,
    required this.isGroup,
  });

  static Conversations fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Conversations(
      id: snap.id,
      title: snapshot['title'],
      groupImageUrl: snapshot['groupImageUrl'], // Retrieve from snapshot
      participantIDs: List<String>.from(snapshot['participantIDs']),
      participantsKey: snapshot['participantsKey'],
      lastMessage: snapshot['lastMessage'],
      lastMessageTimestamp:
          (snapshot['lastMessageTimestamp'] as Timestamp).toDate(),
      createdAt: (snapshot['createdAt'] as Timestamp).toDate(),
      unreadCounts: Map<String, int>.from(snapshot['unreadCounts'] ?? {}),
      isGroup: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'groupImageUrl': groupImageUrl, // Include in toJson
        'participantIDs': participantIDs,
        'participantsKey': participantsKey,
        'lastMessage': lastMessage,
        'lastMessageTimestamp': lastMessageTimestamp,
        'createdAt': createdAt,
        'unreadCounts': unreadCounts,
        'isGroup': isGroup,
      };
}
