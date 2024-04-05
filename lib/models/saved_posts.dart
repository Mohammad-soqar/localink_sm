import 'package:cloud_firestore/cloud_firestore.dart';

class Saved {
  final String saveId;
  final String uid;
  final String postId;
  final String postCreatorId;
  final String caption;
  final List<dynamic> hashtags;
  final DateTime timestamp;

  Saved({
    required this.saveId,
    required this.uid,
    required this.postId,
    required this.postCreatorId,
    required this.caption,
    required this.hashtags,
    required this.timestamp,
  });

  factory Saved.fromDocument(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    return Saved(
      saveId: snapshot['saveId'],
      uid: snapshot['userId'],
      postId: snapshot['postId'],
      postCreatorId: snapshot['postCreatorId'],
      timestamp: (snapshot['timestamp'] as Timestamp).toDate(),
      hashtags: (snapshot['hashtags'] as List<dynamic>).cast<String>(),
      caption: snapshot['caption'],
    );
  }

  Map<String, dynamic> toDocument() {
    return {
      'saveId': saveId,
      'uid': uid,
      'postId': postId,
      'postCreatorId': postCreatorId,
      'timestamp': timestamp,
      'hashtags': hashtags,
      'caption': caption,
    };
  }
}
