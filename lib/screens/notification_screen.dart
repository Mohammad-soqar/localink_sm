import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/models/notifications.dart';

class NotificationsPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<NotificationModel>> _fetchNotifications() async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => NotificationModel.fromSnap(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: _fetchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No notifications'));
          }

          List<NotificationModel> notifications = snapshot.data!;
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              NotificationModel notification = notifications[index];
              return ListTile(
                title: Text(notification.title),
                subtitle: Text(notification.body),
                trailing: Text(DateFormat('MMM d, yyyy hh:mm a').format(notification.timestamp)),
              );
            },
          );
        },
      ),
    );
  }
}
