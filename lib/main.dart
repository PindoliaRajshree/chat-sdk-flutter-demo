import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:liveconnect_flutter/liveconnect_flutter.dart';
import 'package:liveconnect_flutter/models/visitor_profile.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_chat_widget/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final title = message.notification?.title ?? '(no title)';
  debugPrint('background message: $title');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await requestNotificationPermission();

  await LiveConnectChat.init(
    widgetKey: '6c313c1f-806f-4f8b-9a01-e8337e615935',
    visitorDetails: VisitorProfile(
      name: 'Jacky',
      email: 'jacky@example.com',
      phone: '+14155552671',
    ),
    theme: LiveConnectTheme(
      primaryColor: Colors.blue,
      headerBackgroundColor: Colors.blue.shade700,
      headerTitleColor: Colors.white,
    ),
  );

  // Get and register initial FCM token
  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM token: $fcmToken');

  if (fcmToken != null) {
    LiveConnectChat.setFcmToken(fcmToken);
  }

  runApp(const MyApp());
}

Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.notification.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('Notification permission denied on Android');
    } else {
      debugPrint('Notification permission granted on Android');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  void setupNotifications() {
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
      LiveConnectChat.setFcmToken(newToken);
    });

    // Handle messages in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? '(no title)';
      final body = message.notification?.body ?? message.data.toString();
      debugPrint('foreground message: $title');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body)),
        );
      }
    });

    // Handle notification tap (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final title = message.notification?.title ?? '(no title)';
      debugPrint('notification opened: $title');
      if (mounted) {
        LiveConnectChat.show(context);
      }
    });
  }

  @override
  void initState() {
    setupNotifications();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fabLocation =
        LiveConnectChat.currentTheme.floatingActionButtonLocation;

    return MaterialApp(
      home: Scaffold(
        floatingActionButton: LiveConnectFloatingButton(
          backgroundColor: const Color(0xFF4F46E5),
          tooltip: 'Open Chat',
        ),
        floatingActionButtonLocation: fabLocation,
      ),
    );
  }
}

