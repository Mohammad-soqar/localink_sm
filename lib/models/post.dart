import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String uid;
  final Timestamp createdDatetime;
  final String caption;
  final DocumentReference postType;
  final double longitude;
  final double latitude;
  final String locationName;
  final List<String> hashtags;
  final int likesCount;
  final String privacy; // New field
  
 // final List<String> tags; // New field

  const Post({
    required this.id,
    required this.uid,
    required this.createdDatetime,
    required this.caption,
    required this.postType,
    required this.longitude,
    required this.latitude,
    required this.locationName,
    required this.hashtags,
    required this.likesCount,
    required this.privacy, // New field
    //required this.tags, // New field
  });

  static Post fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Post(
      id: snapshot['id'],
      uid: snapshot['uid'],
      createdDatetime: snapshot['createdDatetime'],
      caption: snapshot['caption'],
      postType: snapshot['postType'],
      longitude: snapshot['longitude'],
      latitude: snapshot['latitude'],
      locationName: snapshot['locationName'],
      hashtags: (snapshot['hashtags'] as List<dynamic>).cast<String>(),
      likesCount: snapshot['likesCount'] ?? 0,
      privacy: snapshot['privacy'], // New field
     // tags: (snapshot['tags'] as List<dynamic>).cast<String>(), // New field
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "uid": uid,
        "createdDatetime": createdDatetime,
        "caption": caption,
        "postType": postType,
        "longitude": longitude,
        "latitude": latitude,
        "locationName": locationName,
        "hashtags": hashtags,
        "likesCount": likesCount,
        "privacy": privacy, // New field
      // "tags": tags, // New field
      };
}
