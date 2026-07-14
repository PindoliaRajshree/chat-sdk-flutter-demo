import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:liveconnect_flutter/liveconnect_flutter.dart';
import 'package:liveconnect_flutter/models/visitor_profile.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_chat_widget/firebase_options.dart';

const String _liveConnectWidgetKey = '6c313c1f-806f-4f8b-9a01-e8337e615935';

VisitorProfile get _visitorProfile => VisitorProfile(
  name: 'Jacky',
  email: 'jacky@example.com',
  phone: '+14155552671',
);

LiveConnectTheme get _liveConnectTheme => LiveConnectTheme(
  primaryColor: Colors.blue,
  headerBackgroundColor: Colors.blue.shade700,
  headerTitleColor: Colors.white,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final title = message.notification?.title ?? '(no title)';
  debugPrint('background message: $title');
}

Future<void> _initLiveConnect() async {
  await LiveConnectChat.init(
    widgetKey: _liveConnectWidgetKey,
    visitorDetails: _visitorProfile,
    theme: _liveConnectTheme,
  );

  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM token: $fcmToken');

  if (fcmToken != null) {
    LiveConnectChat.setFcmToken(fcmToken);
  }
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await requestNotificationPermission();

  // Init once, here. No need to repeat this anywhere else.
  await _initLiveConnect();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Opens the chat widget once the first frame has been drawn, so the
  // Navigator/Overlay behind LiveConnectChat.navigatorKey is guaranteed to
  // be mounted. Used for both the cold-start and background-tap paths.

  void setupNotifications() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      LiveConnectChat.setFcmToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final ctx = LiveConnectChat.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(message.notification?.body ?? message.data.toString())),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('notification opened: ${message.notification?.title}');
      LiveConnectChat.showFromNotification();
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      debugPrint('getInitialMessage() returned: $message');
      if (message == null) return;
      LiveConnectChat.showFromNotification();
    });
  }

  @override
  void initState() {
    super.initState();
    setupNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final fabLocation =
        LiveConnectChat.currentTheme.floatingActionButtonLocation;

    return MaterialApp(
      navigatorKey: LiveConnectChat.navigatorKey,
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