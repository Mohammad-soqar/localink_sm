import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localink_sm/models/UserLocation.dart';
import 'package:location/location.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  final Location location = Location();
  LocationData? lastPublishedLocation;
  LocationData? currentLocation;  
  final double threshold = 30; 

  factory LocationService() {
    return _instance;
  }

  LocationService._internal() {
    location.changeSettings(interval: 30000, accuracy: LocationAccuracy.high);
    _ensurePermissions();
    _trackLocation();
  }

  void _ensurePermissions() async {
    bool _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        print('Failed to enable location service.');
        return;
      }
    }

    PermissionStatus _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        print('Location permission not granted.');
        return;
      }
    }
  }

  void _trackLocation() {
    location.onLocationChanged.listen((LocationData locData) {
      currentLocation = locData;  
      if (_shouldUpdateLocation(locData)) {
        _updateFirestoreLocation(locData);
        lastPublishedLocation = locData;
      }
    });
  }

  bool _shouldUpdateLocation(LocationData newLocation) {
    if (lastPublishedLocation == null) return true;
    double distance = _calculateDistance(
      newLocation.latitude!,
      newLocation.longitude!,
      lastPublishedLocation!.latitude!,
      lastPublishedLocation!.longitude!
    );
    return distance > threshold;
  }

  void _updateFirestoreLocation(LocationData locData) {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null && locData.latitude != null && locData.longitude != null) {
      UserLocation userLocation = UserLocation(
        latitude: locData.latitude!,
        longitude: locData.longitude!,
        timestamp: DateTime.now()
      );

      FirebaseFirestore.instance.collection('user_locations').doc(user.uid).set(
        userLocation.toFirestore(),
        SetOptions(merge: true)
      ).then((_) {
        print('Location updated in Firestore successfully.');
      }).catchError((error) {
        print('Failed to update location in Firestore: $error');
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295; 
    var a = 0.5 - cos((lat2 - lat1) * p)/2 +
            cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000; 
  }
}
