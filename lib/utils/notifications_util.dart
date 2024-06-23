import 'package:cloud_functions/cloud_functions.dart';

final String token =
    'fJt1X1pNRsGPFsqHD14pDQ:APA91bH3B9Xtp8SKbZoWTs_PV7nFw-L-rNr3K-9rdqDWzotb1EXy3kI-icVIeqhrXIL6nq6SpPTwzQ8yivMLQmVZET3ar3gLvgznLmp4dcd_B5wXQ-aKW5LZajY1aaNehEzNhwyz_IV8'; // Replace with the actual FCM token
final String notificationTitle = 'Test Notification';
final String notificationBody = 'This is a test notification';
// Utility function to send a new follower notification
Future<void> sendNFollowerNotification(
    String token, String followerId, String followerName) async {
  final HttpsCallable callable =
      FirebaseFunctions.instance.httpsCallable('sendNFollowerNotification');
  try {
    final response = await callable.call({
      'token': token,
      'followerId': followerId,
      'followerName': followerName,
    });
    if (response.data['success']) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.data['error']}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

// Utility function to send a like notification
Future<void> sendLikeNotification(
    String token, String postId, String likerId, String likerName) async {
  final HttpsCallable callable =
      FirebaseFunctions.instance.httpsCallable('sendLikeNotification');
  try {
    final response = await callable.call({
      'token': token,
      'postId': postId,
      'likerId': likerId,
      'likerName': likerName,
    });
    if (response.data['success']) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.data['error']}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

// Add other notification utility functions here...
Future<void> sendCommentNotification(String token, String postId,
    String commenterId, String commenterName) async {
  final HttpsCallable callable =
      FirebaseFunctions.instance.httpsCallable('sendCommentNotification');
  try {
    final response = await callable.call({
      'token': token,
      'postId': postId,
      'commenterId': commenterId,
      'commenterName': commenterName,
    });
    if (response.data['success']) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.data['error']}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

Future<void> sendSystemUpdate(String token, String updateMessage) async {
  final HttpsCallable callable =
      FirebaseFunctions.instance.httpsCallable('sendSystemUpdate');
  try {
    final response = await callable.call({
      'token': token,
      'updateMessage': updateMessage,
    });
    if (response.data['success']) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.data['error']}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

Future<void> sendPromotionalOffer(
    String token, String offerId, String offerDetails) async {
  final HttpsCallable callable =
      FirebaseFunctions.instance.httpsCallable('sendPromotionalOffer');
  try {
    final response = await callable.call({
      'token': token,
      'offerId': offerId,
      'offerDetails': offerDetails,
    });
    if (response.data['success']) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.data['error']}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}
