import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'monetization/monetization_controller.dart';
import 'screens/home_screen.dart';
import 'services/sound_service.dart';
import 'services/supabase_bootstrap.dart';
import 'utils/effects_quality.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initializeIfConfigured();
  runApp(const StirnratenApp());
}

class StirnratenApp extends StatelessWidget {
  const StirnratenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const showPerfOverlay =
        bool.fromEnvironment('SHOW_PERF_OVERLAY', defaultValue: false);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => EffectsController()..startMonitoring(),
        ),
        ChangeNotifierProvider(
          create: (_) => MonetizationController()..init(),
        ),
        Provider(
          create: (context) => SoundService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Stirnraten',
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: kDebugMode && showPerfOverlay,
        theme: ThemeData.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
