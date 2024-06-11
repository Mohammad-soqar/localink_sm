import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/utils/utils.dart';

class DeletedEventsPage extends StatefulWidget {
  @override
  _DeletedEventsPageState createState() => _DeletedEventsPageState();
}

class _DeletedEventsPageState extends State<DeletedEventsPage> {
  bool isLoading = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> deletedEvents = [];

  @override
  void initState() {
    super.initState();
    getDeletedEvents();
  }

  Future<void> getDeletedEvents() async {
    setState(() {
      isLoading = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Get all event documents
      QuerySnapshot<Map<String, dynamic>> eventsSnapshot = await firestore.collection('events').get();

      // Initialize an empty list to store the deleted events
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allDeletedEvents = [];

      // Iterate through all event documents
      for (var eventDoc in eventsSnapshot.docs) {
        // Get the deleted events sub-collection for the current event document
        QuerySnapshot<Map<String, dynamic>> deletedEventsSnapshot = await eventDoc.reference.collection('deleted_events').get();

        // Add the deleted events to the list
        allDeletedEvents.addAll(deletedEventsSnapshot.docs);
      }

      setState(() {
        deletedEvents = allDeletedEvents;
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

  Future<void> _restoreEvent(String eventId, String parentEventId) async {
    try {
      var deletedEventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(parentEventId)
          .collection('deleted_events')
          .doc(eventId)
          .get();
      if (deletedEventDoc.exists) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .set(deletedEventDoc.data()!);
        await FirebaseFirestore.instance
            .collection('events')
            .doc(parentEventId)
            .collection('deleted_events')
            .doc(eventId)
            .delete();
      }
    } catch (e) {
      showSnackBar(
        e.toString(),
        context,
      );
    }
  }

  int _daysLeft(Timestamp deletedAt) {
    final deletedDate = deletedAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(deletedDate).inDays;
    return 10 - difference;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Events'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : deletedEvents.isEmpty
              ? Center(child: Text('No deleted events found'))
              : ListView.builder(
                  itemCount: deletedEvents.length,
                  itemBuilder: (context, index) {
                    final event = deletedEvents[index];
                    final daysLeft = _daysLeft(event['deletedAt']);
                    return ListTile(
                      title: Text(event['name'] ?? 'No Title'),
                      subtitle: Text('Restore within $daysLeft days'),
                      trailing: IconButton(
                        icon: Icon(Icons.restore),
                        onPressed: () async {
                          await _restoreEvent(event.id, event.reference.parent.parent!.id);
                          await getDeletedEvents(); // Refresh the list
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
