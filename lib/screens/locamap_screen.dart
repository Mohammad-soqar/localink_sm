import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_map_markers/custom_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/models/user.dart';
import 'package:localink_sm/providers/user_provider.dart';
import 'package:provider/provider.dart';

class LocaMap extends StatefulWidget {
  final String uid;
  const LocaMap({Key? key, required this.uid}) : super(key: key);

  @override
  _LocaMapState createState() => _LocaMapState();
}

class _LocaMapState extends State<LocaMap> {
  GoogleMapController? mapController;
  Position? currentPosition;
  model.User? userData;
  String? imageUrl;
  Completer<BitmapDescriptor> _customMarkerCompleter = Completer();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    fetchUserData();
  }

  fetchUserData() async {
    try {
      dynamic uid = widget.uid;
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      userData = User.fromSnap(userSnapshot);
      setState(() {});
    } catch (err) {
      print('Error fetching user data: $err');
    }
  }

  @override
  void didUpdateWidget(covariant LocaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
  }


  Future<BitmapDescriptor> _getCustomMarkerIcon() async {
    if (_customMarkerCompleter.isCompleted) {
      return _customMarkerCompleter.future;
    }

    final Uint8List markerIconBytes = await _getBytesFromUrl(imageUrl!);
    final BitmapDescriptor customMarker =
        BitmapDescriptor.fromBytes(markerIconBytes);

    // Complete the Completer with the custom marker
    _customMarkerCompleter.complete(customMarker);

    return customMarker;
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

// ...

// Function to get bytes from URL
  Future<Uint8List> _getBytesFromUrl(String url) async {
    print('Fetching bytes from URL: $url');
    http.Response response = await http.get(Uri.parse(url));
    print('Response status code: ${response.statusCode}');
    return response.bodyBytes;
  }

  void _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
      // Handle error or show an alert to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    var locations = [
      LatLng(
          currentPosition?.latitude ?? 0.0, currentPosition?.longitude ?? 0.0),
    ];

    _customMarker(String symbol, Color color) {
      return Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: color, blurRadius: 6)]),
        child: Center(child: Text(symbol)),
      );
    }

    ;

    late List<MarkerData> _customMarkers;
    return Scaffold(
      body: CustomGoogleMapMarkerBuilder(
        customMarkers: [
          MarkerData(
              marker: Marker(
                  markerId: const MarkerId('id-1'), position: locations[0]),
              child: _customMarker('A', Colors.black)),
        ],
        builder: (BuildContext context, Set<Marker>? markers) {
          if (markers == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return GoogleMap(
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(
              target: currentPosition != null
                  ? LatLng(
                      currentPosition!.latitude, currentPosition!.longitude)
                  : LatLng(0.0,
                      0.0), // Default coordinates if location is not available
              zoom: 12.0,
            ),
            // Add other GoogleMap properties and methods as needed
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
