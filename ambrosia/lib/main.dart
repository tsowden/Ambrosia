// main.dart
import 'package:flutter/material.dart';
import 'styles/app_theme.dart';
import 'screens/home_screen.dart';
import 'routes/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambrosia',
      theme: AppTheme.themeData, 
      home: HomeScreen(), // Écran de départ SANS bottom nav
      debugShowCheckedModeBanner: false,

      // Redirection des routes
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
