import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:turf/turf.dart';
import 'package:turf/turf.dart' as turf;

class LocaMap extends StatefulWidget {
  const LocaMap({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocaMapState createState() => _LocaMapState();
}

class _LocaMapState extends State<LocaMap> {
  String? userLocation;
  MapboxMapController? mapController;
  Location location = Location();
  Symbol? _userSymbol;
  late Future<String?> userImageFuture;

  @override
  void initState() {
    super.initState();
    userImageFuture = getCurrentUserImage();
    _checkAndRequestLocationPermission();
  }

  Future<String?> getCurrentUserImage() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userSnapshot.exists) {
        // Explicitly cast the photoUrl to a String
        String? photoUrl = userSnapshot.get('photoUrl') as String?;
        return photoUrl;
      }
    }

    return null;
  }

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
  }

  void _checkAndRequestLocationPermission() async {
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

  void _onStyleLoaded() async {
    _showUserLocation();
  }

  void _showUserLocation() async {
    var currentLocation = await location.getLocation();

    String address = await LocationUtils.getAddressFromLatLng(
      currentLocation.latitude!,
      currentLocation.longitude!,
    );

    final String? networkImageUrl = await userImageFuture;

    if (networkImageUrl != null) {
      final response = await http.get(Uri.parse(networkImageUrl));
      if (response.statusCode == 200) {
        ui.Image pinImage =
            await loadImageFromAssets('assets/icons/mapPin.png');
        ui.Image userImage = await loadImageFromBytes(response.bodyBytes);

        Uint8List combinedImageBytes =
            await createCustomMarkerImage(pinImage, userImage);

        await mapController?.addImage('custom-pin', combinedImageBytes);

        if (_userSymbol != null) {
          await mapController?.removeSymbol(_userSymbol!);
        }

        _userSymbol = await mapController?.addSymbol(SymbolOptions(
          geometry:
              LatLng(currentLocation.latitude!, currentLocation.longitude!),
          iconImage: 'custom-pin',
          iconSize: 0.8,
        ));

        mapController?.animateCamera(CameraUpdate.newLatLng(
          LatLng(currentLocation.latitude!, currentLocation.longitude!),
        ));

        if (_userSymbol != null) {
          // Now, call _addCircle to draw the 1km radius around the user's current location
          _addCircle(
            currentLocation.latitude!,
            currentLocation.longitude!,
            700, // radius in meters
          );
        }

        setState(() {
          userLocation = address;
        });
      } else {
        print('Failed to download network image.');
      }
    } else {
      print('Network image URL is null.');
    }
  }

  void _addCircle(double latitude, double longitude, double radiusInMeters) {
    List<LatLng> circlePoints = [];

    int totalPoints = 60;

    for (int i = 0; i < totalPoints; i++) {
      double angle = (i * (360 / totalPoints)).toDouble();
      LatLng point =
          _calculateCoordinate(latitude, longitude, radiusInMeters, angle);
      circlePoints.add(point);
    }

    circlePoints.add(circlePoints.first);

    mapController?.addLine(LineOptions(
      geometry: circlePoints,
      lineColor: "#2AF89B",
      lineWidth: 5.0,
      lineOpacity: 1,
    ));
  }



  LatLng _calculateCoordinate(
      double latitude, double longitude, double radius, double angle) {
    double earthRadius = 6371000; // in meters

    double lat = latitude * pi / 180; // Convert to radians
    double lon = longitude * pi / 180; // Convert to radians

    double angularDistance =
        radius / earthRadius; // Angular distance in radians
    double trueCourse = angle * pi / 180; // Convert angle to radians

    double newLat = asin(sin(lat) * cos(angularDistance) +
        cos(lat) * sin(angularDistance) * cos(trueCourse));
    double newLon = lon +
        atan2(sin(trueCourse) * sin(angularDistance) * cos(lat),
            cos(angularDistance) - sin(lat) * sin(newLat));

    newLat = newLat * 180 / pi; // Convert back to degrees
    newLon = newLon * 180 / pi; // Convert back to degrees

    return LatLng(newLat, newLon);
  }

  Future<ui.Image> loadImageFromAssets(String assetPath) async {
    ByteData data = await rootBundle.load(assetPath);
    Uint8List bytes = data.buffer.asUint8List();
    return loadImageFromBytes(bytes);
  }

  Future<ui.Image> loadImageFromBytes(Uint8List bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }

  Future<Uint8List> createCustomMarkerImage(
      ui.Image pinImage, ui.Image userImage) async {
    final double imageSize = pinImage.width / 2;
    final Offset imageOffset = Offset((pinImage.width - imageSize) / 2,
        (pinImage.height - imageSize) / 2 - 15);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();

    canvas.drawImage(pinImage, Offset.zero, paint);

    final Rect ovalRect = Rect.fromCircle(
        center: imageOffset + Offset(imageSize / 2, imageSize / 2),
        radius: imageSize / 2);
    final Path ovalPath = Path()..addOval(ovalRect);
    canvas.clipPath(ovalPath, doAntiAlias: false);
    canvas.drawImageRect(
        userImage,
        Rect.fromLTRB(
            0, 0, userImage.width.toDouble(), userImage.height.toDouble()),
        ovalRect,
        paint);

    final ui.Image compositeImage =
        await recorder.endRecording().toImage(pinImage.width, pinImage.height);

    final ByteData? byteData =
        await compositeImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

//ios: sk.eyJ1IjoibW9oYW1tYWRzb3FhcjEwMSIsImEiOiJjbHVkYzVrMzEwbjFpMmxuenpxM2Eybm5nIn0.S4pjUr0pwYqsJOzpJo73vQ
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      MapboxMap(
        accessToken:
            "sk.eyJ1IjoibW9oYW1tYWRzb3FhcjEwMSIsImEiOiJjbHUyM3Rwc2owc2p6MmtrMWg1eTNjb25oIn0.uP5k1FrxSDNNBjWo1LdSlg",
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        styleString: "mapbox://styles/mapbox/dark-v11",
        initialCameraPosition: const CameraPosition(
          target: LatLng(0.0, 0.0),
          zoom: 15.0,
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
                Text(
                  userLocation ??
                      'Featching Location', // Placeholder for dynamic location name
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )),
      ),
    ]));
  }
}
