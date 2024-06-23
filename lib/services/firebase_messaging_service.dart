import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/notification_helper.dart';
import '../constants.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  FirebaseMessagingService() {
    _initializeFirebaseMessaging();
    _requestPermission();
    _configureForegroundNotification();
  }

  void _initializeFirebaseMessaging() {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      NotificationConstants.channelId,
      NotificationConstants.channelName,
      description: NotificationConstants.channelDescription,
      importance: Importance.max,
    );

    _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  void _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  void _configureForegroundNotification() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received a message while in the foreground: ${message.messageId}');
      if (message.notification != null) {
        NotificationHelper.showNotification(message, _flutterLocalNotificationsPlugin);
      }
    });
  }

  Future<String?> getToken() async {
    String? token = await _messaging.getToken();
    print('FCM Token: $token');
    return token;
  }
}
