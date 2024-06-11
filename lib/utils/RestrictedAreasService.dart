import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mapbox_gl/mapbox_gl.dart';

class RestrictedAreasService {
  final String apiKey = 'AIzaSyAaRdWEmEijKLDStEKnJLjhRPT_Ok1XK4M';

  Future<List<LatLng>> fetchRestrictedAreas() async {
    List<String> placeTypes = [
      'courthouse',
      'police',
      'local_government_office',
      'embassy',
      'city_hall',
      'administrative_area_level_1',
      'administrative_area_level_2'
    ];
    List<LatLng> restrictedAreas = [];

    for (String type in placeTypes) {
      String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json' +
              '?location=41.0082,28.9784' + // Latitude and longitude of Istanbul
              '&radius=50000' + // Search within 50km radius
              '&type=$type' +
              '&key=$apiKey';
      print(url);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        for (var result in data['results']) {
          restrictedAreas.add(LatLng(result['geometry']['location']['lat'],
              result['geometry']['location']['lng']));
        }
      } else {
        throw Exception('Failed to load restricted areas');
      }
    }

    return restrictedAreas;
  }
}
