import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

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
    const iosDetails = DarwinNotificationDetails(presentSound: true, presentBadge: true, presentAlert: true);
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
