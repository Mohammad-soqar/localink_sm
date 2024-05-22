import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localink_sm/models/event.dart';

class AdminEventApprovalPage extends StatefulWidget {
  const AdminEventApprovalPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AdminEventApprovalPageState createState() => _AdminEventApprovalPageState();
}

class _AdminEventApprovalPageState extends State<AdminEventApprovalPage> {
  Future<List<Event>> _fetchPendingEvents() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs.map((doc) => Event.fromSnap(doc)).toList();
  }

  Future<void> _updateEventStatus(String eventId, String status) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'status': status,
    });
  }

  void _approveEvent(String eventId) async {
    await _updateEventStatus(eventId, 'approved');
    setState(() {});
  }

  void _rejectEvent(String eventId) async {
    await _updateEventStatus(eventId, 'rejected');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Approve Events'),
      ),
      body: FutureBuilder<List<Event>>(
        future: _fetchPendingEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No pending events'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                Event event = snapshot.data![index];
                return ListTile(
                  title: Text(event.name),
                  subtitle: Text(event.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveEvent(event.id),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectEvent(event.id),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
 