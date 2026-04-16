import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:firebase_core/firebase_core.dart';
import '../config/firebase_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      appId: FirebaseConfig.appId,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      projectId: FirebaseConfig.projectId,
      databaseURL: FirebaseConfig.databaseURL,
      storageBucket: FirebaseConfig.storageBucket,
    ),
  );
  // Handle background messages
  debugPrint("Handling a background message: ${message.messageId}");
  if (message.data['type'] == 'call') {
     CallNotificationService().showIncomingCallNotification(message.data['callerName'] ?? 'Someone');
  }
}

class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _notifications.initialize(initSettings);

    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    // Create high importance channel
    const channel = AndroidNotificationChannel(
      'incoming_call_channel', 
      'Incoming Calls',
      description: 'Incoming call notification',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await androidImplementation?.createNotificationChannel(channel);

    // Setup Firebase Messaging
    await setupFcm();
  }

  Future<void> setupFcm() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions (especially for iOS)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the token
    String? token = await messaging.getToken();
    debugPrint("FCM Token: $token");

    // Listen to background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       debugPrint('Got a message whilst in the foreground!');
       if (message.data['type'] == 'call') {
          showIncomingCallNotification(message.data['callerName'] ?? 'Someone');
       }
    });
  }

  /// Show a persistent notification for an ongoing call.
  Future<void> showOngoingCallNotification(String partnerName) async {
    const androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Ongoing Calls',
      channelDescription: 'Active call status',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      color: Color(0xFF6366F1),
      category: AndroidNotificationCategory.call,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      10,
      'ZuuMeet · Active Call',
      'Ongoing call with $partnerName',
      details,
      payload: 'return_to_call',
    );
  }

  /// Show an incoming call notification (Ringing).
  Future<void> showIncomingCallNotification(String callerName) async {
    const androidDetails = AndroidNotificationDetails(
      'incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Incoming call notification',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
      color: Color(0xFF10B981),
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true, 
      presentBadge: true, 
      presentAlert: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      11,
      'ZuuMeet · Incoming Call',
      '$callerName is calling you...',
      details,
      payload: 'answer_call',
    );
  }

  /// Dismiss the call notification.
  Future<void> dismissCallNotification() async {
    await _notifications.cancel(10);
    await _notifications.cancel(11);
  }
}
