import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/online_status_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // App going to background or being killed
      OnlineStatusService.setOffline();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      OnlineStatusService.setOnline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... your routes
    );
  }
}
