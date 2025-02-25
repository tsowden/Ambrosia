// game-api/sockets/socketHandlers.js

const TurnManager = require('../game/turnManager');
const { getCardHandlerForCategory } = require('../game/cardHandlers');
const redisClient = require('../config/redis');
const { getRandomCard } = require('../models/card');
const { useObjectEffect } = require('../game/objects/objectEffects');

const handleSocketEvents = (io, socket) => {
  console.log('Backend: Socket.IO: Nouveau joueur connecté');

  // -----------------------------------------------------
  // 1) TUTORIAL
  // -----------------------------------------------------
  socket.on('finishTutorial', async ({ gameId, playerId }) => {
    console.log(`Backend: Player ${playerId} finished tutorial in game ${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData) return;
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find(p => p.playerId === playerId);
      if (!player) return;
      player.tutorialDone = true;
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
      const allDone = players.every(p => p.tutorialDone === true);
      if (allDone) {
        const maze = JSON.parse(gameData.maze || '[]');
        const activePlayerId = gameData.activePlayerId;
        const activePlayer = players.find((p) => p.playerId === activePlayerId);
        io.to(gameId).emit('tutorialAllFinished', {
          maze,
          players,
          activePlayerName: activePlayer ? activePlayer.playerName : null,
        });
      }
    } catch (error) {
      console.error("Backend: Error in finishTutorial:", error);
    }
  });

  // -----------------------------------------------------
  // 2) BROADCAST GAME INFOS
  // -----------------------------------------------------
  async function broadcastGameInfos(gameId) {
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData) return;
      const players = JSON.parse(gameData.players || '[]');
      const activePlayerId = gameData.activePlayerId;
      const sorted = [...players].sort((a, b) => (b.berries || 0) - (a.berries || 0));
      const playersInfo = sorted.map((p, index) => ({
        playerId: p.playerId,
        playerName: p.playerName,
        berries: p.berries || 0,
        rank: index + 1,
        avatarBase64: p.avatarBase64 || '',
        inventory: p.inventory || [],
      }));
      let activePlayerName = null;
      const activePlayer = players.find((p) => p.playerId === activePlayerId);
      if (activePlayer) {
        activePlayerName = activePlayer.playerName;
      }
      console.log("Backend: broadcastGameInfos");
      io.to(gameId).emit('gameInfos', {
        players: playersInfo,
        activePlayerName: activePlayerName,
      });
    } catch (error) {
      console.error('broadcastGameInfos: Error =>', error);
    }
  }

  socket.on('requestGameInfos', async ({ gameId }) => {
    console.log(`Backend: Reçu 'requestGameInfos' pour game=${gameId}`);
    await broadcastGameInfos(gameId);
  });

  // -----------------------------------------------------
  // 3) LOBBY LOGIC
  // -----------------------------------------------------
  socket.on('playerReady', async ({ gameId, playerName, isReady }) => {
    console.log(`Backend: playerReady => ${playerName}, game=${gameId}, isReady=${isReady}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerName === playerName);
      if (player) {
        player.ready = isReady;
        await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
        io.to(gameId).emit('readyStatusUpdate', { playerName, isReady });
        const allReady = players.every((p) => p.ready);
        if (allReady) {
          console.log(`Backend: Tous les joueurs sont prêts dans game=${gameId}`);
          io.to(gameId).emit('allPlayersReady');
        }
      }
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('Backend: Error in playerReady =>', error);
    }
  });

  socket.on('joinRoom', async (gameId) => {
    socket.join(gameId);
    console.log(`Backend: Socket ${socket.id} joined room ${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (gameData.players) {
        const players = JSON.parse(gameData.players);
        io.to(gameId).emit('currentPlayers', players);
      }
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('Backend: joinRoom => error', error);
    }
  });

  socket.on('updateAvatar', async ({ gameId, playerId, avatarBase64 }) => {
    console.log(`Backend: updateAvatar => game=${gameId}, player=${playerId}, base64Len=${avatarBase64?.length}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData) {
        console.error(`[updateAvatar] game not found => ${gameId}`);
        return;
      }
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find(p => p.playerId === playerId);
      if (!player) {
        console.error(`[updateAvatar] Player ${playerId} not found in game ${gameId}`);
        return;
      }
      player.avatarBase64 = avatarBase64;
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
      io.to(gameId).emit('currentPlayers', players);
      await broadcastGameInfos(gameId);
    } catch (err) {
      console.error('[updateAvatar] error =>', err);
    }
  });

  // -----------------------------------------------------
  // 4) START GAME
  // -----------------------------------------------------
  socket.on('startGame', async ({ gameId }) => {
    console.log(`Backend: startGame => gameId=${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData) {
        console.error(`[startGame] No gameData found => game:${gameId}`);
        return;
      }
      if (!gameData.maze) {
        console.error(`[startGame] NO 'maze' field in redis => game:${gameId}`);
        return;
      }
      const players = JSON.parse(gameData.players || '[]');
      const maze = JSON.parse(gameData.maze || '[]'); // tableau d'objets
      if (players.length === 0) {
        console.error(`[startGame] No players found => game:${gameId}`);
        return;
      }
      const firstPlayer = players[0];
      const activePlayerName = firstPlayer.playerName;
      await redisClient.hSet(`game:${gameId}`, 'activePlayerId', firstPlayer.playerId);
      io.to(gameId).emit('startGame', {
        maze, // on renvoie la map d’objets
        players,
        activePlayerName,
      });
      console.log(`Backend: Premier joueur actif => ${activePlayerName}, game=${gameId}`);
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error(`Backend: startGame error => gameId=${gameId}`, error);
    }
  });

  // -----------------------------------------------------
  // 5) TURN LOGIC
  // -----------------------------------------------------
  socket.on('endTurn', async (gameId) => {
    console.log(`Backend: endTurn => game=${gameId}`);
    try {
      const turnManager = new TurnManager(gameId, io);
      await turnManager.changeActivePlayer();
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[endTurn] error =>', error);
    }
  });

  socket.on('getActivePlayer', async ({ gameId }) => {
    console.log(`Backend: getActivePlayer => game=${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData || !gameData.activePlayerId) {
        socket.emit('activePlayer', { activePlayerName: null });
        return;
      }
      const players = JSON.parse(gameData.players || '[]');
      const activePlayerId = gameData.activePlayerId;
      const activePlayer = players.find((p) => p.playerId === activePlayerId);
      if (activePlayer) {
        console.log(`Backend: Joueur actif => ${activePlayer.playerName}`);
        socket.emit('activePlayer', { activePlayerName: activePlayer.playerName });
      } else {
        console.error(`[getActivePlayer] No active player found => ${activePlayerId}`);
        socket.emit('activePlayer', { activePlayerName: null });
      }
    } catch (error) {
      console.error('[getActivePlayer] error =>', error);
      socket.emit('activePlayer', { activePlayerName: null });
    }
  });

  socket.on('playerDrawCard', async ({ gameId, playerId }) => {
    console.log(`Backend: playerDrawCard => game=${gameId}, player=${playerId}`);
    try {
      const turnManager = new TurnManager(gameId, io);
      await turnManager.handleDrawCard(playerId);
      await broadcastGameInfos(gameId);
    } catch (err) {
      console.error('[playerDrawCard] error =>', err);
    }
  });

  // -----------------------------------------------------
  // MOVE LOGIC
  // -----------------------------------------------------
  socket.on('playerMove', async ({ gameId, playerId, move }) => {
    console.log(`Backend: playerMove => game=${gameId}, player=${playerId}, move=${move}`);
    try {
      const turnManager = new TurnManager(gameId, io);
      await turnManager.handleMove(playerId, move);
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[playerMove] error =>', error);
      socket.emit('moveError', { message: 'Error processing move' });
    }
  });

  socket.on('getValidMoves', async ({ gameId, playerId }) => {
    console.log(`Backend: getValidMoves => game=${gameId}, player=${playerId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);
      if (!player) {
        socket.emit('validMoves', { error: 'Player not found' });
        return;
      }
      const turnManager = new TurnManager(gameId, io);
      const localMaze = require('../models/map');
      const validMoves = turnManager.getValidMoves(player, localMaze);
      console.log(`[getValidMoves] => `, validMoves);
      socket.emit('validMoves', validMoves);
    } catch (error) {
      console.error('[getValidMoves] error =>', error);
      socket.emit('validMoves', { error: 'Error getting valid moves' });
    }
  });

  // -----------------------------------------------------
  // CHALLENGE LOGIC
  // -----------------------------------------------------
  socket.on('startBetting', async ({ gameId, playerId }) => {
    console.log(`[startBetting] => game=${gameId}, player=${playerId}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Challenge');
      await handler.startBetting();
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[startBetting] error =>', error);
    }
  });

  socket.on('placeBet', async ({ gameId, playerId, bet }) => {
    console.log(`[placeBet] => game=${gameId}, player=${playerId}, bet=${bet}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Challenge');
      await handler.handleBet(playerId, bet);
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);
      if (!player) return;
      console.log(`[placeBet] => Emitting betPlaced for ${player.playerName}`);
      io.to(gameId).emit('betPlaced', {
        playerName: player.playerName,
        bet: bet,
      });
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[placeBet] error =>', error);
    }
  });

  socket.on('placeChallengeVote', async ({ gameId, playerId, vote }) => {
    console.log(`[placeChallengeVote] => game=${gameId}, player=${playerId}, vote=${vote}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Challenge');
      await handler.handleChallengeVote(playerId, vote);
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[placeChallengeVote] error =>', error);
    }
  });

  // -----------------------------------------------------
  // QUIZ
  // -----------------------------------------------------
  socket.on('startQuiz', async ({ gameId, playerId, chosenTheme }) => {
    console.log(`[startQuiz] => game=${gameId}, player=${playerId}, theme=${chosenTheme}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Quiz');
      await handler.startQuiz(playerId, chosenTheme);
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[startQuiz] error =>', error);
    }
  });

  socket.on('quizAnswer', async ({ gameId, playerId, answer }) => {
    console.log(`[quizAnswer] => game=${gameId}, player=${playerId}, answer=${answer}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Quiz');
      await handler.handleAnswer(playerId, answer);
      await broadcastGameInfos(gameId);
    } catch (error) {
      console.error('[quizAnswer] error =>', error);
    }
  });

  // -----------------------------------------------------
  // INVENTORY
  // -----------------------------------------------------
  socket.on('pickUpObject', async ({ gameId, playerId }) => {
    console.log(`[pickUpObject] => game=${gameId}, player=${playerId}`);
    try {
      const currentCardJson = await redisClient.hGet(`game:${gameId}`, 'currentCard');
      if (!currentCardJson) {
        console.error('[pickUpObject] No current card in redis');
        return;
      }
      const currentCard = JSON.parse(currentCardJson);
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players  = JSON.parse(gameData.players || '[]');
      const player   = players.find(p => p.playerId === playerId);
      if (!player) return;
      if (!player.inventory) player.inventory = [];
      const itemData = {
        itemId: currentCard.card_id,
        name: currentCard.card_name,
        image: currentCard.card_image,
        description: currentCard.card_description,
      };
      player.inventory.push(itemData);
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
      io.to(gameId).emit('objectPickedUp', { playerId, itemData });
      await redisClient.hSet(`game:${gameId}`, 'turnState', 'movement');
      await broadcastGameInfos(gameId);
    } catch (err) {
      console.error('[pickUpObject] error =>', err);
    }
  });

  socket.on('discardObject', async ({ gameId, playerId, itemId }) => {
    console.log(`[discardObject] => game=${gameId}, player=${playerId}, itemId=${itemId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players  = JSON.parse(gameData.players || '[]');
      const player   = players.find(p => p.playerId === playerId);
      if (!player) return;
      if (!player.inventory) {
        player.inventory = [];
      }
      player.inventory = player.inventory.filter(i => i.itemId !== itemId);
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
      io.to(gameId).emit('objectDiscarded', { playerId, itemId });
      await broadcastGameInfos(gameId);
    } catch (err) {
      console.error('[discardObject] error =>', err);
    }
  });

  socket.on('useObject', async ({ gameId, playerId, itemId }) => {
    console.log(`[useObject] => game=${gameId}, player=${playerId}, itemId=${itemId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players  = JSON.parse(gameData.players || '[]');
      const player   = players.find(p => p.playerId === playerId);
      if (!player) return;
      const item = (player.inventory || []).find(i => i.itemId === itemId);
      if (!item) {
        console.log("[useObject] item not found in player's inventory");
        return;
      }
      await useObjectEffect(gameId, playerId, item, players, gameData);
      await broadcastGameInfos(gameId);
      io.to(gameId).emit('objectUsed', {
        playerId,
        itemId,
        message: `Player used ${item.name}`
      });
    } catch (error) {
      console.error("[useObject] error =>", error);
    }
  });

  socket.on('teleportPlayer', async ({ gameId, playerId, coordinate }) => {
    console.log(`Backend: teleportPlayer => game=${gameId}, player=${playerId}, coord=${coordinate}`);
    if (!coordinate || coordinate.length < 2) return;
    const letter = coordinate.charAt(0);
    const number = parseInt(coordinate.substring(1), 10);
    const x = letter.charCodeAt(0) - 65;
    const y = number - 1;
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData || !gameData.players) return;
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find(p => p.playerId === playerId);
      if (!player) return;
      player.position = { x, y };
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
      io.to(gameId).emit('positionUpdate', { playerId, position: player.position, orientation: player.orientation });
    } catch (err) {
      console.error('Backend: teleportPlayer error =>', err);
    }
  });

  socket.on('disconnect', () => {
    console.log('Backend: Socket.IO: Un joueur s\'est déconnecté');
  });
};

module.exports = handleSocketEvents;
