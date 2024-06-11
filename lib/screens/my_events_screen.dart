import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/screens/deleted_events.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/widgets/event_card.dart';
import 'package:localink_sm/widgets/post_card.dart';

class MyEventsPage extends StatefulWidget {
  final String userId;

  MyEventsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _MyEventsPageState createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  bool isLoading = false;
  List<DocumentSnapshot> events = [];

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      var eventSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('organizer', isEqualTo: userId)
          .get();

      setState(() {
        events = eventSnap.docs;
        isLoading = false;
      });
    } catch (e) {
      showSnackBar(
        e.toString(),
        context,
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DeletedEventsPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? Center(child: Text('No events found'))
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return EventCard(eventId: events[index].id);
                  },
                ),
    );
  }
}
