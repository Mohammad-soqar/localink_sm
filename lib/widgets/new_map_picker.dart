import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:localink_sm/utils/RestrictedAreasService.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class MapPickerScreen extends StatefulWidget {
  final Function(LatLng) onLocationPicked;


  const MapPickerScreen({Key? key, required this.onLocationPicked}) : super(key: key);

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  MapboxMapController? _controller;
  LatLng? _pickedLocation;
  Completer<MapboxMapController> _controllerCompleter =
      Completer<MapboxMapController>();
  List<LatLng> _restrictedAreas = [];

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  //  _fetchRestrictedAreas();
  }

  void _setInitialLocation() {
    // Set the initial location here
  }

/*   Future<void> _fetchRestrictedAreas() async {
    RestrictedAreasService service = RestrictedAreasService();
    List<LatLng> areas = await service.fetchRestrictedAreas();
    setState(() {
      _restrictedAreas = areas;
    });
    _displayRestrictedAreas();
  } */

/*   Future<void> _displayRestrictedAreas() async {
    final controller = await _controllerCompleter.future;
    for (var area in _restrictedAreas) {
      controller.addCircle(
        CircleOptions(
          geometry: area,
          circleRadius: 8.0,
          circleColor: "#116640",
          circleOpacity: 0.5,
        ),
      );
    }
  } */

  Future<void> _onMapCreated(MapboxMapController controller) async {
    _controller = controller;
    _controllerCompleter.complete(controller);
    await _moveCameraToCurrentLocation();
  //  _displayRestrictedAreas();
  }

  Future<void> _moveCameraToCurrentLocation() async {
    if (_pickedLocation != null) {
      final controller = await _controllerCompleter.future;
      controller.moveCamera(CameraUpdate.newLatLng(_pickedLocation!));
      _addSymbolAtLocation(_pickedLocation!);
    }
  }

  void _onMapTap(Point<double> point, LatLng coordinates) {
    if (_isRestrictedArea(coordinates)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot add events in restricted areas')),
      );
      return;
    }

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
          iconImage: "assets/icons/mapPin2.png",
        ),
      );
    }
  }

  bool _isRestrictedArea(LatLng coordinates) {
    for (LatLng area in _restrictedAreas) {
      if (_calculateDistance(coordinates, area) < 0.05) {
        // Distance in kilometers
        return true;
      }
    }
    return false;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295; // Math.PI / 180
    var c = cos;
    var a = 0.5 -
        c((point2.latitude - point1.latitude) * p) / 2 +
        c(point1.latitude * p) *
            c(point2.latitude * p) *
            (1 - c((point2.longitude - point1.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
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
        accessToken:
            "sk.eyJ1IjoibW9oYW1tYWRzb3FhcjEwMSIsImEiOiJjbHUyM3Rwc2owc2p6MmtrMWg1eTNjb25oIn0.uP5k1FrxSDNNBjWo1LdSlg",
        onMapCreated: _onMapCreated,
        styleString: "mapbox://styles/mapbox/dark-v11",
        initialCameraPosition: CameraPosition(
          target: _pickedLocation ??
              LatLng(40.99437101906267, 28.99925336148795), // Default location if null
          zoom: 10.0,
        ),
        onMapClick: _onMapTap,
      ),
    );
  }
}
