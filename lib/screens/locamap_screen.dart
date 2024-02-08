import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocaMap extends StatefulWidget {
  @override
  _LocaMapState createState() => _LocaMapState();
}

class _LocaMapState extends State<LocaMap> {
  GoogleMapController? mapController;
  Position? currentPosition;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _updateCameraPosition();
  }

  void _updateCameraPosition() {
    if (mapController != null && currentPosition != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(currentPosition!.latitude, currentPosition!.longitude),
            zoom: 12.0,
          ),
        ),
      );
    }
  }

  void _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentPosition = position;
        _updateCameraPosition();
      });
    } catch (e) {
      print('Error getting location: $e');
      // Handle error or show an alert to the user
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        initialCameraPosition: CameraPosition(
          target: currentPosition != null
              ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
              : LatLng(
                  0.0, 0.0), // Default coordinates if location is not available
          zoom: 12.0,
        ),
        // Add other GoogleMap properties and methods as needed
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
