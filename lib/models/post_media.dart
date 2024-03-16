import 'package:cloud_firestore/cloud_firestore.dart';

class PostMedia {
  final String id;
  final DocumentReference postId;
  final String mediaFile;




  const PostMedia({
    required this.id,
    required this.postId,
    required this.mediaFile,


  });

  static PostMedia fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return PostMedia(
      id: snapshot['id'],
      postId: snapshot['postId'],
      mediaFile: snapshot['mediaFile'],
     
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "postId": postId,
        "mediaFile": mediaFile,

      };
}
