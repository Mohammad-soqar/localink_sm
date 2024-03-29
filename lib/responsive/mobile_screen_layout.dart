import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/global_variables.dart';
import 'package:provider/provider.dart';

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
    // TODO: implement dispose
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
                    'assets/icons/gamification.svg',
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
