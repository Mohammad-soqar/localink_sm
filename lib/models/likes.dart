import 'package:cloud_firestore/cloud_firestore.dart';

class Like {
  final String likeId;
  final String uid;
  final String postId;
  final String postCreatorId;
  final DateTime likedAt;


  Like({
    required this.likeId,
    required this.uid,
    required this.postId,
    required this.postCreatorId,
    required this.likedAt,
  
  });

  factory Like.fromDocument(Map<String, dynamic> doc) {
    return Like(
      likeId: doc['likeId'],
      uid: doc['userId'],
      postId: doc['postId'],
      postCreatorId: doc['postCreatorId'],
      likedAt: (doc['likedAt'] as Timestamp).toDate(),
    
    );
  }

  Map<String, dynamic> toDocument() {
    return {
      'likeId': likeId,
      'uid': uid,
      'postId': postId,
      'postCreatorId': postCreatorId,
      'likedAt': likedAt,
      
    };
  }
}
