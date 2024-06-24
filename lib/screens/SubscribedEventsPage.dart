import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/widgets/event_card.dart';
import 'package:localink_sm/utils/utils.dart';

class SubscribedEventsPage extends StatefulWidget {
  final String userId;

  const SubscribedEventsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _SubscribedEventsPageState createState() => _SubscribedEventsPageState();
}

class _SubscribedEventsPageState extends State<SubscribedEventsPage> {
  bool isLoading = false;
  List<DocumentSnapshot> subscribedEvents = [];

  @override
  void initState() {
    super.initState();
    getSubscribedEvents();
  }

  Future<void> getSubscribedEvents() async {
    setState(() {
      isLoading = true;
    });

    try {
      var allEvents = await FirebaseFirestore.instance.collection('events').get();
      List<DocumentSnapshot> tempSubscribedEvents = [];

      for (var eventDoc in allEvents.docs) {
        var attendeesCollection = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventDoc.id)
            .collection('attendees')
            .where('userId', isEqualTo: widget.userId)
            .get();

        if (attendeesCollection.docs.isNotEmpty) {
          tempSubscribedEvents.add(eventDoc);
        }
      }

      setState(() {
        subscribedEvents = tempSubscribedEvents;
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
        title: const Text('Subscribed Events'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : subscribedEvents.isEmpty
              ? Center(child: Text('No subscribed events found'))
              : ListView.builder(
                  itemCount: subscribedEvents.length,
                  itemBuilder: (context, index) {
                    return EventCard(eventId: subscribedEvents[index].id, viewer: true);
                  },
                ),
    );
  }
}
