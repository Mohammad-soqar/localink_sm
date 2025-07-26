import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String userId;
  final String name;
  final String referencePhoto;
  final String description;

  const Report({
    required this.userId,
    required this.name,
    required this.referencePhoto,
    required this.description,
  });
//g2lIDACP5GR3DdsvmcMpr5VjlHj1
  static Report fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    return Report(
      userId: snapshot['userId'],
      name: snapshot['name'],
      referencePhoto: snapshot['referencePhoto'],
      description: snapshot['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "userId": userId,
      "name": name,
      "referencePhoto": referencePhoto,
      "description": description,
    };
  }
}
