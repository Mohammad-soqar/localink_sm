import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String description;
  final String profileImage;
  final String username;
  final String uid;
  final String postId;
  final String postUrl;
  final DateTime datePublished;
  // Users who liked the post
  final List<dynamic> likes;
  final List<dynamic> hashtags;

  const Post(
      {required this.description,
      required this.uid,
      required this.username,
      required this.profileImage,
      required this.postId,
      required this.datePublished,
      required this.postUrl,
      required this.likes,
      required this.hashtags});

  static Post fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Post(
      username: snapshot['username'],
      uid: snapshot['uid'],
      description: snapshot['description'],
      profileImage: snapshot['profileImage'],
      postId: snapshot['postId'],
      datePublished: snapshot['datePublished'],
      postUrl: snapshot['postUrl'],
      likes: (snapshot['likes'] as List<dynamic>).cast<String>(),
      hashtags: (snapshot['likes'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        "description": description,
        "username": username,
        "uid": uid,
        "profileImage": profileImage,
        "postId": postId,
        "datePublished": datePublished,
        "postUrl": postUrl,
        "likes": likes,
        "hashtags": hashtags,
      };
}
