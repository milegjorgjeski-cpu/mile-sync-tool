import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/models/models.dart';
import 'data/repositories/project_repository.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Hive.initFlutter();
  Hive.registerAdapter(LyricLineAdapter());
  Hive.registerAdapter(WordTimestampAdapter());
  Hive.registerAdapter(StemSetAdapter());
  Hive.registerAdapter(TransposeSettingsAdapter());
  Hive.registerAdapter(TrimSettingsAdapter());
  Hive.registerAdapter(CrossfadeSettingsAdapter());
  Hive.registerAdapter(ExportSettingsAdapter());
  Hive.registerAdapter(ProjectAdapter());

  await ProjectRepository().init();

  runApp(const ProviderScope(child: MileSyncApp()));
}

class MileSyncApp extends StatelessWidget {
  const MileSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mile Sync Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
