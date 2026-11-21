import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for the AL SHEIKHA administration Android app.
/// These values identify the Firebase project; access is controlled by Firebase Security Rules.
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA97IxmVYLuB73jTZ7VDCwFI8keBTxZfA4',
    appId: '1:160261336352:android:b63cbf7c381944d9773b45',
    messagingSenderId: '160261336352',
    projectId: 'alshaikha',
    storageBucket: 'alshaikha.firebasestorage.app',
  );
}
