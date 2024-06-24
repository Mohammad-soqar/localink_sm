import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingPage extends StatefulWidget {
  final String userId;

  const FollowingPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FollowingPageState createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  Future<void> _toggleFollow(String followingId, bool isFollowing) async {
    if (isFollowing) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'following': FieldValue.arrayRemove([followingId])
      });
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'following': FieldValue.arrayUnion([followingId])
      });
    }
    setState(() {}); // Trigger a rebuild to update the UI
  }

  Future<String> _getUsername(String userId) async {
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data()?['username'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Following'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> following = userData['following'] ?? [];

          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              return FutureBuilder<String>(
                future: _getUsername(following[index]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ListTile(
                      title: Text('Loading...'),
                      trailing: CircularProgressIndicator(),
                    );
                  }
                  bool isFollowing = following.contains(following[index]);
                  return ListTile(
                    title: Text(snapshot.data!),
                    trailing: ElevatedButton(
                      onPressed: () => _toggleFollow(following[index], isFollowing),
                      child: Text(isFollowing ? 'Following' : 'Follow'),
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
