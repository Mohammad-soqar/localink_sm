import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localink_sm/screens/add_post_screen.dart';
import 'package:localink_sm/screens/comment_screen.dart';
import 'package:localink_sm/screens/verify_email_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/widgets/post_card.dart';
import 'package:geocoding/geocoding.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? userLocation;
  late Future<List<String>> followingListFuture;

  @override
  void initState() {
    super.initState();
    followingListFuture = _getUserFollowingList();
    _determinePosition();
  }

  Future<List<String>> _getUserFollowingList() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    return List<String>.from(followingList);
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

    Position position = await Geolocator.getCurrentPosition();
    await _getAddressFromLatLng(position.latitude, position.longitude);
  }

  Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      Placemark place = placemarks[0];
      String address =
          '${place.street}, ${place.subAdministrativeArea}, ${place.country}';
      setState(() {
        userLocation = address;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkLBackgroundColor,
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
                  onPressed: () {
                    showAboutDialog(
                      context: context,
                      applicationIcon: FlutterLogo(),
                      applicationName: 'LocaLink',
                      applicationVersion: '0.3.0',
                      children: [
                        const Text('This is a beta version'),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/Navigation/add-post.svg',
                    height: 24,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddPostScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/Navigation/messages.svg',
                    height: 24,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => VerifyEmailScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: highlightColor,
                width: 2.0,
              ),
              color: darkLBackgroundColor, // Background color of the container
              borderRadius: BorderRadius.circular(20), // Rounded corners
              boxShadow: [
                BoxShadow(
                  color: highlightColor.withOpacity(0.5), // Shadow color
                  spreadRadius: 3, // Spread radius
                  blurRadius: 5, // Blur radius
                  offset: Offset(0, 3), // changes position of shadow
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
                SizedBox(width: 8.0), // Spacing between icon and text
                Expanded(
                  child: Text(
                    userLocation ??
                        'Fetching location...', // Display the location or a placeholder
                    style: TextStyle(
                      color: Colors.white, // Text color
                      fontSize: 16,
                    ),
                    overflow:
                        TextOverflow.ellipsis, // Prevent text from overflowing
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_back, // Check icon at the end
                    color: highlightColor, // Icon color
                  ),
                  onPressed: () {
                    // Action when check icon is pressed
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: followingListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                        'Error fetching following list: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text('You are not following anyone yet.'),
                  );
                } else {
                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('uid', whereIn: snapshot.data!)
                        .orderBy('datePublished', descending: true)
                        .snapshots(),
                    builder: (context,
                        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return ListView.builder(
                        itemCount: snapshot.data?.docs.length ?? 0,
                        itemBuilder: (context, index) {
                          if (snapshot.data == null ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('No posts available.'),
                            );
                          } else {
                            return PostCard(
                              snap: snapshot.data!.docs[index].data(),
                            );
                          }
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}