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

  @override
  void initState() {
    super.initState();
    pageController = PageController();
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

  /* @override
  void initState() {
    super.initState();
  } */

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    /* final model.User? user = Provider.of<UserProvider>(context).getUser;
    if (user == null) {
      return const Center(
          child: CircularProgressIndicator(
        color: highlightColor,
      ));
    }
    return Scaffold(
      body: Center(child: Text(user.username)),
    ); */
    return Scaffold(
      body: PageView(
        children: homeScreenItems,
        physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        onPageChanged: onPageChanged,
      ),
      bottomNavigationBar: CupertinoTabBar(
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
              icon: Icon(
                Icons.person,
                color: _page == 4 ? highlightColor : primaryColor,
              ),
              label: '',
              backgroundColor: primaryColor),
          /*  BottomNavigationBarItem(
              icon: Icon(
                Icons.upload_file,
                color: _page == 5 ? highlightColor : primaryColor,
              ),
              label: '',
              backgroundColor: primaryColor), */
        ],
        onTap: navigationTap,
      ),
    );
  }
}
