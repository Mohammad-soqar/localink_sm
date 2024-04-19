import 'dart:async';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  final Location location = Location();
  Timer? _timer;

  LocationService() {
    _checkAndRequestLocationPermission();
  }

  void startTracking() {
    _timer = Timer.periodic(Duration(seconds: 30), (timer) async {
      var userLocation = await location.getLocation();
      _updateUserLocation(userLocation);
    });
  }

  void stopTracking() {
    _timer?.cancel();
  }

  void _updateUserLocation(LocationData currentLocation) async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      FirebaseFirestore.instance.collection('user_locations').doc(userId).set({
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }
  }
}
