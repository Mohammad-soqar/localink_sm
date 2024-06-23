import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class VisitingStatus {

final databaseReference = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: 'https://localink-778c5-default-rtdb.europe-west1.firebasedatabase.app/', // Replace with your Realtime Database URL
// ignore: deprecated_member_use
).reference();



  void setUserVisiting(double latitude, double longitude) {
    firebase_auth.User? firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      var userVisitingDatabaseRef = databaseReference.child('visiting/${firebaseUser.uid}');
      userVisitingDatabaseRef.set({
        'visiting': true,
        'last_visited': DateTime.now().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      })
      .then((_) => print("User visiting status set successfully"))
      .catchError((error) => print("Failed to set user visiting status: $error"));
      userVisitingDatabaseRef.onDisconnect().set({
        'visiting': false,
        'last_visited': DateTime.now().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      });
    } else {
      print("Firebase user is null, cannot set visiting status");
    }
  }

  void clearUserVisiting() {
    firebase_auth.User? firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      var userVisitingDatabaseRef = databaseReference.child('visiting/${firebaseUser.uid}');
      userVisitingDatabaseRef.set({
        'visiting': false,
        'last_visited': DateTime.now().toIso8601String(),
        'latitude': null,
        'longitude': null,
      });
    }
  }


   Future<Map<String, dynamic>?> isUserVisiting(String userId) async {
    DatabaseReference ref = databaseReference.child('visiting/$userId');
    DataSnapshot snapshot = await ref.get();
    if (snapshot.exists) {
      bool isVisiting = snapshot.child('visiting').value == true;
      double? latitude = snapshot.child('latitude').value as double?;
      double? longitude = snapshot.child('longitude').value as double?;
      return {
        'visiting': isVisiting,
        'latitude': latitude,
        'longitude': longitude,
      };
    }
    return null;
  }

  
}
