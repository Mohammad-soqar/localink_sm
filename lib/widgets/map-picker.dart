import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerWidget extends StatefulWidget {
  final Function(LatLng) onLocationSelected;

  const MapPickerWidget({Key? key, required this.onLocationSelected}) : super(key: key);

  @override
  _MapPickerWidgetState createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  late GoogleMapController mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
      // Clear existing markers
      _markers.clear();
      // Add a marker at the selected location
      _markers.add(
        Marker(
          markerId: MarkerId('selectedLocation'),
          position: location,
          infoWindow: InfoWindow(title: 'Selected Location'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? LatLng(41.0082, 28.9784), // Default to Istanbul
                zoom: 11.0,
              ),
              markers: _markers,
              onTap: _onTap,
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  if (_selectedLocation != null) {
                    widget.onLocationSelected(_selectedLocation!);
                    Navigator.pop(context);
                  }
                },
                child: Icon(Icons.check),
              ),
            )
          ],
        ),
      ),
    );
  }
}
