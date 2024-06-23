import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:localink_sm/services/firebase_messaging_service.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/global_variables.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({super.key});

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  String username = "";
  int _page = 0;
  late PageController pageController;
  late Future<String?> userImageFuture;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    FirebaseMessagingService(); // Initialize Firebase Messaging Service
    _retrieveToken();

    userImageFuture = getCurrentUserImage();
     _preloadVideos();
  }

  void _retrieveToken() async {
    FirebaseMessagingService firebaseMessagingService =
        FirebaseMessagingService();
    String? token = await firebaseMessagingService.getToken();
    setState(() {
      _fcmToken = token;
    });
    print(_fcmToken);
  }

  Future<String?> getCurrentUserImage() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userSnapshot.exists) {
        return userSnapshot['photoUrl'];
      }
    }

    return null;
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }

  void navigationTap(int page) {
    pageController.jumpToPage(page);
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  Future<void> _preloadVideos() async {
    try {
      // Clear old cached videos
      Directory tempDir = await getTemporaryDirectory();
      List<FileSystemEntity> files = tempDir.listSync();
      for (FileSystemEntity file in files) {
        if (file is File) {
          await file.delete();
        } else if (file is Directory) {
          await file.delete(recursive: true);
        }
      }

      // Fetch initial videos from Firestore
      var postTypeSnapshot = await FirebaseFirestore.instance
          .collection('postTypes')
          .where('postType_name', isEqualTo: 'videos')
          .limit(1)
          .get();

      if (postTypeSnapshot.docs.isEmpty) {
        print('No video post type found');
        return;
      }

      DocumentReference videoTypeRef = postTypeSnapshot.docs.first.reference;

      Query query = FirebaseFirestore.instance
          .collection('posts')
          .where('postType', isEqualTo: videoTypeRef)
          .orderBy('createdDatetime', descending: true)
          .limit(3);

      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        print('No initial posts found');
        return;
      }

      // Download and cache videos
      for (var doc in querySnapshot.docs) {
        String mediaUrl = await getMediaUrl(doc);
        print('Downloading video from URL: $mediaUrl');
        await _downloadAndCacheVideo(mediaUrl, tempDir);
      }
    } catch (e) {
      print('Error preloading videos: $e');
    }
  }

  Future<void> _downloadAndCacheVideo(String url, Directory tempDir) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String fileName = url.split('/').last;
        File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        print('Cached video: ${file.path}');
      } else {
        print('Failed to download video: $url');
      }
    } catch (e) {
      print('Error downloading video: $e');
    }
  }

  Future<String> getMediaUrl(DocumentSnapshot post) async {
    final mediaSnap = await post.reference.collection('postMedia').get();
    if (mediaSnap.docs.isNotEmpty) {
      final mediaData = mediaSnap.docs.first.data() as Map<String, dynamic>;
      if (mediaData.containsKey('transcodedUrl')) {
        return mediaData['transcodedUrl'] as String;
      }
      return mediaData['mediaUrl'] as String;
    } else {
      throw StateError('No mediaUrl found in postMedia subcollection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        children: homeScreenItems,
        physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        onPageChanged: onPageChanged,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: CupertinoTabBar(
            backgroundColor: darkBackgroundColor,
            items: [
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/home.svg',
                    // ignore: deprecated_member_use
                    color: _page == 0 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/search.svg',
                    // ignore: deprecated_member_use
                    color: _page == 1 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/locamap.svg',
                    // ignore: deprecated_member_use
                    color: _page == 2 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/videoplayer.svg',
                    // ignore: deprecated_member_use
                    color: _page == 3 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                icon: FutureBuilder(
                  future: userImageFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        width: 24,
                        height: 24,
                        child: Container(), // Placeholder is an empty container
                      );
                    } else if (snapshot.hasError) {
                      return Icon(Icons.error, color: Colors.red);
                    } else {
                      return CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          snapshot.data as String, // Use the fetched image URL
                        ),
                        radius: 12,
                      );
                    }
                  },
                ),
                label: '',
                backgroundColor: primaryColor,
              ),
            ],
            onTap: navigationTap,
          ),
        ),
      ),
    );
  }
}
