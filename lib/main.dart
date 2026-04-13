import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'config/firebase_config.dart';
import 'services/ad_manager.dart';
import 'providers/room_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with explicit options for Android
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      appId: FirebaseConfig.appId,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      projectId: FirebaseConfig.projectId,
      databaseURL: FirebaseConfig.databaseURL,
      storageBucket: FirebaseConfig.storageBucket,
    ),
  );

  // Set preferred orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Unity Ads
  await AdManager.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
      ],
      child: const ZuumeetApp(),
    ),
  );
}
