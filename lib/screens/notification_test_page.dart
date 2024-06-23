import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotificationTestPage extends StatefulWidget {
  @override
  _NotificationTestPageState createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final String userToken = 'fJt1X1pNRsGPFsqHD14pDQ:APA91bH3B9Xtp8SKbZoWTs_PV7nFw-L-rNr3K-9rdqDWzotb1EXy3kI-icVIeqhrXIL6nq6SpPTwzQ8yivMLQmVZET3ar3gLvgznLmp4dcd_B5wXQ-aKW5LZajY1aaNehEzNhwyz_IV8'; // Replace with the actual FCM token
  final String notificationTitle = 'Test Notification';
  final String notificationBody = 'This is a test notification';

  Future<void> sendNotification() async {
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
    try {
      final response = await callable.call(<String, dynamic>{
        'token': userToken,
        'title': notificationTitle,
        'body': notificationBody,
      });
      if (response.data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notification sent successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send notification: ${response.data['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending notification: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Test Page'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: sendNotification,
          child: Text('Send Test Notification'),
        ),
      ),
    );
  }
}
