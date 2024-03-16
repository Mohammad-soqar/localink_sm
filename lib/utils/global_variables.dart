import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/screens/add-ARItem_screen.dart';
import 'package:localink_sm/screens/add_post_screen.dart';
import 'package:localink_sm/screens/feed_screen.dart';
import 'package:localink_sm/screens/locamap_screen.dart';
import 'package:localink_sm/screens/profile_screen.dart';
import 'package:localink_sm/screens/search_screen.dart';

const webScreenSize = 600;

List<Widget> homeScreenItems = [
  FeedScreen(),
  SearchScreen(),
  LocaMap(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ),
  UploadARItemScreen(),
  ProfileScreen(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ),
  AddPostScreen(),
];
