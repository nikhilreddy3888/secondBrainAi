import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/services/notification_service.dart';
import 'features/settings/controller/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('App starting...');
  
  final container = ProviderContainer();
  final notificationService = container.read(notificationServiceProvider);
  
  debugPrint('Initializing notification service...');
  try {
    await notificationService.initialize();
    debugPrint('Notification service initialized.');
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }

  debugPrint('Requesting permissions...');
  try {
    await notificationService.requestPermissions();
    debugPrint('Permissions requested.');
  } catch (e) {
    debugPrint('Failed to request permissions: $e');
  }

  debugPrint('Running app...');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SecondBrainApp(),
    ),
  );
}

class SecondBrainApp extends ConsumerWidget {
  const SecondBrainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp.router(
      title: 'Second Brain',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
