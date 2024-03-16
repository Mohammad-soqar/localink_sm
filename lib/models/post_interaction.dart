import 'package:cloud_firestore/cloud_firestore.dart';

class Reaction {
  final String id;
  final String postId;
  final String uid;

  const Reaction({
    required this.id,
    required this.postId,
    required this.uid,

  });

  static Reaction fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Reaction(
      id: snapshot['id'],
      postId: snapshot['postId'],
      uid: snapshot['uid'],

      
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "postId": postId,
        "uid": uid,
      };
}
