import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'sports_service.dart';

/// خدمة إشعارات المباريات
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const String _channelId = 'match_reminders';
  static const String _channelName = 'تذكير المباريات';
  static const String _channelDesc = 'إشعارات قبل بدء المباريات الرياضية';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;

  /// معرفات الإشعارات المُجدولة (لتجنب التكرار)
  final Set<int> _scheduledIds = {};

  // ==========================================================
  //  التهيئة
  // ==========================================================
  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // طلب الصلاحيات (Android 13+)
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      _initialized = true;
      debugPrint('Notifications service initialized');
    } catch (e) {
      debugPrint('Failed to init notifications: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // TODO: فتح التطبيق على شاشة المباريات
  }

  // ==========================================================
  //  التفعيل / الإطفاء
  // ==========================================================
  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      cancelAll();
    }
  }

  bool get isEnabled => _enabled;

  // ==========================================================
  //  جدولة إشعارات المباريات
  // ==========================================================
  /// جدول إشعارات لمباريات اليوم
  Future<void> scheduleMatches(
    List<SportMatch> matches, {
    int minutesBefore = 15,
  }) async {
    if (!_enabled) return;
    if (!_initialized) await init();

    // امسح القديمة
    await cancelAll();

    final now = DateTime.now();

    for (final match in matches) {
      if (match.isFinished) continue;

      final notifyAt = match.startTime.subtract(
        Duration(minutes: minutesBefore),
      );

      // تجاهل المباريات التي مضى وقتها
      if (notifyAt.isBefore(now)) continue;

      // تجاهل المباريات البعيدة أكثر من 24 ساعة
      if (notifyAt.difference(now).inHours > 24) continue;

      await _scheduleMatchNotification(match, notifyAt);
    }

    debugPrint('Scheduled ${_scheduledIds.length} match notifications');
  }

  Future<void> _scheduleMatchNotification(
    SportMatch match,
    DateTime notifyAt,
  ) async {
    try {
      final id = match.id.hashCode.abs() % 100000;

      // تجنب التكرار
      if (_scheduledIds.contains(id)) return;
      _scheduledIds.add(id);

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF00C8FF),
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const details = NotificationDetails(android: androidDetails);

      final title = '⚽ مباراة بعد 15 دقيقة';
      final body = _formatMatchBody(match);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(notifyAt, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule: $e');
    }
  }

  String _formatMatchBody(SportMatch match) {
    final buffer = StringBuffer();
    buffer.write('${match.homeTeam} × ${match.awayTeam}');

    if (match.league.isNotEmpty) {
      buffer.write('\n🏆 ${match.league}');
    }

    if (match.channel != null && match.channel!.isNotEmpty) {
      buffer.write('\n📺 ${match.channel}');
    } else {
      buffer.write('\n📺 beIN Sports');
    }

    return buffer.toString();
  }

  // ==========================================================
  //  إلغاء كل الإشعارات
  // ==========================================================
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      _scheduledIds.clear();
      debugPrint('All notifications cancelled');
    } catch (_) {}
  }

  /// إشعار فوري (للاختبار)
  Future<void> showNow({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF00C8FF),
    );

    await _plugin.show(
      999,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
