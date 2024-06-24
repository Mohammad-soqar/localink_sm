import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/Admin_event_approval_screen.dart';
import 'package:localink_sm/screens/SubscribedEventsPage.dart';
import 'package:localink_sm/screens/add_tester_screen.dart';
import 'package:localink_sm/screens/edit_profile_screen.dart';
import 'package:localink_sm/screens/feed_screen.dart';
import 'package:localink_sm/screens/followers.dart';
import 'package:localink_sm/screens/following.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/screens/chat.dart';
import 'package:localink_sm/screens/my_events_screen.dart';
import 'package:localink_sm/screens/profile_activity_screen.dart';
import 'package:localink_sm/screens/settings_screen.dart';
import 'package:localink_sm/screens/temp_pin_gen.dart';
import 'package:localink_sm/screens/users_online_screen.dart';
import 'package:localink_sm/services/visiting_status.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:localink_sm/utils/notifications_util.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/widgets/new_map_picker.dart';
import 'package:localink_sm/widgets/updates_card.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  var userData = {};
  final String allowedUserId = 'xh8FLottZeNttmgFq5hRmSQYXlp2';
  final VisitingStatus visitingStatus = VisitingStatus();

  int postLen = 0;
  int followers = 0;
  int following = 0;
  bool isFollowing = false;
  bool isLoading = false;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isDrawerOpen = false;
  model.User? user;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    getData();
  }

  Future<String> getFileType(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final contentType = response.headers['content-type'];
      return contentType ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  Future<bool> isVideo(String url) async {
    try {
      // ignore: deprecated_member_use
      final controller = VideoPlayerController.network(url);
      await controller.initialize();
      controller.dispose();
      return true;
    } catch (e) {
      return false;
    }
  }

  Widget buildMediaItem(Map<String, String> mediaData) {
    String mediaUrl = mediaData['url']!;
    String postTypeName = mediaData['type']!;

    bool isVideo = postTypeName == 'videos';

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.3,
          child: isVideo
              ? FutureBuilder(
                  future: _initializeVideoPlayer(mediaUrl),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return VideoPlayer(
                          snapshot.data as VideoPlayerController);
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  },
                )
              : CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
        ),
        if (isVideo)
          const Positioned(
            top: 8,
            right: 8,
            child: Icon(
              Icons.videocam,
              color: Colors.white,
            ),
          ),
      ],
    );
  }

  Future<VideoPlayerController> _initializeVideoPlayer(String url) async {
    VideoPlayerController controller = VideoPlayerController.network(url);
    await controller.initialize();
    return controller;
  }

  Future<void> openConversation(model.User user) async {
    final FireStoreMethods firestoreMethods = FireStoreMethods();
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Get or create a conversation between the current user and the selected user
    final conversationData = await firestoreMethods
        .getOrCreateConversation([currentUserId, user.uid]);

    String conversationId = conversationData['conversationId'];

    // Navigate to the messaging screen
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MessagePage(user: user, conversationId: conversationId),
      ),
    );
  }

  Future<List<Map<String, String>>> fetchPostMediaUrls() async {
    List<Map<String, String>> mediaData = [];
    try {
      QuerySnapshot postSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .orderBy('createdDatetime', descending: true)
          .get();

      for (var postDoc in postSnap.docs) {
        QuerySnapshot mediaSnap = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postDoc.id)
            .collection('postMedia')
            .get();

        DocumentReference postTypeRef = postDoc['postType'];
        DocumentSnapshot postTypeSnap = await postTypeRef.get();
        String postTypeName = postTypeSnap[
            'postType_name']; // Assuming 'postType_name' field in postType document

        List<String> postMediaUrls =
            mediaSnap.docs.map((doc) => doc['mediaUrl'] as String).toList();
        for (String mediaUrl in postMediaUrls) {
          mediaData.add({'url': mediaUrl, 'type': postTypeName});
        }
      }
      return mediaData;
    } catch (err) {
      print('Error fetching post media: $err');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUpdates() async {
    try {
      // Fetch the postType reference for "Updates"
      DocumentSnapshot postTypeSnap = await FirebaseFirestore.instance
          .collection('postTypes')
          .doc('Fjs1tb1aCMjUouk704fR')
          .get();

      if (!postTypeSnap.exists) {
        print('PostType for Updates does not exist.');
        return [];
      }

      DocumentReference updatesPostTypeRef = postTypeSnap.reference;

      // Fetch posts with the postType reference for "Updates"
      QuerySnapshot postSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .where('postType', isEqualTo: updatesPostTypeRef)
          .orderBy('createdDatetime', descending: true)
          .get();

      List<Map<String, dynamic>> updates = [];

      for (var postDoc in postSnap.docs) {
        updates.add(postDoc.data() as Map<String, dynamic>);
      }

      return updates;
    } catch (err) {
      print('Error fetching updates: $err');
      return [];
    }
  }

  Future<void> getData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      if (widget.uid.isNotEmpty && widget.uid != userId) {
        userId = widget.uid;
      }

      var userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userSnap.exists) {
        user = model.User.fromSnap(userSnap);
      }

      // Get post length
      var postSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: userId)
          .get();

      postLen = postSnap.docs.length;
      userData = userSnap.data()!;
      followers = userSnap.data()!['followers'].length;
      following = userSnap.data()!['following'].length;
      isFollowing = userSnap
          .data()!['followers']
          .contains(FirebaseAuth.instance.currentUser!.uid);
    } catch (e) {
      showSnackBar(
        e.toString(),
        // ignore: use_build_context_synchronously
        context,
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  void toggleDrawer() {
    if (isDrawerOpen) {
      _scaffoldKey.currentState!.closeDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      key: _scaffoldKey,
      drawer: Container(
        child: Drawer(
          backgroundColor: darkBackgroundColor,
          child: ListView(
            children: <Widget>[
              const SizedBox(
                height: 18,
              ),
              SvgPicture.asset(
                'assets/logo-with-name-H.svg',
                height: 20,
              ),
              const SizedBox(
                height: 24,
              ),
              //Settings
             /*  InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AdminDashboard(),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/Settings.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text('Settings & Privacy',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ), */
              /* InkWell(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Use as little space as possible
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/Insights.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8), // Spacing between icon and text
                      const Text('Insights',
                          style: TextStyle(color: Colors.white)), // Text style
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ), */
              //Activity
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ActivityPage(),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Use as little space as possible
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/Activity.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ), // Icon color
                      const SizedBox(width: 8), // Spacing between icon and text
                      const Text('Your Activity',
                          style: TextStyle(color: Colors.white)), // Text style
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              //QR Code

              //Get Verified
           /*    InkWell(
                onTap: () {
                  // Your tap callback code
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Use as little space as possible
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/Verified.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ), // Icon color
                      const SizedBox(width: 8), // Spacing between icon and text
                      const Text('Get Verified',
                          style: TextStyle(color: Colors.white)), // Text style
                    ],
                  ),
                ),
              ), */

              const SizedBox(
                height: 10,
              ),
              //Archived
              TextButton(
                 onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscribedEventsPage(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Use as little space as possible
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/Archive.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ), // Icon color
                      const SizedBox(width: 8), // Spacing between icon and text
                      const Text('Subscribed Events',
                          style: TextStyle(color: Colors.white)), // Text style
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              //Archived
            /*   InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GeneratePinsScreen(),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Use as little space as possible
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/Archive.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ), // Icon color
                      const SizedBox(width: 8), // Spacing between icon and text
                      const Text('gen pin',
                          style: TextStyle(color: Colors.white)), // Text style
                    ],
                  ),
                ),
              ), */
              const SizedBox(
                height: 10,
              ),
              //SignOut
              InkWell(
                onTap: () async {
                  await AuthMethods().signOut(context);
                  // Close the drawer
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                  // Check if the context is still valid before navigating
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min, // Use as little space as possible
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/icons/Profile_icons/SignOut.svg',
                        height: 28,
                        // ignore: deprecated_member_use
                        color: primaryColor,
                      ), // Icon color
                      const SizedBox(width: 8), // Spacing between icon and text
                      const Text('Signout',
                          style: TextStyle(color: Colors.white)), // Text style
                    ],
                  ),
                ),
              ),

              currentUser != null && user?.isBusinessAccount == true
                  ? ListTile(
                      title: const Text('My Events'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MyEventsPage(
                                    userId: currentUser.uid,
                                  )),
                        );
                      },
                    )
                  : Container(),

                

              currentUser != null && currentUser.uid == allowedUserId
                  ? ListTile(
                      title: const Text('Add Tester'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddTesterPage()),
                        );
                      },
                    )
                  : Container(),

              currentUser != null && currentUser.uid == allowedUserId
                  ? ListTile(
                      title: const Text('Approve Events'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AdminEventApprovalPage()),
                        );
                      },
                    )
                  : Container(),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: darkBackgroundColor,
        title: Text(
          userData['username'] ?? '',
        ),
        centerTitle: true,
        leading: FirebaseAuth.instance.currentUser!.uid == widget.uid
            ? Container(
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState!.openDrawer(),
                ),
              )
            : IconButton(
              icon: const Icon(Icons.arrow_back_rounded, ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
      ),
      body: Stack(
        children: [
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: highlightColor,
                            width: 4.0,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.grey,
                          backgroundImage: NetworkImage(userData['photoUrl']),
                          radius: 55,
                        ),
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      Text(
                        // ignore: prefer_interpolation_to_compose_strings
                        '@' + userData['username'],
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                Row(
  mainAxisSize: MainAxisSize.max,
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    buildStatColumn(postLen, "Posts", () {}),
    buildStatColumn(followers, "Followers", () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FollowersPage(userId: widget.uid),
        ),
      );
    }),
    buildStatColumn(following, "Following", () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FollowingPage(userId: widget.uid),
        ),
      );
    }),
  ],
),

                                const SizedBox(
                                  height: 15,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    FirebaseAuth.instance.currentUser!.uid ==
                                            widget.uid
                                        ? TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      EditProfilePage(),
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: highlightColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
                                              ),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 0,
                                                  horizontal: 30.0),
                                              child: Text(
                                                'Edit Profile',
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(),

                                    FirebaseAuth.instance.currentUser!.uid !=
                                            widget.uid
                                        ? isFollowing
                                            ? ElevatedButton(
                                                onPressed: () async {
                                                  await FireStoreMethods()
                                                      .followUser(
                                                    FirebaseAuth.instance
                                                        .currentUser!.uid,
                                                    userData['uid'],
                                                  );

                                                  setState(() {
                                                    isFollowing = false;
                                                    followers--;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      darkLBackgroundColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16.0), // Adjust the border radius as needed
                                                  ),
                                                  side: const BorderSide(
                                                    color: greyColor,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 8.0,
                                                      horizontal:
                                                          20.0), // Adjust the padding as needed
                                                  child: Text(
                                                    'Following',
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : ElevatedButton(
                                                onPressed: () async {
                                                  // Implement the functionality for Follow button
                                                  await FireStoreMethods()
                                                      .followUser(
                                                    FirebaseAuth.instance
                                                        .currentUser!.uid,
                                                    userData['uid'],
                                                  );

                                                  // Retrieve the follower's name and other necessary data
                                                  String followerName =
                                                      "Default Name"; // Default value in case of null

                                                  // Fetch the current user's data to get the follower's name
                                                  var currentUserData =
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(FirebaseAuth
                                                              .instance
                                                              .currentUser!
                                                              .uid)
                                                          .get();

                                                  if (currentUserData.exists) {
                                                    followerName =
                                                        currentUserData.data()![
                                                                'username'] ??
                                                            "Default Name";
                                                  }

                                                  // Send notification to the followed user
                                                  HttpsCallable callable =
                                                      FirebaseFunctions.instance
                                                          .httpsCallable(
                                                              'sendNFollowerNotification');
                                                  await callable.call({
                                                    'userId': userData[
                                                        'uid'], // The ID of the user being followed
                                                    'followerId': FirebaseAuth
                                                        .instance
                                                        .currentUser!
                                                        .uid, // The ID of the follower
                                                    'followerName':
                                                        followerName, // The name of the follower
                                                  });

                                                  setState(() {
                                                    isFollowing = true;
                                                    followers++;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      highlightColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16.0), // Adjust the border radius as needed
                                                  ),
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 8.0,
                                                      horizontal:
                                                          30.0), // Adjust the padding as needed
                                                  child: Text(
                                                    'Follow',
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              )
                                        : Container(), // Empty container if it's the user's own profile

                                    // Visit Area Button (visible only if it's the user's own profile)
                                    FirebaseAuth.instance.currentUser!.uid ==
                                            widget.uid
                                        ? Container() /* TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      SettingsPage(),
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  darkLBackgroundColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
                                              ),
                                              side: const BorderSide(
                                                color: greyColor,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 0,
                                                  horizontal: 35.0),
                                              child: Text(
                                                'Settings',
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ) */
                                        : ElevatedButton(
                                            onPressed: () {
                                              if (user != null) {
                                                openConversation(user!);
                                              } else {}
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  darkLBackgroundColor, // Background color
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                    16.0), // Adjust the border radius as needed
                                              ),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8.0,
                                                  horizontal:
                                                      25.0), // Adjust the padding as needed
                                              child: Text(
                                                'Message',
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(
                          top: 1,
                        ),
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      if (userData['bio'] != null &&
                          userData['bio'].isNotEmpty) ...[
                        Text(
                          userData['bio'],
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                      ],
                      if (userData['link'] != null &&
                          userData['link'].isNotEmpty) ...[
                        InkWell(
                          onTap: () async {
                            String url = userData['link'];
                            if (!url.startsWith('http://') &&
                                !url.startsWith('https://')) {
                              url = 'http://$url';
                            }
                            try {
                              await _launchUrl(url);
                            } catch (e) {
                              print(e);
                            }
                          },
                          child: Text(
                            userData['link'],
                            style: const TextStyle(
                                fontSize: 16, color: Colors.blue),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                      ],
                      const SizedBox(
                        height: 15,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(text: 'Media'), // Tab for photos and videos
                          Tab(text: 'Updates'), // Tab for text-based posts
                        ],
                        controller: _tabController,
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab view for Media
                            FutureBuilder(
                              future: fetchPostMediaUrls(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else if (snapshot.hasError) {
                                  return const Center(
                                      child:
                                          Text('Error fetching media posts'));
                                } else {
                                  List<Map<String, String>> mediaData = snapshot
                                      .data as List<Map<String, String>>;
                                  return GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8.0,
                                      mainAxisSpacing: 8.0,
                                    ),
                                    itemCount: mediaData.length,
                                    itemBuilder: (context, index) {
                                      return buildMediaItem(mediaData[index]);
                                    },
                                  );
                                }
                              },
                            ),

                            // Tab view for Updates
                            FutureBuilder(
                              future: fetchUpdates(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else if (snapshot.hasError) {
                                  return const Center(
                                      child: Text('Error fetching updates'));
                                } else {
                                  List<Map<String, dynamic>> updates = snapshot
                                      .data as List<Map<String, dynamic>>;
                                  return ListView.builder(
                                    itemCount: updates.length,
                                    itemBuilder: (context, index) {
                                      return TextPostCard(snap: updates[index]);
                                    },
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (isDrawerOpen)
            GestureDetector(
              onTap: () {
                toggleDrawer();
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Column buildStatColumn(int num, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Text(
            num.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }


/*  void _showQrCodeDialog(BuildContext context, String profileUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Share Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImage(
                data: profileUrl, // This should be the URL or data you want to encode
                version: QrVersions.auto,
                size: 200.0,
              ),
              SizedBox(height: 10),
              Text(
                'Scan this QR code to view the profile.',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  } */
}
