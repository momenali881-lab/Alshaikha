import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static final StreamController<Map<String,dynamic>> _tapController =
      StreamController<Map<String,dynamic>>.broadcast();
  static Stream<Map<String,dynamic>> get taps => _tapController.stream;
  static Map<String,dynamic>? _initialTap;
  static bool _initialized = false;
  static const String channelId = 'alshaikha_notifications';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId, 'إشعارات الشيخة',
    description: 'رسائل العملاء والحجوزات والتحديثات',
    importance: Importance.max, playSound: true,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(settings,
      onDidReceiveNotificationResponse: (response) => _emitPayload(response.payload));
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? message.data['title']?.toString();
      final body = message.notification?.body ?? message.data['body']?.toString();
      if (title == null || title.isEmpty) return;
      unawaited(_local.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647), title, body ?? '',
        const NotificationDetails(android:AndroidNotificationDetails(
          channelId,'إشعارات الشيخة',
          channelDescription:'رسائل العملاء والحجوزات والتحديثات',
          importance:Importance.max,priority:Priority.high,playSound:true,
        )),
        payload:jsonEncode(message.data),
      ));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message)=>_emit(message.data));
    final initial=await FirebaseMessaging.instance.getInitialMessage();
    if(initial!=null)_initialTap=Map<String,dynamic>.from(initial.data);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) => unawaited(_saveToken(token)));
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(_syncTokenSafely());
    });
    if (FirebaseAuth.instance.currentUser != null) await _syncTokenSafely();
  }

  // Push-token registration is best-effort and must never affect authentication.
  static Future<void> _syncTokenSafely() async {
    try {
      await syncToken();
    } catch (_) {
      // Notifications may be unavailable; the user can still use the app.
    }
  }

  static Future<void> syncToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (_) {
      // A Firestore rule/network failure must not sign out or block the account.
    }
  }
  static void handleExternalTap(Map<String,dynamic> data) => _emit(data);
  static Map<String,dynamic>? takeInitialTap(){final value=_initialTap;_initialTap=null;return value;}
  static void _emit(Map<dynamic,dynamic> data){
    final normalized=data.map((key,value)=>MapEntry(key.toString(),value));
    if(_tapController.hasListener){_tapController.add(normalized);}else{_initialTap=normalized;}
  }
  static void _emitPayload(String? payload){
    if(payload==null||payload.isEmpty)return;
    try{final decoded=jsonDecode(payload);if(decoded is Map)_emit(decoded);}catch(_){}
  }
}
