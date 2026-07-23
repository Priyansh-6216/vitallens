import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Heart rate thresholds for notifications
  static const int _lowHeartRateThreshold = 50;   // bpm - bradycardia
  static const int _highHeartRateThreshold = 120; // bpm - tachycardia (at rest)

  // Track last notification time to prevent spam
  DateTime? _lastLowHRNotification;
  DateTime? _lastHighHRNotification;
  static const Duration _notificationCooldown = Duration(minutes: 5);

  NotificationService();

  Future<void> init() async {
    // Initialize time zones
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {},
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {},
      onDidReceiveBackgroundNotificationResponse:
          (NotificationResponse notificationResponse) async {},
    );
  }

  /// Check if heart rate is abnormal and send notification if needed
  Future<void> checkHeartRate(int heartRate) async {
    // Don't send notifications if heart rate is in normal range
    if (heartRate >= _lowHeartRateThreshold &&
        heartRate <= _highHeartRateThreshold) {
      return;
    }

    final now = DateTime.now();

    // Check for low heart rate (bradycardia)
    if (heartRate < _lowHeartRateThreshold) {
      // Check if we're in cooldown period
      if (_lastLowHRNotification != null &&
          now.difference(_lastLowHRNotification!) < _notificationCooldown) {
        return; // Still in cooldown
      }

      await _showLowHeartRateNotification(heartRate);
      _lastLowHRNotification = now;
    }
    // Check for high heart rate (tachycardia)
    else if (heartRate > _highHeartRateThreshold) {
      // Check if we're in cooldown period
      if (_lastHighHRNotification != null &&
          now.difference(_lastHighHRNotification!) < _notificationCooldown) {
        return; // Still in cooldown
      }

      await _showHighHeartRateNotification(heartRate);
      _lastHighHRNotification = now;
    }
  }

  /// Show notification for low heart rate
  Future<void> _showLowHeartRateNotification(int heartRate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'low_heart_rate_channel',
      'Low Heart Rate Alerts',
      channelDescription: 'Notifications for low heart rate detection',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Low heart rate detected',
      icon: '@mipmap/ic_launcher',
    );

    const IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // notification id
      'Low Heart Rate Detected',
      'Your heart rate is $heartRate bpm, which is below the normal resting range. Please consult with a healthcare professional if this persists.',
      platformChannelSpecifics,
      payload: 'low_heart_rate_$heartRate',
    );
  }

  /// Show notification for high heart rate
  Future<void> _showHighHeartRateNotification(int heartRate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_heart_rate_channel',
      'High Heart Rate Alerts',
      channelDescription: 'Notifications for high heart rate detection',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'High heart rate detected',
      icon: '@mipmap/ic_launcher',
    );

    const IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      1, // notification id
      'High Heart Rate Detected',
      'Your heart rate is $heartRate bpm, which is above the normal resting range. Please consult with a healthcare professional if this persists.',
      platformChannelSpecifics,
      payload: 'high_heart_rate_$heartRate',
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Dispose resources
  void dispose() {
    // Cancel any pending notifications when disposing
    cancelAllNotifications();
  }
}