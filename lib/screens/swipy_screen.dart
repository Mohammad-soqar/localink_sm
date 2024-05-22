import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:localink_sm/widgets/map-picker.dart';
import 'package:localink_sm/widgets/video_card.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

import 'package:video_thumbnail/video_thumbnail.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({Key? key}) : super(key: key);

  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final ScrollController _scrollController = ScrollController();
  String? userLocation;
  late Stream<List<String>> followingListStream;
  String selectedOption = '';
  PageController _pageController = PageController();
  List<VideoPlayerController> _controllers = [];
  List<Future<void>> _initializations = [];
  bool _loadingInitialized = false;
  List<String> _thumbnails = [];

  double userLatitude = 0.0;
  double userLongitude = 0.0;
  bool _isFetchingPosts = false;
  DocumentSnapshot? _lastDocument;
  List<DocumentSnapshot> _posts = [];
  bool _hasMorePosts = true;

  @override
  void initState() {
    super.initState();

    _determinePosition();
    followingListStream = _getUserFollowingList();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchPosts();
      }
    });

    _fetchPosts();
  }

  Future<void> _preloadVideos() async {
    // Dispose old controllers if any
    _controllers.forEach((controller) => controller.dispose());
    _controllers.clear();
    _initializations.clear();
    _thumbnails.clear(); // Clear existing thumbnails

    for (var post in _posts) {
      String mediaUrl = await getMediaUrl(post); // Correctly handle as Future
      var controller = VideoPlayerController.network(mediaUrl);
      _controllers.add(controller);
      _initializations.add(controller.initialize());

      // Thumbnail generation and caching
      String? thumb = await VideoThumbnail.thumbnailFile(
        video: mediaUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
      );

      _thumbnails
          .add(thumb ?? ''); // Add thumbnail or an empty string if it fails
    }

    // Wait for all video controllers to be initialized
    await Future.wait(_initializations);
  }

  Future<String> getMediaUrl(DocumentSnapshot post) async {
    var mediaSnap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(post.id)
        .collection('postMedia')
        .get();
    var mediaUrl = mediaSnap.docs.first.data()['mediaUrl'] as String;
    return mediaUrl;
  }

  Future<String> getVideoTypeAsync() {
    String videoType = "videos";
    return Future.value(videoType);
  }

  Future<void> _fetchPosts() async {
    if (!_hasMorePosts || _isFetchingPosts) return;
    _isFetchingPosts = true;

    var postTypeSnapshot = await FirebaseFirestore.instance
        .collection('postTypes')
        .where('postType_name', isEqualTo: 'videos')
        .limit(1)
        .get();

    if (postTypeSnapshot.docs.isEmpty) {
      print('No postType found for videos');
      _isFetchingPosts = false;
      return;
    }

    DocumentReference videoTypeRef = postTypeSnapshot.docs.first.reference;

    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('postType', isEqualTo: videoTypeRef)
        .orderBy('createdDatetime', descending: true)
        .limit(10);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    List<String> userFollowingList = List<String>.from(followingList);
    userFollowingList.add(userId);

    query = query.where('uid', whereIn: userFollowingList);

    QuerySnapshot querySnapshot = await query.get();

    if (querySnapshot.docs.isEmpty) {
      _hasMorePosts = false;
      
    } else {
      _lastDocument = querySnapshot.docs.last;
      _posts.addAll(querySnapshot.docs);
      await _preloadVideos(); // Preload videos after posts are fetched
    }

    _isFetchingPosts = false;
    if (mounted) setState(() {});
  }

  Stream<List<String>> _getUserFollowingList() async* {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    yield List<String>.from(followingList);
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      String address = await LocationUtils.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );
      setState(() {
        userLocation = address;
        userLatitude = position.latitude;
        userLongitude = position.longitude;
      });
    } catch (e) {
      print('Error getting current position: $e');
    }
  }

  void _showOptionsPanel(BuildContext context) async {
    String location;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      location = await LocationUtils.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      print('Error getting current position: $e');
      location = 'Error fetching location';
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: darkBackgroundColor, // Change to your darkBackgroundColor
            boxShadow: [
              BoxShadow(
                color: Colors.blue
                    .withOpacity(0.01), // Change to your highlightColor
                spreadRadius: 3,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white, // Set the default color
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(
                        text: location ?? 'Fetching location...',
                      ),
                      const TextSpan(
                        text: '  (Current Location)',
                        style: TextStyle(
                          color: Colors
                              .grey, // Set the color for "(Current Location)"
                          fontSize:
                              12, // Set the font size for "(Current Location)"
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () async {
                  Position position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high);
                  String address = await LocationUtils.getAddressFromLatLng(
                      position.latitude, position.longitude);

                  setState(() {
                    selectedOption = 'currentLocation';
                    userLocation = address;
                    userLatitude = position.latitude;
                    userLongitude = position.longitude;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Global Content'),
                onTap: () {
                  setState(() {
                    selectedOption = 'global';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Visit Area'),
                onTap: () {
                  _showMapPicker(context); // Show the map picker dialog
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMapPicker(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible:
          true, // Allows dismissing the dialog by tapping outside of it
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors
              .transparent, // Transparent background to apply custom decoration
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height *
                    0.7, // Adjust size as needed
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                ),
                padding: EdgeInsets.all(20),
                child: MapPickerWidget(
                  onLocationSelected: (LatLng selectedLocation) {
                    setState(() {
                      selectedOption = 'visitArea';
                      userLatitude = selectedLocation.latitude;
                      userLongitude = selectedLocation.longitude;
                    });
                    Navigator.of(context)
                        .pop(); // Close the dialog after selection
                  },
                ),
              ),
              Positioned(
                right: -15.0, // Adjust position as needed
                top: -15.0, // Adjust position as needed
                child: InkResponse(
                  onTap: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: CircleAvatar(
                    child: Icon(Icons.close),
                    backgroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double calculateDistance(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const int radiusOfEarth = 6371;

    // Convert degrees to radians
    double startLatRad = startLat * (3.141592653589793 / 180);
    double startLonRad = startLon * (3.141592653589793 / 180);
    double endLatRad = endLat * (3.141592653589793 / 180);
    double endLonRad = endLon * (3.141592653589793 / 180);

    // Calculate the change in coordinates
    double latChange = endLatRad - startLatRad;
    double lonChange = endLonRad - startLonRad;

    // Haversine formula
    double a = (sin(latChange / 2) * sin(latChange / 2)) +
        (cos(startLatRad) *
            cos(endLatRad) *
            sin(lonChange / 2) *
            sin(lonChange / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Calculate the distance
    double distance = radiusOfEarth * c;

    return distance;
  }

  Future<void> _refreshFeed() async {
    _lastDocument = null;
    _posts.clear();
    _hasMorePosts = true;
    await _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty ||
        _controllers.any((c) => !c.value.isInitialized)) {
      return Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _controllers.length,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, index) {
        return VideoCard(
          snap: _posts[index].data() as Map<String,
              dynamic>, // Assuming _posts contains your Firestore data
          controller: _controllers[index],
          thumbnailUrl:
              _thumbnails[index], // Pass the corresponding thumbnail URL
        );
      },
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
