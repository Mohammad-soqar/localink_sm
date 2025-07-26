import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/event.dart';
import 'package:localink_sm/screens/add_event.dart';
import 'package:localink_sm/utils/Online_status.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/location_service.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:localink_sm/widgets/event_details.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class LocaMap extends StatefulWidget {
  const LocaMap({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocaMapState createState() => _LocaMapState();
}

class _LocaMapState extends State<LocaMap> with SingleTickerProviderStateMixin {
  String? userLocation;
  MapboxMapController? mapController;
  Location location = Location();
  Symbol? _userSymbol;
  double _currentZoom = 15.0;
  late Future<String?> userImageFuture;
  Map<String, Symbol> friendMarkers = {};
  Map<String, Uint8List> imageCache = {};
  Map<String, Symbol> eventMarkers = {};
  late AnimationController _animationController;
  late Animation<double> _animation;
  Map<String, Circle> eventCircles = {};
  bool isBusinessAccount = false;

  final databaseReference = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://localink-778c5-default-rtdb.europe-west1.firebasedatabase.app/',
  );

  @override
  void initState() {
    super.initState();
    userImageFuture = getCurrentUserImage();
    initializeMap();

    /*  _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ); */
  }

  void initializeMap() {
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
        String? photoUrl = userSnapshot.get('photoUrl') as String?;
        isBusinessAccount = userSnapshot.get('isBusinessAccount');
        return photoUrl;
      }
    }

    return null;
  }

  Future<Uint8List> loadImageFromAssets2(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMapController controller) {
    setState(() {
      mapController = controller;
      mapController!.onSymbolTapped.add(_onSymbolTapped);
    });
    mapController!.addListener(_onCameraIdle);
    print("Map controller initialized.");
  }

  Future<void> _addImageFromStorage() async {
    try {
      // Get the current user's ID
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // Get the reference to the image in Firebase Storage
      Reference ref =
          FirebaseStorage.instance.ref('user_pins/$userId/normal_pin.png');

      // Download the image as Uint8List
      final Uint8List? list = await ref.getData();

      if (list != null) {
        // Add image to the map
        await mapController?.addImage("mapPin", list);
        print("Image added to the map.");
      } else {
        print("Image not found in storage.");
      }
    } catch (e) {
      print("Error adding image: $e");
    }
  }

  Future<void> _addSource() async {
    var locationService = LocationService();
    var currentLocation = locationService.currentLocation;

    try {
      await mapController?.addSource(
        "my-source",
        GeojsonSourceProperties(
          data: {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "geometry": {
                  "type": "Point",
                  "coordinates": [
                    currentLocation?.longitude,
                    currentLocation?.latitude
                  ]
                },
                "properties": {"title": "Mapbox DC", "icon": "mapPin"}
              }
            ]
          },
        ),
      );
      print("Source added to the map.");
    } catch (e) {
      print("Error adding source: $e");
    }
  }

  void _refreshMap() {
    // Your logic to refresh the map goes here
    setState(() {
      // Update the state to refresh the map
    });
  }

  Future<void> _addSymbolLayer() async {
    try {
      await mapController?.addSymbolLayer(
        "my-source",
        "my-symbol-layer",
        const SymbolLayerProperties(
          iconImage: "mapPin",
          iconSize: 1.2,
          textSize: 12.0,
          textOffset: [0, 1.5],
          textAnchor: "top",
        ),
      );
      print("Symbol layer added to the map.");
    } catch (e) {
      print("Error adding symbol layer: $e");
    }
  }

  void _onStyleLoaded() {
    print("Style is fully loaded.");
    if (mapController != null) {
      _initializeMapFeatures();
    } else {
      print("Map controller is not ready when style is loaded.");
    }
  }

  Future<void> _initializeMapFeatures() async {
    _showFriendsLocationsRealTime();
    _showEventsLocations();
    _showUserLocationBasic();
    await _addImageFromStorage();
    await _addSource();
    await _addSymbolLayer();
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

  Future<Uint8List> _getFriendPin(String userId) async {
    // Assuming the pin is stored as `normal_pin.png` in `user_pins/{userId}/`
    Reference ref =
        FirebaseStorage.instance.ref('user_pins/$userId/normal_pin.png');
    Uint8List? pinImage = await ref.getData();
    if (pinImage != null) {
      return pinImage;
    } else {
      throw Exception('Pin image not found for user: $userId');
    }
  }

  void _showFriendsLocationsRealTime() {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((userDoc) {
        var following = List<String>.from(userDoc.data()?['following'] ?? []);
        for (String friendId in following) {
          FirebaseFirestore.instance
              .collection('user_locations')
              .doc(friendId)
              .snapshots()
              .listen((friendLocationDoc) async {
            try {
              if (friendLocationDoc.exists) {
                bool isOnline = await isFriendOnline(friendId);
                if (isOnline) {
                  var locData = friendLocationDoc.data()!;
                  LatLng friendLatLng =
                      LatLng(locData['latitude'], locData['longitude']);
                  Uint8List pinImage = await _getFriendPin(friendId);
                  _updateOrRemoveFriendMarker(friendId, friendLatLng, pinImage);
                } else {
                  _removeFriendMarker(friendId);
                }
              } else {
                _removeFriendMarker(friendId);
              }
            } catch (e) {
              print("Error handling friend locations: $e");
            }
          });
        }
      });
    }
  }

  bool _isWithinRange(LatLng friendLatLng) {
    // Assuming LocationService keeps the latest location updated
    var locationService = LocationService();
    var currentLocation = locationService.currentLocation;

    if (currentLocation == null) {
      print("Current location is not available.");
      return false;
    }

    double distance = calculateDistance(
        currentLocation.latitude!,
        currentLocation.longitude!,
        friendLatLng.latitude,
        friendLatLng.longitude);

    return distance <= 700; // Check if the distance is within 700 meters
  }

  void _addFriendMarker(String friendId, LatLng location, Uint8List pinImage) {
    if (friendMarkers.containsKey(friendId)) {
      // Update existing marker
      mapController?.updateSymbol(
        friendMarkers[friendId]!,
        SymbolOptions(
          geometry: location,
          zIndex: 1,
        ),
      );
    } else {
      // Add the image to the map and then add the marker
      mapController?.addImage(friendId, pinImage).then((_) {
        mapController
            ?.addSymbol(
          SymbolOptions(
            geometry: location,
            iconImage:
                friendId, // Use the friendId as the identifier for the image
            iconSize: 0.8,
            zIndex: 1,
          ),
        )
            .then((symbol) {
          friendMarkers[friendId] = symbol;
        });
      }).catchError((error) {
        print('Error adding image: $error');
      });
    }
  }

  Future<bool> isFriendOnline(String friendId) async {
    DatabaseReference ref = databaseReference.ref('status/$friendId/online');
    DataSnapshot snapshot = await ref.get();
    return snapshot.exists && snapshot.value == true;
  }

  OnlineStatusCache onlineStatusCache = OnlineStatusCache();

  void _updateOrRemoveFriendMarker(
      String friendId, LatLng location, Uint8List pinImage) async {
    bool online = await onlineStatusCache.isFriendOnline(friendId);
    if (online && _isWithinRange(location)) {
      _addFriendMarker(friendId, location, pinImage);
    } else {
      _removeFriendMarker(friendId);
    }
  }

  Timer? _debounceTimer;

  void debounce(VoidCallback action, int milliseconds) {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void _removeFriendMarker(String friendId) {
    if (friendMarkers.containsKey(friendId)) {
      mapController?.removeSymbol(friendMarkers[friendId]!);
      friendMarkers.remove(friendId);
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3;
    double phi1 = lat1 * pi / 180;
    double phi2 = lat2 * pi / 180;
    double deltaPhi = (lat2 - lat1) * pi / 180;
    double deltaLambda = (lon2 - lon1) * pi / 180;

    double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  Future<void> _showUserLocationBasic() async {
    var locationService = LocationService();
    var currentLocation = locationService.currentLocation;
    if (currentLocation != null &&
        currentLocation.latitude != null &&
        currentLocation.longitude != null) {
      _addBasicUserLocationPin(currentLocation);
      String address = await LocationUtils.getAddressFromLatLng(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );
      setState(() {
        userLocation =
            '${currentLocation.latitude}, ${currentLocation.longitude}';
        userLocation = address;
      });
    } else {
      print("Location is not available or incomplete.");
    }
  }

  void _addBasicUserLocationPin(LocationData location) {
    if (mapController == null) {
      print("Map controller is null when trying to add a symbol.");
      return;
    }
    if (mapController == null ||
        location.latitude == null ||
        location.longitude == null) {
      print("Map controller or location data is not ready.");
      return;
    }
    final double latitude = location.latitude ?? 0.0; // Default to 0.0 if null
    final double longitude =
        location.longitude ?? 0.0; // Default to 0.0 if null
    final LatLng latLng = LatLng(latitude, longitude);

    try {
      mapController?.addSymbol(SymbolOptions(
        geometry: latLng,
        iconImage: 'assets/icons/mapPin2.png',
        zIndex: 3, // Set a higher zIndex value
      ));
      mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      mapController
          ?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: latLng,
        zoom: 14.0,
      )));
      _addCircle(latitude, longitude, 700);
    } catch (e) {
      print("Error adding symbol or animating camera: $e");
    }
  }

  Future<void> _loadDetailedUserLocation() async {
    var locationService = LocationService();
    var currentLocation = locationService.currentLocation;
    if (currentLocation == null) return;

    String address = await LocationUtils.getAddressFromLatLng(
      currentLocation.latitude!,
      currentLocation.longitude!,
    );

    final String? networkImageUrl = await userImageFuture;
    if (networkImageUrl != null) {
      final response = await http.get(Uri.parse(networkImageUrl));
      if (response.statusCode == 200) {
        /*  ui.Image pinImage =
            await loadImageFromAssets('assets/icons/mapPin.png');
        ui.Image userImage = await loadImageFromBytes(response.bodyBytes); 
         Uint8List combinedImageBytes =
            await createCustomMarkerImage(pinImage, userImage);
        await mapController?.addImage('custom-pin', combinedImageBytes); */

        if (_userSymbol != null) {
          await mapController?.removeSymbol(_userSymbol!);
        }

        _userSymbol = await mapController?.addSymbol(SymbolOptions(
          geometry:
              LatLng(currentLocation.latitude!, currentLocation.longitude!),
          iconImage: networkImageUrl,
          iconSize: 0.8,
          zIndex: 3, // Set a higher zIndex value
        ));

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

    int totalPoints = 500;

    for (int i = 0; i < totalPoints; i++) {
      double angle = (i * (360 / totalPoints)).toDouble();
      LatLng point =
          _calculateCoordinate(latitude, longitude, radiusInMeters, angle);
      circlePoints.add(point);
    }

    circlePoints.add(circlePoints.first);
    try {
      mapController?.addLine(LineOptions(
        geometry: circlePoints,
        lineColor: "#2AF89B",
        lineWidth: 5.0,
        lineOpacity: 1,
      ));
    } catch (e) {
      print("Error adding symbol or animating camera: $e");
    }
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

  final ArgumentCallbacks<Symbol> onSymbolTapped = ArgumentCallbacks<Symbol>();

  /*  Future<Uint8List> createCustomMarkerImage(
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
  } */

  void _showEventsLocations() {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'approved') // Only show approved events
          .snapshots()
          .listen((snapshot) {
        for (var eventDoc in snapshot.docs) {
          var eventData = eventDoc.data() as Map<String, dynamic>;
          var eventId = eventData['id'];
          var latitude = eventData['latitude'];
          var longitude = eventData['longitude'];
          var pinUrl = eventData['pinUrl'];
          var pinColor = eventData['pinColor'];

          LatLng eventLocation = LatLng(latitude, longitude);
          print(pinColor);
          _addEventMarker(eventId, eventLocation, pinUrl, pinColor);
        }
      });
    }
  }

  void _addEventMarker(
      String eventId, LatLng location, String pinUrl, String pinColor) async {
    if (eventMarkers.containsKey(eventId)) {
      mapController?.updateSymbol(
          eventMarkers[eventId]!,
          SymbolOptions(
            geometry: location,
            zIndex: 0,
          ));
    } else {
      if (!imageCache.containsKey(pinUrl)) {
        try {
          final Uint8List imageBytes = await _downloadImage(pinUrl);
          imageCache[pinUrl] = imageBytes; // Cache the image
          await _addImageToMap(eventId, imageBytes); // Add image to map
        } catch (e) {
          print('Error downloading or caching image: $e');
          return;
        }
      } else {
        await _addImageToMap(eventId, imageCache[pinUrl]!); // Use cached image
      }

    
    }
  }



  void _onCameraIdle() {
    setState(() {
      _currentZoom = mapController!.cameraPosition!.zoom;
      _updateMarkersVisibility();
    });
  }

  void _updateMarkersVisibility() {
    for (var eventId in eventMarkers.keys) {
      if (_currentZoom < 10.0) {
        mapController?.removeSymbol(eventMarkers[eventId]!);
      } else {
        // Re-add marker if it was removed
        var eventLocation = eventMarkers[eventId]!.options.geometry;
        _addSymbol(eventId, eventLocation!);
      }
    }
  }

  void _addSymbol(String eventId, LatLng location) {
    if (eventMarkers.containsKey(eventId)) {
      mapController?.removeSymbol(eventMarkers[eventId]!);
    }

    // Add new symbol
    mapController
        ?.addSymbol(SymbolOptions(
      geometry: location,
      iconImage: eventId, // Use the eventId as the image identifier
      iconSize: 0.8,
    ))
        .then((symbol) {
      eventMarkers[eventId] = symbol;
    });
  }

  Future<Uint8List> _downloadImage(String url) async {
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download image from URL');
    }
  }

  Future<void> _addImageToMap(String name, Uint8List bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    final ui.Image image = await completer.future;
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List imageBytes = byteData!.buffer.asUint8List();
    mapController?.addImage(name, imageBytes);
  }

  void _onSymbolTapped(Symbol symbol) {
    if (symbol.data != null && symbol.data!.containsKey('id')) {
      String tappedSymbolId = symbol.data!['id'].toString();
      _showEventInformation(tappedSymbolId);
      print('Tapped on symbol with id: $tappedSymbolId');
    } else {
      print('Symbol data is null or does not contain an id.');
    }
  }

  void _showEventInformation(String eventId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              EventDetails(eventId: eventId),
              Positioned(
                right: -15.0,
                top: -15.0,
                child: InkResponse(
                  onTap: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const CircleAvatar(
                    child: Icon(Icons.close),
                    backgroundColor: highlightColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

//ios: sk.eyJ1IjoibW9oYW1tYWRzb3FhcjEwMSIsImEiOiJjbHVkYzVrMzEwbjFpMmxuenpxM2Eybm5nIn0.S4pjUr0pwYqsJOzpJo73vQ
  @override
  Widget build(BuildContext context) {
    print("Building widget - mapController is: $mapController");

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
        annotationOrder: const <AnnotationType>[
          AnnotationType.line,
          AnnotationType.circle,
          AnnotationType.symbol,
        ],
      ),
      isBusinessAccount
          ? Positioned(
              top: 50,
              right: 0,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddEventPage(),
                    ),
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
              ))
          : Container(),
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
                  (userLocation?.length ?? 0) > 36
                      ? '${userLocation?.substring(0, 30)}...'
                      : userLocation ?? 'Fetching Location',
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}