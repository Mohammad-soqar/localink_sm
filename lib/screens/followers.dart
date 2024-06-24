import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowersPage extends StatelessWidget {
  final String userId;

  const FollowersPage({Key? key, required this.userId}) : super(key: key);

  Future<void> _deleteFollower(String followerId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'followers': FieldValue.arrayRemove([followerId])
    });
  }

  Future<String> _getUsername(String userId) async {
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data()?['username'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Followers'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> followers = userData['followers'] ?? [];

          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              return FutureBuilder<String>(
                future: _getUsername(followers[index]),
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
                      onPressed: () => _deleteFollower(followers[index]),
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
