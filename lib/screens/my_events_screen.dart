import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/widgets/post_card.dart';

class MyEventsPage extends StatefulWidget {
  final String userId;

  MyEventsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _MyEventsPageState createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  bool isLoading = false;
  model.User? user;
  
  @override
  void initState() {
    super.initState();
  }

  Future<void> getData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      var userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userSnap.exists) {
        user = model.User.fromSnap(userSnap);
      }

      var postSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: userId)
          .get();


     
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('My Events'),
        ),
        body: Container());
  }
}
