import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:localink_sm/utils/RestrictedAreasService.dart';

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

class MapPickerScreen extends StatefulWidget {
  final Function(LatLng) onLocationPicked;

  const MapPickerScreen({Key? key, required this.onLocationPicked}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late MapboxMap _mapboxMap;
  late CircleAnnotationManager _circleManager;
  late PointAnnotationManager _pointManager;

  List<LatLng> _restrictedAreas = [];
  LatLng? _pickedLocation;

  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchRestrictedAreas();
  }

  Future<void> _fetchRestrictedAreas() async {
    final service = RestrictedAreasService();
    List<LatLng> areas = await service.fetchRestrictedAreas();
    setState(() => _restrictedAreas = areas);
  }

  Future<void> _addRestrictedAreas() async {
    if (_circleManager == null) return;
    for (var area in _restrictedAreas) {
      await _circleManager.create(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(area.longitude, area.latitude)),
        circleRadius: 8,
        circleColor: "#116640",
        circleOpacity: 0.5,
      ));
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _circleManager = await _mapboxMap.annotations.createCircleAnnotationManager();
    _pointManager = await _mapboxMap.annotations.createPointAnnotationManager();

    await _addRestrictedAreas();
    if (_pickedLocation != null) {
      await _moveCameraTo(_pickedLocation!);
      await _addSymbolAt(_pickedLocation!);
    }
  }

  Future<void> _moveCameraTo(LatLng location) async {
    await _mapboxMap.setCamera(CameraOptions(
      center: Point(coordinates: Position(location.longitude, location.latitude)),
      zoom: 14,
    ));
  }

  Future<void> _addSymbolAt(LatLng location) async {
    await _pointManager.deleteAll();
    await _pointManager.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(location.longitude, location.latitude)),
      image: await _loadImageFromAsset("assets/icons/mapPin2.png"),
      iconSize: 1.5,
    ));
  }

  Future<Uint8List> _loadImageFromAsset(String assetPath) async {
    final ByteData byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }

  void _onMapTap(ScreenCoordinate _, LatLng latLng) async {
    if (_isRestrictedArea(latLng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add events in restricted areas')),
      );
      return;
    }

    setState(() => _pickedLocation = latLng);
    await _addSymbolAt(latLng);
  }

  bool _isRestrictedArea(LatLng location) {
    for (final area in _restrictedAreas) {
      if (_calculateDistance(location, area) < 0.05) return true;
    }
    return false;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((p2.latitude - p1.latitude) * p) / 2 +
        c(p1.latitude * p) *
            c(p2.latitude * p) *
            (1 - c((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
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
        title: const Text('Pick Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _onPickLocation,
          ),
        ],
      ),
      body: MapWidget(
        key: _mapKey,
        resourceOptions: ResourceOptions(
          accessToken: "sk.eyJ1IjoibW9oYW1tYWRzb3FhcjEwMSIsImEiOiJjbHUyM3Rwc2owc2p6MmtrMWg1eTNjb25oIn0.uP5k1FrxSDNNBjWo1LdSlg",
        ),
        styleUri: MapboxStyles.MAPBOX_DARK,
        cameraOptions: CameraOptions(
          center: Point(
            coordinates: Position(
              _pickedLocation?.longitude ?? 28.99925,
              _pickedLocation?.latitude ?? 40.99437,
            ),
          ),
          zoom: 10.0,
        ),
        mapOptions: MapOptions(pixelRatio: MediaQuery.of(context).devicePixelRatio),
        onMapCreated: _onMapCreated,
        onTapListener: _onMapTap,
      ),
    );
  }
}
