import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'meta/profile_store.dart';
import 'story/story_store.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await ProfileStore.load();
  final story = await StoryStore.load();
  runApp(ForeApp(store: store, story: story));
}

class ForeApp extends StatelessWidget {
  const ForeApp({super.key, required this.store, required this.story});

  final ProfileStore store;
  final StoryStore story;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fore! Last Stand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: HomeScreen(store: store, story: story),
    );
  }
}
