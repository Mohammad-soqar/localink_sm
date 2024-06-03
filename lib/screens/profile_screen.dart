import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/Admin_event_approval_screen.dart';
import 'package:localink_sm/screens/add_tester_screen.dart';
import 'package:localink_sm/screens/edit_profile_screen.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/screens/chat.dart';
import 'package:localink_sm/screens/profile_activity_screen.dart';
import 'package:localink_sm/screens/users_online_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:localink_sm/widgets/follow_button.dart';

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

  int postLen = 0;
  int followers = 0;
  int following = 0;
  bool isFollowing = false;
  bool isLoading = false;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();
  bool isDrawerOpen = false;
  model.User?
      user; 

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    getData();
  }

  Future<void> openConversation(model.User user) async {
    final FireStoreMethods _firestoreMethods = FireStoreMethods();
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Get or create a conversation between the current user and the selected user
    final conversationData = await _firestoreMethods
        .getOrCreateConversation([currentUserId, user.uid]);

    String conversationId = conversationData['conversationId'];

    // Navigate to the messaging screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MessagePage(user: user, conversationId: conversationId),
      ),
    );
  }

  Future<List<String>> fetchPostMediaUrls() async {
    List<String> mediaUrls = [];
    try {
      // Fetch documents from 'posts' collection based on uid
      QuerySnapshot postSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.uid)
          .orderBy('createdDatetime',
              descending: true) // Order posts by timestamp, newest first
          .get();

      // Iterate through all the documents in the 'posts' collection
      for (var postDoc in postSnap.docs) {
        // Query the 'postMedia' subcollection of each document
        QuerySnapshot mediaSnap = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postDoc.id)
            .collection('postMedia')
            .get();

        // Extract mediaUrls from 'mediaSnap' documents and add them to the list
        List<String> postMediaUrls =
            mediaSnap.docs.map((doc) => doc['mediaUrl'] as String).toList();
        mediaUrls.addAll(postMediaUrls);
      }
      return mediaUrls;
    } catch (err) {
      print('Error fetching post media: $err');
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
      drawer: Drawer(
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
            InkWell(
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
            ),
            InkWell(
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
            ),
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
            InkWell(
              onTap: () {
                // Your tap callback code
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Use as little space as possible
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icons/Profile_icons/QRCode.svg',
                      height: 28,
                      color: primaryColor,
                    ), // Icon color
                    const SizedBox(width: 8), // Spacing between icon and text
                    Text('QR Code',
                        style: TextStyle(color: Colors.white)), // Text style
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            //Get Verified
            InkWell(
              onTap: () {
                // Your tap callback code
              },
              child: Container( 
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Use as little space as possible
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icons/Profile_icons/Verified.svg',
                      height: 28,
                      color: primaryColor,
                    ), // Icon color
                    const SizedBox(width: 8), // Spacing between icon and text
                    Text('Get Verified',
                        style: TextStyle(color: Colors.white)), // Text style
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            //Close Friends
            InkWell(
              onTap: () {
                // Your tap callback code
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Use as little space as possible
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icons/Profile_icons/CloseFriends.svg',
                      height: 28,
                      color: primaryColor,
                    ), // Icon color
                    const SizedBox(width: 8), // Spacing between icon and text
                    Text('Close Friends',
                        style: TextStyle(color: Colors.white)), // Text style
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            //Archived
            InkWell(
              onTap: () {
                // Your tap callback code
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Use as little space as possible
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icons/Profile_icons/Archive.svg',
                      height: 28,
                      color: primaryColor,
                    ), // Icon color
                    const SizedBox(width: 8), // Spacing between icon and text
                    Text('Archived',
                        style: TextStyle(color: Colors.white)), // Text style
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            //SignOut
            InkWell(
              onTap: () async {
                await AuthMethods().signOut(context);
                // Close the drawer
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Use as little space as possible
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icons/Profile_icons/SignOut.svg',
                      height: 28,
                      color: primaryColor,
                    ), // Icon color
                    const SizedBox(width: 8), // Spacing between icon and text
                    Text('Signout',
                        style: TextStyle(color: Colors.white)), // Text style
                  ],
                ),
              ),
            ),

            currentUser != null && currentUser.uid == allowedUserId
                ? ListTile(
                    title: Text('Add Tester'),
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
                    title: Text('Approve Events'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminEventApprovalPage()),
                      );
                    },
                  )
                : Container(),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: darkBackgroundColor,
        title: Text(
          userData['username'] ?? '',
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState!.openDrawer(),
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: highlightColor,
                                width: 4.0,
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.grey,
                              backgroundImage:
                                  NetworkImage(userData['photoUrl']),
                              radius: 55,
                            ),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          Text(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        buildStatColumn(postLen, "Posts"),
                                        buildStatColumn(followers, "Followers"),
                                        buildStatColumn(following, "Following"),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        FirebaseAuth.instance.currentUser!
                                                    .uid ==
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
                                                  backgroundColor:
                                                      highlightColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16.0),
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

                                        FirebaseAuth.instance.currentUser!
                                                    .uid !=
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
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          darkLBackgroundColor,
                                                      shape:
                                                          RoundedRectangleBorder(
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

                                                      setState(() {
                                                        isFollowing = true;
                                                        followers++;
                                                      });
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          highlightColor,
                                                      shape:
                                                          RoundedRectangleBorder(
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
                                        FirebaseAuth.instance.currentUser!
                                                    .uid ==
                                                widget.uid
                                            ? TextButton(
                                                onPressed: () {
                                                  // Implement the functionality for the Edit Profile button
                                                  // This could navigate to an edit profile screen
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor:
                                                      darkLBackgroundColor, // Background color
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16.0), // Adjust the border radius as needed
                                                  ),
                                                  side: BorderSide(
                                                    color: greyColor,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 0,
                                                      horizontal: 35.0),
                                                  child: Text(
                                                    'Visit Area',
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              )
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
                                                    borderRadius:
                                                        BorderRadius.circular(
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
                            tabs: [
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
                                      return Center(
                                          child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Center(
                                          child: Text(
                                              'Error fetching media posts'));
                                    } else {
                                      List<String> mediaUrls =
                                          snapshot.data as List<String>;
                                      return GridView.builder(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 8.0,
                                          mainAxisSpacing: 8.0,
                                        ),
                                        itemCount: mediaUrls.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.3,
                                            child: Image.network(
                                              mediaUrls[index],
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),

                                // Tab view for Updates
                                FutureBuilder(
                                  future: fetchPostMediaUrls(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                          child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Center(
                                          child: Text(
                                              'Error fetching text-based posts'));
                                    } else {
                                      List<String> updateTexts =
                                          snapshot.data as List<String>;
                                      return ListView.builder(
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          Text('updates');
                                        },
                                        // ... your code to display text-based posts ...
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

  Column buildStatColumn(int num, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          num.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
}
