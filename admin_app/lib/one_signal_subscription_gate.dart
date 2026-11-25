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
  static const _shownKey = 'onesignal_permission_prompt_shown';

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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    } catch (_) {
      // Permission prompts are optional and must never block app startup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
