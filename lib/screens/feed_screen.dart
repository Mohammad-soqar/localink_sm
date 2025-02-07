import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/screens/chats_screen.dart';
import 'package:localink_sm/screens/create_post.dart';
import 'package:localink_sm/screens/notification_screen.dart';
import 'package:localink_sm/screens/notification_test_page.dart';
import 'package:localink_sm/services/visiting_status.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/location_service.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:localink_sm/utils/service_locator.dart';
import 'package:localink_sm/widgets/map-picker.dart';
import 'package:localink_sm/widgets/new_map_picker.dart';
import 'package:localink_sm/widgets/post_card.dart';
import 'package:localink_sm/widgets/updates_card.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';

class FeedScreen extends StatefulWidget {
  final String? selectedOption;
  final double? userLatitude;
  final double? userLongitude;
  final String? visitedAreaLocation;
  const FeedScreen({
    Key? key,
    this.selectedOption,
    this.userLatitude,
    this.userLongitude,
    this.visitedAreaLocation,
  }) : super(key: key);


  

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  String? userLocation;
  String? visitedAreaLocation;
  final ScrollController _visibilityScrollController =
      ScrollController(); // New controller
  bool _isVisible = true;
  late Stream<List<String>> followingListStream;
  String selectedOption = '';
  double userLatitude = 0.0;
  double userLongitude = 0.0;
  bool _isFetchingPosts = false;
  DocumentSnapshot? _lastDocument;
  List<DocumentSnapshot> _posts = []; // Posts to display
  bool _hasMorePosts = true; // Flag to check if more posts are available
  final VisitingStatus visitingStatus = VisitingStatus();

  @override
  void initState() {
    super.initState();
    _determinePosition();
    followingListStream = _getUserFollowingList();
    selectedOption = widget.selectedOption ?? '';
    userLatitude = widget.userLatitude ?? 0.0;
    userLongitude = widget.userLongitude ?? 0.0;
    visitedAreaLocation = widget.visitedAreaLocation;
    _scrollController.addListener(_fetchPostsListener);
    _visibilityScrollController
        .addListener(_visibilityListener); // Add listener to new controller

    _fetchPosts();
  }

  void _fetchPostsListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _fetchPosts();
    }
  }

  void _visibilityListener() {
    if (_visibilityScrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isVisible) {
        setState(() {
          _isVisible = false;
        });
      }
    } else if (_visibilityScrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_fetchPostsListener);
    _visibilityScrollController.removeListener(_visibilityListener);
    _scrollController.dispose();
    _visibilityScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    if (!_hasMorePosts || _isFetchingPosts) return;

    _isFetchingPosts = true;

    Query query = FirebaseFirestore.instance
        .collection('posts')
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
      if (mounted) {
        setState(() {
          userLocation = address;
          userLatitude = position.latitude;
          userLongitude = position.longitude;
        });
      }
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
                  if (mounted) {
                    setState(() {
                      selectedOption = 'currentLocation';
                      userLocation = address;
                      userLatitude = position.latitude;
                      userLongitude = position.longitude;
                      visitingStatus.clearUserVisiting();
                    });
                  }
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Global Content'),
                onTap: () {
                  if (mounted) {
                    setState(() {
                      selectedOption = 'global';
                    });
                  }
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
                padding: EdgeInsets.all(5),
                child: MapPickerScreen(
                  onLocationPicked: (LatLng selectedLocation) async {
                    // Perform asynchronous operations
                    double latitude = selectedLocation.latitude;
                    double longitude = selectedLocation.longitude;
                    String? location = await LocationUtils.getAddressFromLatLng(
                        latitude, longitude);

                    // Update the state
                    if (mounted) {
                      setState(() {
                        selectedOption = 'visitArea';
                        userLatitude = latitude;
                        userLongitude = longitude;
                        visitingStatus.setUserVisiting(latitude, longitude);
                        visitedAreaLocation = location;
                      });
                    }

                    // Close the dialog after selection
                    Navigator.of(context).pop();
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

  Future<String> getPostTypeName(DocumentReference postTypeRef) async {
    // Fetch the document using the reference and extract the post type name
    DocumentSnapshot postTypeSnapshot = await postTypeRef.get();
    return postTypeSnapshot[
        'postType_name']; // assuming the field is called 'name'
  }

  @override
  Widget build(BuildContext context) {
    final LocationService _locationService = locator<LocationService>();

    final model.User? user = Provider.of<UserProvider>(context).getUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkBackgroundColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset(
              'assets/logo-with-name-H.svg',
              height: 20,
            ),
            Row(
              children: [
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/Navigation/notification.svg',
                    height: 24,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NotificationsPage(),
                    ),
                  ),
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/Navigation/add-post.svg',
                    height: 24,
                    // ignore: deprecated_member_use
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PostPage(),
                    ),
                  ),
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/Navigation/messages.svg',
                    height: 24,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: Column(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isVisible ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: userLocation != null
                    ? () => _showOptionsPanel(context)
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(6.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5.0, vertical: 1.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: highlightColor,
                      width: 2.0,
                    ),
                    color: darkBackgroundColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: highlightColor.withOpacity(0.01),
                        spreadRadius: 3,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
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
                      SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          selectedOption == 'global'
                              ? 'Global'
                              : (selectedOption == 'visitArea' &&
                                      visitedAreaLocation != null)
                                  ? visitedAreaLocation!
                                  : (userLocation ?? 'Select Area'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedOption != 'global')
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: highlightColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: _fetchPosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _hasMorePosts ? _posts.length + 1 : _posts.length,
                    itemBuilder: (context, index) {
                      if (index >= _posts.length) {
                        return Center(child: Container());
                      }
                      DocumentSnapshot<Map<String, dynamic>> post =
                          _posts[index]
                              as DocumentSnapshot<Map<String, dynamic>>;
                      bool shouldIncludePost = false;
                      if (selectedOption == 'global') {
                        shouldIncludePost = true;
                      } else {
                        double postLatitude =
                            post.data()?['latitude'] as double;
                        double postLongitude =
                            post.data()?['longitude'] as double;
                        double distance = calculateDistance(
                          userLatitude,
                          userLongitude,
                          postLatitude,
                          postLongitude,
                        );
                        double distanceThreshold =
                            selectedOption == 'visitArea' ? 0.7 : 0.7;
                        shouldIncludePost = distance <= distanceThreshold;
                      }
                      if (shouldIncludePost) {
                        return FutureBuilder<String>(
                          future: getPostTypeName(post.data()?['postType']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: Container());
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else if (snapshot.hasData) {
                              if (snapshot.data == 'updates') {
                                return TextPostCard(
                                  key: ValueKey(post.id), 
                                  snap: post.data()!,
                                );
                              } else {
                                return PostCard(
                                  key: ValueKey(post.id),
                                  snap: post.data()!,
                                );
                              }
                            } else {
                              return Container();
                            }
                          },
                        );
                      } else {
                        return Container();
                      }
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
