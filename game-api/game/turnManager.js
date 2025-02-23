// game/turnManager.js
const redisClient = require('../config/redis');
const { getCardHandlerForCategory } = require('./cardHandlers');
const { getRandomCard, getCardById } = require('../models/card');


class TurnManager {
  constructor(gameId, io) {
    this.gameId = gameId;
    this.io = io;
  }

  /**
   * Le joueur actif demande à se déplacer => handleMove()
   *  - On vérifie la validité
   *  - On bouge le joueur
   *  - Après le mouvement, on pioche une carte (drawCard)
   */
  async handleMove(playerId, move) {
    const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
    const players = JSON.parse(gameData.players || '[]');
    const player = players.find((p) => p.playerId === playerId);

    if (!player) {
      console.error(`TurnManager: Player with ID ${playerId} not found in game ${this.gameId}.`);
      this.io.to(this.gameId).emit('moveError', { message: 'Player not found' });
      return;
    }

    const maze = require('../models/map');
    const validMoves = this.getValidMoves(player, maze);

    // Vérifie si le move est possible
    if (
      (move === 'forward' && !validMoves.canMoveForward) ||
      (move === 'left' && !validMoves.canMoveLeft) ||
      (move === 'right' && !validMoves.canMoveRight)
    ) {
      this.io.to(this.gameId).emit('moveError', { message: 'Invalid move' });
      return;
    }

    // Applique le move
    const result = this.processPlayerMove(player, move, maze);

    if (result.success) {
      // Sauvegarde la nouvelle position/orientation dans Redis
      await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

      // Notifie tout le monde de la position du joueur
      this.io.to(this.gameId).emit('positionUpdate', {
        playerId,
        position: player.position,
        orientation: player.orientation,
      });

      // Maintenant on pioche une carte
      await this.drawCard(player);
    } else {
      this.io.to(this.gameId).emit('moveError', { message: result.message });
    }
  }

  /**
   * Renvoie les coups valides (forward, left, right) en fonction de la map
   */
  getValidMoves(player, maze) {
    const { x, y } = player.position;
    const orientation = player.orientation;

    const orientations = ['north', 'east', 'south', 'west'];
    const idx = orientations.indexOf(orientation);

    const movementOffsets = {
      north: { dx: 0, dy: -1 },
      east: { dx: 1, dy: 0 },
      south: { dx: 0, dy: 1 },
      west: { dx: -1, dy: 0 },
    };

    const isAccessible = (pos) =>
      pos.y >= 0 &&
      pos.y < maze.length &&
      pos.x >= 0 &&
      pos.x < maze[0].length &&
      maze[pos.y][pos.x].accessible;

    // Case "forward"
    const forward = {
      x: x + movementOffsets[orientation].dx,
      y: y + movementOffsets[orientation].dy,
    };

    // Construction d'un move gauche/droite => orientation modifiée
    const getTurnMove = (direction) => {
      let newIdx = idx;
      if (direction === 'left') newIdx = (idx + 3) % 4; // rotation à gauche
      if (direction === 'right') newIdx = (idx + 1) % 4; // rotation à droite
      const newOrientation = orientations[newIdx];
      return {
        x: x + movementOffsets[newOrientation].dx,
        y: y + movementOffsets[newOrientation].dy,
      };
    };

    const left = getTurnMove('left');
    const right = getTurnMove('right');

    return {
      canMoveForward: isAccessible(forward),
      canMoveLeft: isAccessible(left),
      canMoveRight: isAccessible(right),
    };
  }

  /**
   * Applique le mouvement au joueur (modifie player.position / orientation)
   */
  processPlayerMove(player, move, maze) {
    let { x, y } = player.position;
    let orientation = player.orientation;

    const orientations = ['north', 'east', 'south', 'west'];
    const idx = orientations.indexOf(orientation);

    const movementOffsets = {
      north: { dx: 0, dy: -1 },
      east: { dx: 1, dy: 0 },
      south: { dx: 0, dy: 1 },
      west: { dx: -1, dy: 0 },
    };

    if (move === 'forward') {
      const offset = movementOffsets[orientation];
      const newX = x + offset.dx;
      const newY = y + offset.dy;

      // Vérifie si c'est accessible
      if (
        newY >= 0 &&
        newY < maze.length &&
        newX >= 0 &&
        newX < maze[0].length &&
        maze[newY][newX].accessible
      ) {
        player.position = { x: newX, y: newY };
        return { success: true };
      } else {
        return { success: false, message: "Impossible d'avancer; chemin bloqué" };
      }
    } else if (move === 'left' || move === 'right') {
      // On change juste l'orientation
      let newIdx = idx;
      if (move === 'left') newIdx = (idx + 3) % 4;
      if (move === 'right') newIdx = (idx + 1) % 4;
      player.orientation = orientations[newIdx];
      return { success: true };
    } else {
      return { success: false, message: 'Mouvement invalide' };
    }
  }

  /**
   * Pioche une carte aléatoire et invoque le handler approprié
   */
  async drawCard(player) {
    // Vérifier si un forced draw est activé pour ce joueur
    const forcedIds = await redisClient.get(`forcedDraw:${this.gameId}:${player.playerId}`);
    const forcedCountStr = await redisClient.get(`forcedDrawCount:${this.gameId}:${player.playerId}`);
    let forcedCount = forcedCountStr ? parseInt(forcedCountStr, 10) : 0;
    
    let card;
    if (forcedIds && forcedCount > 0) {
      // forcedIds = liste d'IDs séparés par des virgules, ex: "2,3,6"
      const possibleIds = forcedIds.split(',').map(x => parseInt(x, 10));
      const randomIndex = Math.floor(Math.random() * possibleIds.length);
      const forcedCardId = possibleIds[randomIndex];
      card = await getCardById(forcedCardId);
      forcedCount -= 1;
      if (forcedCount <= 0) {
        await redisClient.del(`forcedDraw:${this.gameId}:${player.playerId}`);
        await redisClient.del(`forcedDrawCount:${this.gameId}:${player.playerId}`);
      } else {
        await redisClient.set(`forcedDrawCount:${this.gameId}:${player.playerId}`, forcedCount.toString());
      }
    } else {
      // Pioche classique
      card = await getRandomCard();
    }
    
    // Utiliser le handler approprié pour la carte piochée
    const handler = getCardHandlerForCategory(this.gameId, this.io, card.card_category);
    await handler.handleCard(player.playerId, card);
  }
  
  

  /**
   * Fin d'un tour => on passe le joueur actif au suivant
   */
  async changeActivePlayer() {
    const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
    if (!gameData) {
      console.error(`TurnManager: Aucune donnée de jeu trouvée pour ${this.gameId}`);
      return;
    }

    const players = JSON.parse(gameData.players || '[]');

    const currentActiveId = gameData.activePlayerId;

    // Vérifier le doubleTurnKey
    const doubleTurnKey = `doubleTurn:${this.gameId}:${currentActiveId}`;
    const doubleTurn = await redisClient.get(doubleTurnKey);
    if (doubleTurn === '1') {
      console.log(`TurnManager: Player ${currentActiveId} gets a second turn!`);
      // On supprime le flag
      await redisClient.del(doubleTurnKey);
      // Ne pas changer de joueur, on renvoie juste "activePlayerChanged" ou turnStarted
      // Ex:
      this.io.to(this.gameId).emit('activePlayerChanged', {
        activePlayerId: currentActiveId,
        activePlayerName: players.find(p => p.playerId === currentActiveId)?.playerName,
        turnState: 'movement',
      });
      return; 
    }

    let currentIndex = players.findIndex((p) => p.playerId === gameData.activePlayerId);

    if (currentIndex === -1) {
      console.error(`TurnManager: Joueur actif introuvable dans ${this.gameId}`);
      return;
    }

    // On passe au joueur suivant
    currentIndex = (currentIndex + 1) % players.length;
    const newActivePlayer = players[currentIndex];

    // On stocke le nouvel activePlayer
    await redisClient.hSet(`game:${this.gameId}`, 'activePlayerId', newActivePlayer.playerId);

    console.log(
      `TurnManager: Nouveau joueur actif: ${newActivePlayer.playerName} (ID: ${newActivePlayer.playerId})`,
    );
    
    // On émet "activePlayerChanged" avec turnState = 'movement'
    // => le front saura que le nouveau joueur peut d'abord se déplacer
    this.io.to(this.gameId).emit('activePlayerChanged', {
      activePlayerId: newActivePlayer.playerId,
      activePlayerName: newActivePlayer.playerName,
      turnState: 'movement',
    });
  }
}

module.exports = TurnManager;
