// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import '../screens/game_home_screen.dart';
import '../services/game_service.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/game':
        {
          final args = settings.arguments as Map<String, dynamic>?;

          final gameId = args?['gameId'] as String? ?? '';
          final playerId = args?['playerId'] as String? ?? '';
          final playerName = args?['playerName'] as String? ?? '(unknown)';
          final gameService = args?['gameService'] as GameService? ?? GameService();
          final initialData = args?['initialData'] as Map<String, dynamic>? ?? {};

          return MaterialPageRoute(
            builder: (_) => GameHomeScreen(
              gameId: gameId,
              playerName: playerName,
              playerId: playerId,
              gameService: gameService,
              initialData: initialData,
            ),
            settings: settings,
          );
        }
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Page not found: ${settings.name}')),
          ),
        );
    }
  }
}
