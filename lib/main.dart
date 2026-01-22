import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/sound_service.dart';
import 'utils/effects_quality.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StirnratenApp());
}

class StirnratenApp extends StatelessWidget {
  const StirnratenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => EffectsController()..startMonitoring(),
        ),
        Provider(
          create: (context) => SoundService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Stirnraten',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
