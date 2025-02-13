// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/global_variables.dart';

class WebScreenLayout extends StatefulWidget {
  const WebScreenLayout({super.key});

  @override
  State<WebScreenLayout> createState() => _WebScreenLayoutState();
}

class _WebScreenLayoutState extends State<WebScreenLayout> {
  String username = "";
  int _page = 0;
  late PageController pageController;
  late Future<String?> userImageFuture; 

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    userImageFuture = getCurrentUserImage();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        onPageChanged: onPageChanged,
        children: homeScreenItems,
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
                    color: _page == 0 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/search.svg',
                    color: _page == 1 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/locamap.svg',
                    color: _page == 2 ? highlightColor : primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  label: '',
                  backgroundColor: primaryColor),
              BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/icons/videoplayer.svg',
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
                      return const Icon(Icons.error, color: Colors.red);
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


 