import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const F1WowsApp());
}

class F1WowsApp extends StatelessWidget {
  const F1WowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'F1 WOWS',
      theme: buildTheme(),
      home: const SearchScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
