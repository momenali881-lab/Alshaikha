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
  static const _shownKey = 'onesignal_subscription_setup_dialog_shown';
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _restoreAndObserve();
  }

  Future<void> _restoreAndObserve() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _dialogShown = preferences.getBool(_shownKey) ?? false;
      if (_dialogShown) return;
      OneSignalService.addPushSubscriptionObserver(_onSubscriptionChanged);
    } catch (_) {
      // The app remains usable if local preferences or OneSignal are unavailable.
    }
  }

  void _onSubscriptionChanged(String? subscriptionId) {
    if (!mounted ||
        _dialogShown ||
        subscriptionId == null ||
        subscriptionId.isEmpty ||
        subscriptionId.startsWith('local-')) {
      return;
    }

    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool(_shownKey, true);
      } catch (_) {}
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تفعيل إشعارات الشيخة'),
            content: const Text(
              'هل ترغب في تفعيل الإشعارات لتصلك تحديثات الحجوزات والرسائل والإعلانات؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('لاحقاً'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(OneSignalService.requestPermission());
                },
                child: const Text('تفعيل الإشعارات'),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
