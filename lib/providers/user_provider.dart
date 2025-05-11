import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/user.dart'; // Your custom user model
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // Prefixed
import 'package:firebase_database/firebase_database.dart';
import 'package:localink_sm/resources/auth_methods.dart';

class UserProvider with ChangeNotifier {
  User? _user; // This now clearly refers to your custom User model
  final AuthMethods _authMethods = AuthMethods();
final databaseReference = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: 'https://localink-778c5-default-rtdb.europe-west1.firebasedatabase.app/', // Replace with your Realtime Database URL
// ignore: deprecated_member_use
).ref();


  User? get getUser => _user;

  Future<void> refreshUser() async {
    try {
      User user = await _authMethods.getUserDetails(); // Assumes this returns your custom User model
      _user = user;
      notifyListeners();
      setUserOnline(); // Ensures user is set online
    } catch (e) {
      print("Error refreshing user: $e");
    }
  }


 void setUserOnline() {
  firebase_auth.User? firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (firebaseUser != null) {
    var userStatusDatabaseRef = databaseReference.child('status/${firebaseUser.uid}');
    userStatusDatabaseRef.set({'online': true, 'last_online': DateTime.now().toIso8601String()})
    .then((_) => print("User set online successfully"))
    .catchError((error) => print("Failed to set user online: $error"));
    userStatusDatabaseRef.onDisconnect().set({'online': false, 'last_online': DateTime.now().toIso8601String()});
  } else {
    print("Firebase user is null, cannot set online status");
  }
}

  void setUserOffline() {
    firebase_auth.User? firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser; // Using the prefix
    if (firebaseUser != null) {
      var userStatusDatabaseRef = databaseReference.child('status/${firebaseUser.uid}');
      userStatusDatabaseRef.set({'online': false, 'last_online': DateTime.now().toIso8601String()});
    }
  }
}
