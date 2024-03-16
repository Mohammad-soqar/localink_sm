import 'package:geolocator/geolocator.dart';

Future<Position> getLatLng() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Handle when location service is not enabled
    throw Exception('Location service is not enabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Handle when location permission is denied
      throw Exception('Location permission is denied.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Handle when location permission is permanently denied
    throw Exception('Location permission is permanently denied.');
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return position;
  } catch (e) {
    // Handle errors while getting current position
    print('Error getting current position: $e');
    throw Exception('Error getting current position.');
  }
}