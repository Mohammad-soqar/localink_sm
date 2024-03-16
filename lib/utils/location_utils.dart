 import 'package:geocoding/geocoding.dart';

class LocationUtils {
  static Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      Placemark place = placemarks[0];
      String address = '${place.street}, ${place.subAdministrativeArea}, ${place.country}';
      return address;
    } catch (e) {
      print(e);
      return '';
    }
  }
}