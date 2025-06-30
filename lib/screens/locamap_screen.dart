import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:location/location.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:localink_sm/utils/mapbox_constants.dart';
import 'package:localink_sm/screens/add_event.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/location_service.dart';
import 'package:localink_sm/utils/location_utils.dart';

class LocaMap extends StatefulWidget {
  const LocaMap({super.key});

  @override
  State<LocaMap> createState() => _LocaMapState();
}

class _LocaMapState extends State<LocaMap> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  String? userLocation;
  bool isBusinessAccount = false;

  @override
  void initState() {
    super.initState();
    _fetchAccountType();
    _checkAndRequestLocationPermission();
  }

  Future<void> _fetchAccountType() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userSnapshot.exists) {
        setState(() {
          isBusinessAccount = userSnapshot.get('isBusinessAccount') ?? false;
        });
      }
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    _showUserLocation();
  }

  Future<void> _showUserLocation() async {
    var service = LocationService();
    var locationData = service.currentLocation;
    if (locationData == null ||
        locationData.latitude == null ||
        locationData.longitude == null) return;

    final point =
        Point(coordinates: Position(locationData.longitude!, locationData.latitude!));
    await _pointManager?.create(PointAnnotationOptions(
      geometry: point,
      image: await _loadImageFromAsset('assets/icons/mapPin2.png'),
      iconSize: 1.2,
    ));

    await _mapboxMap?.setCamera(CameraOptions(center: point, zoom: 14));

    final address = await LocationUtils.getAddressFromLatLng(
        locationData.latitude!, locationData.longitude!);
    setState(() {
      userLocation = address;
    });
  }

  Future<Uint8List> _loadImageFromAsset(String assetPath) async {
    final ByteData byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }

  void _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Location().serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await Location().requestService();
      if (!serviceEnabled) return;
    }
    PermissionStatus permissionGranted = await Location().hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await Location().requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            resourceOptions: ResourceOptions(accessToken: mapboxAccessToken),
            styleUri: mapboxDarkStyle,
            mapOptions:
                MapOptions(pixelRatio: MediaQuery.of(context).devicePixelRatio),
            cameraOptions: const CameraOptions(
              center: Point(coordinates: Position(28.99925, 40.99437)),
              zoom: 10,
            ),
            onMapCreated: _onMapCreated,
          ),
          if (isBusinessAccount)
            Positioned(
              top: 50,
              right: 0,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AddEventPage()),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: highlightColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: 30.0),
                  child: Text(
                    'Add Event',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              decoration: const BoxDecoration(
                color: darkBackgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/locamap.svg',
                      color: highlightColor,
                      width: 24,
                      height: 24,
                    ),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Text(
                      (userLocation?.length ?? 0) > 36
                          ? '${userLocation?.substring(0, 30)}...'
                          : userLocation ?? 'Fetching Location',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
