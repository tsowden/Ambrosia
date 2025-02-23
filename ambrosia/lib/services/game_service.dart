// lib/services/game_service.dart

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameService {
  late IO.Socket socket;
  String? majorityVote;

  // ----------------------------------------------------------------
  // CONSTRUCTOR & SOCKET INITIALIZATION
  // ----------------------------------------------------------------
  GameService() {
    socket = IO.io(
      // 'http://192.168.0.53:3000', // wifi
      'http://192.168.1.168:3000', // 5G
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  // ----------------------------------------------------------------
  // CONNECTION & ROOM
  // ----------------------------------------------------------------
  void connectToGame(String gameId) {
    print('GameService: Connecting to game $gameId');
    socket.on('connect', (_) {
      print('GameService: Connected to Socket.IO server');
      joinRoom(gameId);
    });

    socket.on('disconnect', (_) {
      print('GameService: Disconnected from Socket.IO server');
    });

    socket.connect();
  }

  void joinRoom(String gameId) {
    print("GameService: Joining room with gameId: $gameId via Socket.IO");
    socket.emit('joinRoom', gameId);
  }

  void disconnect() {
    print("GameService: Disconnecting from Socket.IO server");
    socket.disconnect();
  }

  // ----------------------------------------------------------------
  // LOBBY / READY STATUS
  // ----------------------------------------------------------------
  void setReadyStatus(String gameId, String playerName, bool isReady) {
    print("GameService: Updating ready status for $playerName in room $gameId: $isReady");
    socket.emit('playerReady', {
      'gameId': gameId,
      'playerName': playerName,
      'isReady': isReady,
    });
  }

  void updateAvatar(String gameId, String playerId, String base64Image) {
    print("GameService: Updating avatar for player $playerId in game $gameId");
    socket.emit('updateAvatar', {
      'gameId': gameId,
      'playerId': playerId,
      'avatarBase64': base64Image,
    });
  }


  // ----------------------------------------------------------------
  // GAME START / END
  // ----------------------------------------------------------------
  
  void finishTutorial(String gameId, String playerId) {
    print("GameService: Player $playerId finished tutorial in game $gameId");
    socket.emit('finishTutorial', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }
  
  void startGame(String gameId) {
    print("GameService: Requesting to start game for room $gameId");
    socket.emit('startGame', {'gameId': gameId});
  }

  void onStartGame(Function(Map<String, dynamic>) callback) {
    socket.on('startGame', (data) {
      _logPlayerPosition(data);
      callback(Map<String, dynamic>.from(data));
    });
  }

  void endTurn(String gameId) {
    print("GameService: Ending turn for game $gameId");
    socket.emit('endTurn', gameId); 
  }

  // ----------------------------------------------------------------
  // TURN & ACTIVE PLAYER
  // ----------------------------------------------------------------
  void onTurnStarted(Function(Map<String, dynamic>) callback) {
    socket.on('turnStarted', (data) {
      print("GameService: Turn started event received");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onTurnStateChanged(Function(Map<String, dynamic>) callback) {
    socket.on('turnStateChanged', (data) {
      print("GameService: Turn state changed.");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onActivePlayerChanged(Function(Map<String, dynamic>) callback) {
    socket.on('activePlayerChanged', (data) {
      _logPlayerPosition(data);
      callback(Map<String, dynamic>.from(data));
    });
  }
  

  void getActivePlayer(String gameId) {
    print("GameService: Requesting active player for game $gameId...");
    socket.emit('getActivePlayer', {'gameId': gameId});
  }

  void onActivePlayerReceived(Function(String) callback) {
    socket.on('activePlayer', (data) {
      print("GameService: Received activePlayer: ${data['activePlayerName']}");
      _logPlayerPosition(data);
      callback(data['activePlayerName']);
    });
  }

  // ----------------------------------------------------------------
  // PLAYERS INFO
  // ----------------------------------------------------------------
  void onCurrentPlayers(Function(List<dynamic>) callback) {
    socket.on('currentPlayers', (data) {
      print("GameService: Current players received.");
      callback(List<dynamic>.from(data));
    });
  }

  void onGameInfos(Function(Map<String, dynamic>) callback) {
    socket.on('gameInfos', (data) {
      if (data.containsKey('players')) {
        print("GameService: Received gameInfos (Players count: ${data['players'].length})");
        // Ne plus logguer avatarBase64
        data['players'].forEach((p) {
          print(" - ${p['playerName']}, berries=${p['berries']}");
        });
      }
      callback(Map<String, dynamic>.from(data));
    });
  }


  // ----------------------------------------------------------------
  // MOVEMENT
  // ----------------------------------------------------------------
  void movePlayer(String gameId, String playerId, String move) {
    print("GameService: Player $playerId moving $move in game $gameId");
    socket.emit('playerMove', {
      'gameId': gameId,
      'playerId': playerId,
      'move': move,
    });
  }

  void onPositionUpdate(Function(Map<String, dynamic>) callback) {
    socket.on('positionUpdate', (data) {
      print("GameService: Received position update: $data");
      _logPlayerPosition(data);
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onMoveError(Function(String) callback) {
    socket.on('moveError', (data) {
      print("GameService: Move error received: $data");
      callback(data['message']);
    });
  }

  // ----------------------------------------------------------------
  // VALID MOVES
  // ----------------------------------------------------------------
  void getValidMoves(String gameId, String playerId, Function(Map<String, bool>) callback) {
    print("GameService: Requesting valid moves for player $playerId in game $gameId");
    socket.emit('getValidMoves', {'gameId': gameId, 'playerId': playerId});
    socket.once('validMoves', (data) {
      if (data != null && data is Map) {
        print("GameService: Received valid moves: $data");
        callback(Map<String, bool>.from(data));
      } else {
        print("GameService: Error getting valid moves");
        callback({
          'canMoveForward': false,
          'canMoveLeft': false,
          'canMoveRight': false
        });
      }
    });
  }

  void onValidMovesReceived(Function(Map<String, bool>) callback) {
    socket.on('validMoves', (data) {
      print("GameService: Valid moves received: $data");
      callback({
        'canMoveForward': data['canMoveForward'] ?? false,
        'canMoveLeft': data['canMoveLeft'] ?? false,
        'canMoveRight': data['canMoveRight'] ?? false,
      });
    });
  }

  // ----------------------------------------------------------------
  // CARD DRAW
  // ----------------------------------------------------------------
  void onCardDrawn(Function(Map<String, dynamic>) callback) {
    socket.on('cardDrawn', (data) {
      print("DEBUG front: cardDrawn => $data");      
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // CHALLENGE METHODS
  // ----------------------------------------------------------------
  void startBetting(String gameId, String playerId) {
    print("GameService: Player $playerId is starting betting in game $gameId");
    socket.emit('startBetting', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void onBettingEnded(Function() callback) {
    socket.on('bettingEnded', (_) {
      print("GameService: Betting phase ended");
      callback();
    });
  }

  void placeBet(String gameId, String playerId, String bet) {
    print("GameService: Player $playerId placing bet $bet in game $gameId");
    socket.emit('placeBet', {
      'gameId': gameId,
      'playerId': playerId,
      'bet': bet,
    });
  }

  void onBetPlaced(Function(Map<String, dynamic>) callback) {
    socket.on('betPlaced', (data) {
      print("GameService: Bet placed event received: $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onChallengeStarted(Function() callback) {
    socket.on('challengeStarted', (_) {
      print("GameService: Challenge started");
      callback();
    });
  }

  void onChallengeResult(Function(Map<String, dynamic>) callback) {
    socket.on('challengeResult', (data) {
      print("GameService: Challenge result received: $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void startChallenge(String gameId, String playerId) {
    print("GameService: Player $playerId starting challenge in game $gameId");
    socket.emit('startChallenge', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void sendChallengeResult(String gameId, String playerId, String result) {
    print("GameService: Sending challenge result $result for player $playerId in game $gameId");
    socket.emit('challengeResult', {
      'gameId': gameId,
      'playerId': playerId,
      'result': result,
    });
  }

  void placeChallengeVote(String gameId, String playerId, String vote) {
    print("GameService: Player $playerId voting $vote in challenge for game $gameId");
    socket.emit('placeChallengeVote', {
      'gameId': gameId,
      'playerId': playerId,
      'vote': vote,
    });
  }

  void onChallengeVotesUpdated(Function(Map<String, dynamic>) callback) {
    socket.on('challengeVotesUpdated', (data) {
      print("GameService: Challenge votes updated: $data");
      if (data['isMajorityReached'] == true) {
        majorityVote = data['majorityVote'];
      }
      callback(data);
    });
  }

  // ----------------------------------------------------------------
  // QUIZ METHODS (NEW)
  // ----------------------------------------------------------------
  void startQuiz(String gameId, String playerId, String chosenTheme) {
    print("GameService: Player $playerId starts quiz with theme=$chosenTheme in game $gameId");
    socket.emit('startQuiz', {
      'gameId': gameId,
      'playerId': playerId,
      'chosenTheme': chosenTheme,
    });
  }

  void quizAnswer(String gameId, String playerId, String answer) {
    print("GameService: Player $playerId sends quizAnswer=$answer in game $gameId");
    socket.emit('quizAnswer', {
      'gameId': gameId,
      'playerId': playerId,
      'answer': answer,
    });
  }

  void onQuizStarted(Function(Map<String, dynamic>) callback) {
    socket.on('quizStarted', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onQuizQuestion(Function(Map<String, dynamic>) callback) {
    socket.on('quizQuestion', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onQuizAnswerResult(Function(Map<String, dynamic>) callback) {
    socket.on('quizAnswerResult', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onQuizEnd(Function(Map<String, dynamic>) callback) {
    socket.on('quizEnd', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ----------------------------------------------------------------
  // OBJECT INVENTORY SYSTEM
  // ----------------------------------------------------------------
  void pickUpObject(String gameId, String playerId) {
    print("GameService: Player $playerId picks up an object in game $gameId.");
    socket.emit('pickUpObject', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void onObjectPickedUp(Function(Map<String, dynamic>) callback) {
    socket.on('objectPickedUp', (data) {
      print("GameService: Object added to inventory -> ${data['objectName']}");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void discardObject(String gameId, String playerId, int itemId) {
    print("GameService: Player $playerId discards item $itemId in game $gameId.");
    socket.emit('discardObject', {
      'gameId': gameId,
      'playerId': playerId,
      'itemId': itemId,
    });
  }

  void onObjectDiscarded(Function(Map<String, dynamic>) callback) {
    socket.on('objectDiscarded', (data) {
      print("GameService: Object removed from inventory -> ${data['objectName']}");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void useObject(String gameId, String playerId, int itemId) {
    print("GameService: Player $playerId uses item $itemId in game $gameId.");
    socket.emit('useObject', {
      'gameId': gameId,
      'playerId': playerId,
      'itemId': itemId,
    });
  }

  void onObjectUsed(Function(Map<String, dynamic>) callback) {
    socket.on('objectUsed', (data) {
      print("GameService: Object used => $data");
      callback(Map<String, dynamic>.from(data));
    });
  }


  // ----------------------------------------------------------------
  // UTILITIES
  // ----------------------------------------------------------------
  Future<String?> getPlayerId(String gameId, String playerName) async {
    final Completer<String?> completer = Completer();

    socket.emit('getPlayerId', {'gameId': gameId, 'playerName': playerName});
    socket.once('playerId', (data) {
      if (data != null && data['playerId'] != null) {
        completer.complete(data['playerId']);
      } else {
        completer.completeError('Player ID not found.');
      }
    });

    return completer.future;
  }

  void _logPlayerPosition(Map<String, dynamic> data) {
    if (data.containsKey('position') && data['position'] is Map) {
      final position = data['position'];
      final x = position['x'] ?? 0;
      final y = position['y'] ?? 0;
      final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final formattedPosition = "${alphabet[x]}${y + 1}";
      print("GameService: Player's current position: $formattedPosition");
    }
  }
}
