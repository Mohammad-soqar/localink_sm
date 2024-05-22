import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:localink_sm/utils/location_service.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class MapPickerScreen extends StatefulWidget {
  final Function(LatLng) onLocationPicked;

  MapPickerScreen({required this.onLocationPicked});

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  MapboxMapController? _controller;
  LatLng? _pickedLocation;
  LocationService locationService = LocationService();
  Completer<MapboxMapController> _controllerCompleter = Completer<MapboxMapController>();

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  void _setInitialLocation() {
    var currentLocation = locationService.currentLocation;
    if (currentLocation != null) {
      _pickedLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
    } else {
      _pickedLocation = LatLng(37.7749, -122.4194); // Default location
    }
  }

  Future<void> _onMapCreated(MapboxMapController controller) async {
    _controller = controller;
    _controllerCompleter.complete(controller);
    await _moveCameraToCurrentLocation();
  }

  Future<void> _moveCameraToCurrentLocation() async {
    if (_pickedLocation != null) {
      final controller = await _controllerCompleter.future;
      controller.moveCamera(CameraUpdate.newLatLng(_pickedLocation!));
      _addSymbolAtLocation(_pickedLocation!);
    }
  }

  void _onCameraIdle() {
    if (_controller != null) {
      LatLng center = _controller!.cameraPosition!.target;
      setState(() {
        _pickedLocation = center;
      });
    }
  }

  void _onMapTap(Point<double> point, LatLng coordinates) {
    setState(() {
      _pickedLocation = coordinates;
    });
    _controller?.clearSymbols();
    _addSymbolAtLocation(coordinates);
  }

  void _addSymbolAtLocation(LatLng location) async {
    final controller = await _controllerCompleter.future;
    if (location != null) {
      controller.addSymbol(
        SymbolOptions(
          geometry: location,
          iconImage: "assets/icons/mapPin.png",
        ),
      );
    }
  }

  void _onPickLocation() {
    if (_pickedLocation != null) {
      widget.onLocationPicked(_pickedLocation!);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick Location'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _onPickLocation,
          )
        ],
      ),
      body: MapboxMap(
        accessToken: "sk.eyJ1IjoibW9oYW1tYWRzb3FhcjEwMSIsImEiOiJjbHUyM3Rwc2owc2p6MmtrMWg1eTNjb25oIn0.uP5k1FrxSDNNBjWo1LdSlg",
        onMapCreated: _onMapCreated,
        styleString: "mapbox://styles/mapbox/dark-v11",
        initialCameraPosition: CameraPosition(
          target: _pickedLocation ?? LatLng(37.7749, -122.4194), // Default location if null
          zoom: 14.0,
        ),
        onCameraIdle: _onCameraIdle,
        onMapClick: _onMapTap,
      ),
    );
  }
}
