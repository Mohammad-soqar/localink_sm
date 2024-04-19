import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/storage_methods.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

   Future<model.User> getUserDetails() async {
    User? currentUser = _auth.currentUser; // FirebaseAuth's User
    if (currentUser != null) {
      DocumentSnapshot documentSnapshot = await _firestore.collection('users').doc(currentUser.uid).get();
      if (documentSnapshot.exists) {
        return model.User.fromSnap(documentSnapshot);
      } else {
        throw Exception("User does not exist in Firestore");
      }
    } else {
      throw Exception("No current user found");
    }
  }

  //sign up user
  Future<String> signUpUser({
    required String email,
    required String password,
    required String phonenumber,
    required String username,
    required Uint8List file,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty ||
          password.isNotEmpty ||
          phonenumber.isNotEmpty ||
          username.isNotEmpty ||
          // ignore: unnecessary_null_comparison
          file != null) {
        //register user
        UserCredential credential = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);

        String photoUrl = await StorageMethods()
            .uploadImageToStorage('profile_pictures', file, false);
        //add user to our db

        model.User user = model.User(
            username: username,
            uid: credential.user!.uid,
            photoUrl: photoUrl,
            email: email,
            phonenumber: phonenumber,
            followers: [],
            following: []);

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(user.toJson());
        res = "success";
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  //login the user
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty || password.isNotEmpty) {
        await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> signOut(BuildContext context) async {
    await _auth.signOut();
  }
}
 