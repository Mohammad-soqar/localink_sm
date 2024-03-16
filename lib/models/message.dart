

import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderID;
  final String content;
  final DateTime timestamp;
  final String type;
    final String? mediaUrl; // URL of the media file
  final String? mediaType; // Type of the media (image, video, audio, etc.)

  MessageModel({
    required this.id,
    required this.senderID,
    required this.content,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.mediaType,
  });

  // Method to create an instance of MessageModel from Firestore snapshot
  static MessageModel fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return MessageModel(
      id: snap.id, // Document ID
      senderID: snapshot['senderID'],
      content: snapshot['content'],
      timestamp: (snapshot['timestamp'] as Timestamp).toDate(),
      type: snapshot['type'],
      mediaUrl: snapshot['mediaUrl'],
      mediaType: snapshot['mediaType'],
    );
  }

    Map<String, dynamic> toJson() => {
        'senderID': senderID,
        'content': content,
        'timestamp': timestamp,
        'type': type,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
       
      };
}