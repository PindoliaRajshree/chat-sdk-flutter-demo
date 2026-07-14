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

// Runs in its own background isolate (no access to the main isolate's
// widget tree or in-memory state) whenever a push arrives while the app is
// backgrounded or fully closed. We only use it to bump the persisted
// unread-count badge — LiveConnectChat.registerIncomingPush() writes
// straight to SharedPreferences, so it works from here safely.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required in a background isolate before touching any plugin channel
  // (SharedPreferences included).
  WidgetsFlutterBinding.ensureInitialized();

  final title = message.notification?.title ?? '(no title)';
  debugPrint('background message: $title');

  await LiveConnectChat.registerIncomingPush(
    ticketId: message.data['ticketId'],
  );
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
  void setupNotifications() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      LiveConnectChat.setFcmToken(newToken);
    });

    // Foreground message: show an in-app alert and bump the unread badge.
    // (Opening chat from a tap already clears the badge, so we only do this
    // for messages the visitor hasn't acted on yet.)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final ctx = LiveConnectChat.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(message.notification?.body ?? message.data.toString())),
        );
      }

      LiveConnectChat.registerIncomingPush(ticketId: message.data['ticketId']);
    });

    // App was in the background, opened via notification tap.
    // showFromNotification() already clears the unread badge when it opens
    // the chat screen — don't call registerIncomingPush here.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('notification opened: ${message.notification?.title}');
      LiveConnectChat.showFromNotification();
    });

    // App was fully closed (terminated), opened via notification tap.
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
        // FAB already shows the unread badge automatically — nothing to add.
        floatingActionButton: LiveConnectFloatingButton(
          backgroundColor: const Color(0xFF4F46E5),
          tooltip: 'Open Chat',
        ),
        floatingActionButtonLocation: fabLocation,
        body: const Center(child: _CenterChatButton()),
      ),
    );
  }
}

/// A second "Open Chat" entry point in the middle of the screen, with its
/// own unread badge — separate from the FAB but reading the same
/// [LiveConnectChat.totalUnreadCount] notifier, so both stay in sync.
class _CenterChatButton extends StatelessWidget {
  const _CenterChatButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveConnectChat.totalUnreadCount,
      builder: (context, unreadCount, button) {
        debugPrint("Unread Count $unreadCount");
        return Stack(
          clipBehavior: Clip.none,
          children: [
            button!,
            if (unreadCount > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      // Built once and reused across rebuilds via the `child` parameter.
      child: ElevatedButton.icon(
        onPressed: () => LiveConnectChat.show(context),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Open Chat'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}