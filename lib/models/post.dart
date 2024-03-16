import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String uid;
  final Timestamp createdDatetime;
  final String caption;
  final DocumentReference postType;
  final String longitude;
  final String latitude;
  final String locationName;
  final List<dynamic> hashtags;

  const Post(
      {required this.id,
      required this.uid,
      required this.createdDatetime,
      required this.caption,
      required this.postType,
      required this.longitude,
      required this.latitude,
      required this.locationName,
      required this.hashtags});

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
      hashtags: (snapshot['likes'] as List<dynamic>).cast<String>(),
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
      };
}
