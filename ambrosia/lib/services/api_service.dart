import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // static const String baseUrl = 'http://192.168.0.53:3000'; // Wifi
  static const String baseUrl = 'http://192.168.1.168:3000'; // 5G

  Future<Map<String, String>?> createGame(String playerName) async {
    print('ApiService.createGame($playerName) -> POST $baseUrl/api/game/create-game');
    
    final url = Uri.parse('$baseUrl/api/game/create-game');
    final body = jsonEncode({'playerName': playerName});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print('ApiService.createGame: response.statusCode=${response.statusCode}');
      print('ApiService.createGame: response.body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['gameId'] != null && data['playerId'] != null) {
          return {
            'gameId': data['gameId'],
            'playerId': data['playerId'],
          };
        } else {
          print('ApiService.createGame: Réponse invalide: $data');
          return null;
        }
      } else {
        print('ApiService.createGame: Erreur statusCode=${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ApiService.createGame: Exception: $e');
      return null;
    }
  }

  Future<Map<String, String>?> joinGame(String gameId, String playerName) async {
    print('ApiService.joinGame(gameId=$gameId, playerName=$playerName) -> POST $baseUrl/api/game/join-game');
    
    final url = Uri.parse('$baseUrl/api/game/join-game');
    final body = jsonEncode({'gameId': gameId, 'playerName': playerName});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print('ApiService.joinGame: response.statusCode=${response.statusCode}');
      print('ApiService.joinGame: response.body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['playerId'] != null) {
          return {'playerId': data['playerId']};
        } else {
          print('ApiService.joinGame: Réponse invalide: $data');
          return null;
        }
      } else {
        print('ApiService.joinGame: Erreur statusCode=${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ApiService.joinGame: Exception: $e');
      return null;
    }
  }
}
