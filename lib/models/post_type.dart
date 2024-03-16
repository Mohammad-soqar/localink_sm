import 'package:cloud_firestore/cloud_firestore.dart';

class PostType {
  final String id;
  final String post_type_name;

  const PostType({
    required this.id,
    required this.post_type_name,

  });

  static PostType fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return PostType(
      id: snapshot['id'],
      post_type_name: snapshot['post_type_name'],

      
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "post_type_name": post_type_name,
      };
}
