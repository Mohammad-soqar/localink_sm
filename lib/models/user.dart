import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class User {
  final String email;
  final String uid;
  final String photoUrl;
  final String username;
  final String phonenumber;
  final List followers;
  final List following;

  const User(
      {required this.username,
      required this.uid,
      required this.photoUrl,
      required this.email,
      required this.phonenumber,
      required this.followers,
      required this.following});

  static User fromSnap(DocumentSnapshot snap) {
   
  var snapshot = snap.data() as Map<String, dynamic>;
    return User(
      username: snapshot['username'],
      uid: snapshot['uid'],
      email: snapshot['email'],
      photoUrl: snapshot['photoUrl'],
      phonenumber: snapshot['phonenumber'],
      followers: snapshot['followers'],
      following: snapshot['following'],
    );

    
  }

  Map<String, dynamic> toJson() => {
        "username": username,
        "uid": uid,
        "email": email,
        "photoUrl": photoUrl,
        "phonenumber": phonenumber,
        "followers": followers,
        "following": following,
      };
}
