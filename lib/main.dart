import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NativeChannelsCourseApp());
}

class NativeChannelsCourseApp extends StatelessWidget {
  const NativeChannelsCourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Channels Course',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0553B1)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
