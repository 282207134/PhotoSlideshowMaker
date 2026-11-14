import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/library.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const SlideshowApp());
}

class SlideshowApp extends StatelessWidget {
  const SlideshowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Slideshow Photo Editor',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(primary: Color(0xffffb51b)),
      fontFamily: 'Poppins',
    ),
    home: const LibraryScreen(),
  );
}
