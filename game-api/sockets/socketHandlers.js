// sockets/socketHandlers.js

const TurnManager = require('../game/turnManager');
const { getCardHandlerForCategory } = require('../game/cardHandlers');
const redisClient = require('../config/redis');
const { getRandomCard } = require('../models/card');
const { useObjectEffect } = require('../game/objects/objectEffects');

const handleSocketEvents = (io, socket) => {
  console.log('Backend: Socket.IO: Nouveau joueur connecté');


  // -----------------------------------------------------
  // FONCTION Tutorial
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
        const gameData = await redisClient.hGetAll(`game:${gameId}`);
        const players = JSON.parse(gameData.players || '[]');
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
  // FONCTION UTILE: broadcastGameInfos
  // -----------------------------------------------------
  async function broadcastGameInfos(gameId) {
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData) return;

      const players = JSON.parse(gameData.players || '[]');
      const activePlayerId = gameData.activePlayerId;

      // console.log("Backend: broadcastGameInfos -> players =", players);

      const sorted = [...players].sort((a, b) => (b.berries || 0) - (a.berries || 0));

      const playersInfo = sorted.map((p, index) => {
        return {
          playerId: p.playerId,
          playerName: p.playerName,
          berries: p.berries || 0,
          rank: index + 1,
          avatarBase64: p.avatarBase64 || '',
          inventory: p.inventory || [],
        };
      });
      

      let activePlayerName = null;
      const activePlayer = players.find((p) => p.playerId === activePlayerId);
      if (activePlayer) {
        activePlayerName = activePlayer.playerName;
      }

      console.log("Backend: broadcastGameInfos");
      
      io.to(gameId).emit('gameInfos', {
        players: playersInfo,
        activePlayerName: activePlayerName,
        // activePlayerAvatar: activePlayer?.avatarUrl || null
      });
    } catch (error) {
      console.error('broadcastGameInfos: Erreur lors de la récupération des infos de jeu:', error);
    }
  }

  socket.on('requestGameInfos', async ({ gameId }) => {
    console.log(`Backend: Reçu 'requestGameInfos' pour game=${gameId}`);
    await broadcastGameInfos(gameId);
  });

  // -----------------------------------------------------
  // LOBBY LOGIC
  // -----------------------------------------------------
  socket.on('playerReady', async ({ gameId, playerName, isReady }) => {
    console.log(`Backend: Mise à jour du statut prêt pour ${playerName} dans la partie ${gameId} : ${isReady}`);
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
          console.log(`Backend: Tous les joueurs sont prêts dans la partie ${gameId}`);
          io.to(gameId).emit('allPlayersReady');
        }
      }

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Erreur lors de la mise à jour de l\'état "Prêt" du joueur:', error);
    }
  });

  socket.on('joinRoom', async (gameId) => {
    socket.join(gameId);
    console.log(`Backend: Socket ${socket.id} a rejoint la salle ${gameId}`);

    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');

      console.log(`Backend: Envoi de la liste des joueurs de la partie ${gameId}`);
      io.to(gameId).emit('currentPlayers', players);

      // Nouveau: broadcast infos
      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Erreur lors de la récupération des joueurs:', error);
    }
  });

  socket.on('updateAvatar', async ({ gameId, playerId, avatarBase64 }) => {
    console.log(`Backend: updateAvatar event for player=${playerId}, len(avatarBase64)=${avatarBase64?.length}`);
    
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData) {
        console.error(`Backend: Game not found for id=${gameId}`);
        return;
      }
      
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find(p => p.playerId === playerId);
    
      if (!player) {
        console.error(`Backend: Player with ID ${playerId} not found in game ${gameId}`);
        return;
      }
    
      // Mise à jour
      player.avatarBase64 = avatarBase64;
      console.log(`Backend: Storing avatarBase64 for ${player.playerName} in game ${gameId}`);
    
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
    
      // 1) On renvoie currentPlayers pour que le lobby reçoive la liste actualisée
      io.to(gameId).emit('currentPlayers', players);
  
      // 2) Optionnel: broadcastGameInfos pour le in-game
      await broadcastGameInfos(gameId);
    
    } catch (err) {
      console.error('Backend: updateAvatar error:', err);
    }
  });
  

  // -----------------------------------------------------
  // START OF THE GAME LOGIC
  // -----------------------------------------------------
  socket.on('startGame', async ({ gameId }) => {
    console.log(`Backend: Demande de démarrage du jeu pour la partie ${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const maze = JSON.parse(gameData.maze || '[]');
      const players = JSON.parse(gameData.players || '[]');
  
      if (players.length === 0) {
        console.error(`Backend: Aucun joueur trouvé pour le jeu ${gameId}`);
        return;
      }
  
      // Définir le premier joueur
      const firstPlayer = players[0];
      const activePlayerName = firstPlayer.playerName;
      await redisClient.hSet(`game:${gameId}`, 'activePlayerId', firstPlayer.playerId);
  
      // On envoie 'startGame' au front
      io.to(gameId).emit('startGame', {
        maze,
        players,
        activePlayerName,
      });
  
      console.log(`Backend: Premier joueur actif défini : ${activePlayerName} (ID: ${firstPlayer.playerId})`);
  
      // broadcast infos
      await broadcastGameInfos(gameId);
      
      // On calcule le snippet du premier joueur
      const turnManager = new TurnManager(gameId, io);
      const snippet = turnManager.getLocalMapSnippet(
        firstPlayer.position.x,
        firstPlayer.position.y,
        firstPlayer.orientation,
        maze
      );
      
      console.log(`[startGame => snippet] 
        Player=${firstPlayer.playerName} 
        pos=(${firstPlayer.position.x},${firstPlayer.position.y}), 
        orientation=${firstPlayer.orientation}, snippet=`, snippet);
  
      // Émet 'positionUpdate' pour le premier joueur
      io.to(gameId).emit('positionUpdate', {
        playerId: firstPlayer.playerId,
        position: firstPlayer.position,
        orientation: firstPlayer.orientation,
        localMapSnippet: snippet
      });

    } catch (error) {
      console.error(`Backend: Erreur lors du démarrage du jeu pour ${gameId} :`, error);
    }
  });
  // -----------------------------------------------------
  // TURN LOGIC
  // -----------------------------------------------------
  socket.on('endTurn', async (gameId) => {
    if (typeof gameId !== 'string') {
      console.error(`Backend: gameId reçu dans un format incorrect:`, gameId);
      return;
    }

    console.log(`Backend: Fin du tour reçu pour la partie ${gameId}`);
    try {
      const turnManager = new TurnManager(gameId, io);
      await turnManager.changeActivePlayer();

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Erreur lors de endTurn:', error);
    }
  });

  socket.on('getActivePlayer', async ({ gameId }) => {
    console.log(`Backend: Reçu demande de getActivePlayer pour la partie ${gameId}`);
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
        console.log(`Backend: Joueur actif pour le jeu ${gameId} : ${activePlayer.playerName}`);
        socket.emit('activePlayer', { activePlayerName: activePlayer.playerName });
      } else {
        console.error(`Backend: Aucun joueur actif trouvé pour le jeu ${gameId}`);
        socket.emit('activePlayer', { activePlayerName: null });
      }
    } catch (error) {
      console.error('Backend: Erreur lors de la récupération du joueur actif :', error);
      socket.emit('activePlayer', { activePlayerName: null });
    }
  });

  
  socket.on('playerDrawCard', async ({ gameId, playerId }) => {
    console.log(`Backend: Player ${playerId} wants to draw a card in game ${gameId}`);
    try {
      const turnManager = new TurnManager(gameId, io);
      await turnManager.handleDrawCard(playerId);
      await broadcastGameInfos(gameId);
    } catch (err) {
      console.error("playerDrawCard error:", err);
    }
  });
  

  // -----------------------------------------------------
  // MOVE LOGIC
  // -----------------------------------------------------
  socket.on('playerMove', async ({ gameId, playerId, move }) => {
    console.log(`Backend: Player ${playerId} moves ${move} in game ${gameId}`);
    try {
      const turnManager = new TurnManager(gameId, io);
      await turnManager.handleMove(playerId, move);

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Error processing player move:', error);
      socket.emit('moveError', { message: 'Error processing move' });
    }
  });

  socket.on('getValidMoves', async ({ gameId, playerId }) => {
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);

      if (!player) {
        socket.emit('validMoves', { error: 'Player not found' });
        return;
      }

      const turnManager = new TurnManager(gameId, io);
      const maze = require('../models/map');
      const validMoves = turnManager.getValidMoves(player, maze);

      console.log(`Backend: Valid moves for player ${playerId}:`, validMoves);
      socket.emit('validMoves', validMoves);
    } catch (error) {
      console.error('Backend: Error getting valid moves:', error);
      socket.emit('validMoves', { error: 'Error getting valid moves' });
    }
  });

  // -----------------------------------------------------
  // CHALLENGE LOGIC (BETS)
  // -----------------------------------------------------
  socket.on('startBetting', async ({ gameId, playerId }) => {
    console.log(`Backend: Player ${playerId} is starting the betting phase in game ${gameId}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Challenge');
      await handler.startBetting();

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Error starting betting phase:', error);
    }
  });

  socket.on('placeBet', async ({ gameId, playerId, bet }) => {
    console.log(`Backend: Player ${playerId} placed a bet in game ${gameId}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Challenge');
      await handler.handleBet(playerId, bet);

      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);

      if (!player) {
        console.error(`Player not found for ID: ${playerId}`);
        return;
      }

      console.log(`Backend: Emitting betPlaced event with playerName: ${player.playerName}`);
      io.to(gameId).emit('betPlaced', {
        playerName: player.playerName,
        bet: bet,
      });

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Error processing bet:', error);
    }
  });

  socket.on('placeChallengeVote', async ({ gameId, playerId, vote }) => {
    console.log(`Backend: Player ${playerId} placed a challenge vote in game ${gameId}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Challenge');
      await handler.handleChallengeVote(playerId, vote);

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Error processing challenge vote:', error);
    }
  });

  // -----------------------------------------------------
  // QUIZ LOGIC
  // -----------------------------------------------------
  socket.on('startQuiz', async ({ gameId, playerId, chosenTheme }) => {
    console.log(`Backend: Player ${playerId} starts the quiz with theme=${chosenTheme} in game=${gameId}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Quiz');
      await handler.startQuiz(playerId, chosenTheme);

      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Error starting quiz:', error);
    }
  });
  
  socket.on('quizAnswer', async ({ gameId, playerId, answer }) => {
    console.log(`Backend: Player ${playerId} answered quiz question in game=${gameId}`);
    try {
      const handler = getCardHandlerForCategory(gameId, io, 'Quiz');
      await handler.handleAnswer(playerId, answer);

      // broadcast infos
      await broadcastGameInfos(gameId);

    } catch (error) {
      console.error('Backend: Error processing quizAnswer:', error);
    }
  });


  // -----------------------------------------------------
  // INVENTORY LOGIC
  // -----------------------------------------------------

  socket.on('pickUpObject', async ({ gameId, playerId }) => {
    console.log(`Backend: Player ${playerId} wants to pick up object in game ${gameId}`);
    try {
      // 1) Récupérer la currentCard (qui est censée être un "Object")
      const currentCardJson = await redisClient.hGet(`game:${gameId}`, 'currentCard');
      if (!currentCardJson) {
        console.error("No current card in redis for this game");
        return;
      }
      const currentCard = JSON.parse(currentCardJson);

      // 2) Récupérer l'info du joueur
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players  = JSON.parse(gameData.players || '[]');
      const player   = players.find(p => p.playerId === playerId);
      if (!player) return;

      // 3) Si pas de champ inventory, on l'init
      if (!player.inventory) {
        player.inventory = [];
      }
      
      // 4) Ajouter cet objet dans l'inventaire
      const itemData = {
        itemId: currentCard.card_id,  // par ex. 101
        name: currentCard.card_name,
        image: currentCard.card_image,
        description: currentCard.card_description,
      };
      player.inventory.push(itemData);

      // 5) Sauvegarder en Redis
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));

      // 6) Émettre un event de succès (optionnel), ou on fait juste un broadcast
      io.to(gameId).emit('objectPickedUp', {
        playerId,
        itemData
      });

      // 7) On peut mettre le turnState à 'objectCollected' ou carrément laisser le joueur terminer son tour
      //    (vous décidez)
      // e.g.:
      await redisClient.hSet(`game:${gameId}`, 'turnState', 'movement'); 
      // => ou "endOfTurn", c'est à vous de décider la suite du workflow.

      // 8) broadcast gameInfos => tout le monde voit que l'inventaire du joueur a changé
      await broadcastGameInfos(gameId);

    } catch (err) {
      console.error('Error picking up object:', err);
    }
  });

  socket.on('discardObject', async ({ gameId, playerId, itemId }) => {
    console.log(`Backend: Player ${playerId} discards item ${itemId} in game ${gameId}`);
    try {
      // 1) Récupérer le joueur
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players  = JSON.parse(gameData.players || '[]');
      const player   = players.find(p => p.playerId === playerId);
      if (!player) return;

      // 2) Retirer l'item du tableau
      if (!player.inventory) {
        player.inventory = [];
      }
      player.inventory = player.inventory.filter(i => i.itemId !== itemId);

      // 3) Mettre à jour Redis
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));

      // 4) Émettre un event (optionnel) + broadcast
      io.to(gameId).emit('objectDiscarded', { playerId, itemId });
      await broadcastGameInfos(gameId);

    } catch (err) {
      console.error('Error discarding object:', err);
    }
  });

  socket.on('useObject', async ({ gameId, playerId, itemId }) => {
    console.log(`Backend: Player ${playerId} uses item ${itemId} in game ${gameId}`);
    try {
      // 1) Charger l'état du jeu
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players  = JSON.parse(gameData.players || '[]');
      const player   = players.find(p => p.playerId === playerId);
      if (!player) return;
    
      // 2) Trouver l'item dans l'inventaire
      const item = (player.inventory || []).find(i => i.itemId === itemId);
      if (!item) {
        console.log("Backend: item not found in player's inventory");
        return;
      }
    
      // 3) Appeler la logique "useObjectEffect"
      await useObjectEffect(gameId, playerId, item, players, gameData);
    
      // 4) broadcastGameInfos pour mettre à jour le front
      await broadcastGameInfos(gameId);
    
      // 5) Émettre un "objectUsed" (feedback)
      io.to(gameId).emit('objectUsed', {
        playerId,
        itemId,
        message: `Player used ${item.name}`
      });
    } catch (error) {
      console.error("Error in useObject:", error);
    }
  });
  
  
  // END
  socket.on('disconnect', () => {
    console.log('Backend: Socket.IO: Un joueur s\'est déconnecté');
  });
};

module.exports = handleSocketEvents;
