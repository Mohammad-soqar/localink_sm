// ignore: file_names
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class OnlineStatusCache {
  Map<String, bool> _cache = {};
  DateTime _lastUpdated = DateTime.now();
  final databaseReference = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://localink-778c5-default-rtdb.europe-west1.firebasedatabase.app/', // Replace with your Realtime Database URL
  );

  Future<bool> isFriendOnline(String friendId) async {
    if (_cache.containsKey(friendId) &&
        DateTime.now().difference(_lastUpdated) < Duration(minutes: 5)) {
      // Return cached status if it's recent
      return _cache[friendId] ?? false;
    }

    // Fetch fresh data if not in cache or cache is outdated
    DatabaseReference ref = databaseReference.ref('status/$friendId/online');
    DataSnapshot snapshot = await ref.get();
    bool online = snapshot.exists && (snapshot.value == true);
    _cache[friendId] = online; // Update cache
    _lastUpdated = DateTime.now(); // Update last updated time
    return online;
  }
}
