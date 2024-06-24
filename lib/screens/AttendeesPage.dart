import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendeesPage extends StatelessWidget {
  final String eventId;

  const AttendeesPage({Key? key, required this.eventId}) : super(key: key);

  Future<String> _getUsername(String userId) async {
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data()?['username'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendees'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('attendees')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var attendees = snapshot.data!.docs;

          return ListView.builder(
            itemCount: attendees.length,
            itemBuilder: (context, index) {
              return FutureBuilder<String>(
                future: _getUsername(attendees[index].id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ListTile(
                      title: Text('Loading...'),
                      trailing: CircularProgressIndicator(),
                    );
                  }

                  return ListTile(
                    title: Text(snapshot.data!),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('events')
                            .doc(eventId)
                            .collection('attendees')
                            .doc(attendees[index].id)
                            .delete();
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
