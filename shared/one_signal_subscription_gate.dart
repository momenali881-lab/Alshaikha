import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'one_signal_service.dart';

class OneSignalSubscriptionGate extends StatefulWidget {
  const OneSignalSubscriptionGate({super.key, required this.child});

  final Widget child;

  @override
  State<OneSignalSubscriptionGate> createState() =>
      _OneSignalSubscriptionGateState();
}

class _OneSignalSubscriptionGateState extends State<OneSignalSubscriptionGate> {
  static const _shownKey = 'onesignal_permission_prompt_shown_v2';

  @override
  void initState() {
    super.initState();
    _promptOnce();
  }

  Future<void> _promptOnce() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || preferences.getBool(_shownKey) == true) return;
      await preferences.setBool(_shownKey, true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(OneSignalService.requestPermission());
      });
    } catch (_) {
      // Push permission is optional and must never block app startup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
