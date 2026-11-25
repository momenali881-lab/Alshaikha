import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Centralized wrapper for all OneSignal SDK interactions.
class OneSignalService {
  OneSignalService._();

  static bool _initialized = false;
  static String? _lastExternalId;
  static StreamSubscription<auth.User?>? _authSubscription;

  static void initialize(String appId) {
    if (_initialized) return;

    OneSignal.initialize(appId);
    _authSubscription = auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (_lastExternalId != null) {
          OneSignal.logout();
          _lastExternalId = null;
        }
        return;
      }
      if (_lastExternalId != user.uid) {
        OneSignal.login(user.uid);
        _lastExternalId = user.uid;
      }
    });
    _initialized = true;
  }

  static void addNotificationClickListener(
    void Function(Map<String, dynamic>) handler,
  ) {
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  static void addPushSubscriptionObserver(void Function(String?) handler) {
    OneSignal.User.pushSubscription.addObserver((state) {
      handler(state.current.id);
    });
    // The server-assigned ID may already exist before the observer is attached.
    handler(OneSignal.User.pushSubscription.id);
  }

  static Future<bool> requestPermission() async {
    return OneSignal.Notifications.requestPermission(true);
  }
}
