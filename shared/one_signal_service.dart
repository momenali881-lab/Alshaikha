import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Centralized, failure-isolated wrapper for OneSignal SDK interactions.
class OneSignalService {
  OneSignalService._();

  static bool _initialized = false;
  static String? _lastExternalId;

  static void initialize(String appId) {
    if (_initialized) return;
    try {
      OneSignal.initialize(appId);
      _initialized = true;
    } catch (_) {
      // Push setup must never prevent either app from opening.
      return;
    }

    auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      try {
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
      } catch (_) {
        // Authentication and core app flows remain independent of push setup.
      }
    }, onError: (_) {});
  }

  static void addNotificationClickListener(
    void Function(Map<String, dynamic>) handler,
  ) {
    try {
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data != null) {
          handler(Map<String, dynamic>.from(data));
        }
      });
    } catch (_) {}
  }

  static void addPushSubscriptionObserver(void Function(String?) handler) {
    try {
      OneSignal.User.pushSubscription.addObserver((state) {
        handler(state.current.id);
      });
      handler(OneSignal.User.pushSubscription.id);
    } catch (_) {}
  }

  static Future<bool> requestPermission() async {
    try {
      return await OneSignal.Notifications.requestPermission(true);
    } catch (_) {
      return false;
    }
  }
}
