// game-api/game/turnManager.js

const redisClient = require('../config/redis');
const { getCardHandlerForCategory } = require('./cardHandlers');
const { getRandomCard, getCardById } = require('../models/card');
const maze = require('../models/map'); // la map initiale

function xyToGridLabel(x, y) {
  const colLetter = String.fromCharCode(65 + x);
  const rowNumber = y + 1;
  return `${colLetter}${rowNumber}`;
}

class TurnManager {
  constructor(gameId, io) {
    this.gameId = gameId;
    this.io = io;
    console.log(`TurnManager: created for game=${gameId}`);
  }

  async handleMove(playerId, move) {
    const gameKey = `game:${this.gameId}`;
    const gameData = await redisClient.hGetAll(gameKey);
    if (!gameData || !gameData.players) {
      console.error(`[handleMove] No players in gameData for ${this.gameId}`);
      return;
    }
    const players = JSON.parse(gameData.players || '[]');
    const player = players.find((p) => p.playerId === playerId);
    if (!player) {
      console.error(`[handleMove] Player ${playerId} not found in game:${this.gameId}`);
      this.io.to(this.gameId).emit('moveError', { message: 'Player not found' });
      return;
    }
    const validMoves = this.getValidMoves(player, maze);
    if (
      (move === 'forward' && !validMoves.canMoveForward) ||
      (move === 'left' && !validMoves.canMoveLeft) ||
      (move === 'right' && !validMoves.canMoveRight)
    ) {
      this.io.to(this.gameId).emit('moveError', { message: 'Invalid move' });
      return;
    }
    const result = this.processPlayerMove(player, move, maze);
    if (!result.success) {
      this.io.to(this.gameId).emit('moveError', { message: result.message });
      return;
    }
    await redisClient.hSet(gameKey, 'players', JSON.stringify(players));
    const currentCoord = xyToGridLabel(player.position.x, player.position.y);
    console.log(`[handleMove] Player "${player.playerName}" => ${currentCoord} (orient=${player.orientation})`);
    this.io.to(this.gameId).emit('positionUpdate', {
      playerId,
      position: player.position,
      orientation: player.orientation,
    });
    this.io.to(this.gameId).emit('turnStateChanged', {
      turnState: 'drawStep',
      playerId,
    });
    setTimeout(async () => {
      await this.handleDrawCard(playerId);
    }, 2000);
  }

  async handleDrawCard(playerId) {
    const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
    if (!gameData || !gameData.players) {
      console.error(`[handleDrawCard] No gameData for ${this.gameId}`);
      return;
    }
    const players = JSON.parse(gameData.players || '[]');
    const player = players.find(p => p.playerId === playerId);
    if (!player) {
      console.error(`[handleDrawCard] Player ${playerId} not found in players array`);
      return;
    }
    const card = await this.drawCard(player);
    if (!card) {
      console.error(`[handleDrawCard] No card returned!?`);
      return;
    }
    console.log(`[handleDrawCard] Drew card "${card.card_name}" for ${player.playerName}`);
    this.io.to(this.gameId).emit('turnStateChanged', {
      turnState: 'cardDrawn',
      playerId,
    });
  }

  getValidMoves(player, localMaze) {
    const { x, y } = player.position;
    const orientation = player.orientation;
    const orientations = ['north', 'east', 'south', 'west'];
    const idx = orientations.indexOf(orientation);
    const offsets = {
      north: { dx: 0, dy: -1 },
      east: { dx: 1, dy: 0 },
      south: { dx: 0, dy: 1 },
      west: { dx: -1, dy: 0 },
    };
    const isAccessible = (pos) =>
      pos.y >= 0 && pos.y < localMaze.length &&
      pos.x >= 0 && pos.x < localMaze[0].length &&
      localMaze[pos.y][pos.x].accessible;
    const forward = {
      x: x + offsets[orientation].dx,
      y: y + offsets[orientation].dy,
    };
    const getTurnMove = (direction) => {
      let newIdx = idx;
      if (direction === 'left') newIdx = (idx + 3) % 4;
      if (direction === 'right') newIdx = (idx + 1) % 4;
      const newOrientation = orientations[newIdx];
      return {
        x: x + offsets[newOrientation].dx,
        y: y + offsets[newOrientation].dy,
        orientation: newOrientation,
      };
    };
    const leftMove = getTurnMove('left');
    const rightMove = getTurnMove('right');
    return {
      canMoveForward: isAccessible(forward),
      canMoveLeft: isAccessible(leftMove),
      canMoveRight: isAccessible(rightMove),
    };
  }

  processPlayerMove(player, move, localMaze) {
    const { x, y } = player.position;
    const orientations = ['north', 'east', 'south', 'west'];
    const idx = orientations.indexOf(player.orientation);
    const offsets = {
      north: { dx: 0, dy: -1 },
      east: { dx: 1, dy: 0 },
      south: { dx: 0, dy: 1 },
      west: { dx: -1, dy: 0 },
    };

    if (move === 'forward') {
      const { dx, dy } = offsets[player.orientation];
      const newX = x + dx;
      const newY = y + dy;
      if (
        newY >= 0 && newY < localMaze.length &&
        newX >= 0 && newX < localMaze[0].length &&
        localMaze[newY][newX].accessible
      ) {
        player.position.x = newX;
        player.position.y = newY;
        return { success: true };
      }
      return { success: false, message: 'Chemin bloqué' };
    } else if (move === 'left' || move === 'right') {
      let newIdx = idx;
      if (move === 'left') newIdx = (idx + 3) % 4;
      if (move === 'right') newIdx = (idx + 1) % 4;
      const newOrientation = orientations[newIdx];
      const offset = offsets[newOrientation];
      const newX = x + offset.dx;
      const newY = y + offset.dy;
      if (
        newY >= 0 && newY < localMaze.length &&
        newX >= 0 && newX < localMaze[0].length &&
        localMaze[newY][newX].accessible
      ) {
        player.orientation = newOrientation;
        player.position.x = newX;
        player.position.y = newY;
        return { success: true };
      }
      return { success: false, message: 'Chemin bloqué lors du tournant' };
    }
    return { success: false, message: 'Mouvement invalide' };
  }

  async drawCard(player) {
    const forcedIds = await redisClient.get(`forcedDraw:${this.gameId}:${player.playerId}`);
    const forcedCountStr = await redisClient.get(`forcedDrawCount:${this.gameId}:${player.playerId}`);
    let forcedCount = forcedCountStr ? parseInt(forcedCountStr, 10) : 0;
    let card;
    if (forcedIds && forcedCount > 0) {
      const possibleIds = forcedIds.split(',').map(x => parseInt(x, 10));
      const idx = Math.floor(Math.random() * possibleIds.length);
      const forcedCardId = possibleIds[idx];
      card = await getCardById(forcedCardId);
      forcedCount--;
      if (forcedCount <= 0) {
        await redisClient.del(`forcedDraw:${this.gameId}:${player.playerId}`);
        await redisClient.del(`forcedDrawCount:${this.gameId}:${player.playerId}`);
      } else {
        await redisClient.set(`forcedDrawCount:${this.gameId}:${player.playerId}`, forcedCount.toString());
      }
    } else {
      card = await getRandomCard();
    }
    const handler = getCardHandlerForCategory(this.gameId, this.io, card.card_category);
    await handler.handleCard(player.playerId, card);
    return card;
  }

  async changeActivePlayer() {
    const gameKey = `game:${this.gameId}`;
    const gameData = await redisClient.hGetAll(gameKey);
    if (!gameData) {
      console.error(`[changeActivePlayer] No data for ${this.gameId}`);
      return;
    }
    const players = JSON.parse(gameData.players || '[]');
    const currentActiveId = gameData.activePlayerId;
    const doubleTurnKey = `doubleTurn:${this.gameId}:${currentActiveId}`;
    const doubleTurn = await redisClient.get(doubleTurnKey);
    if (doubleTurn === '1') {
      console.log(`TurnManager: Player ${currentActiveId} has a double turn`);
      await redisClient.del(doubleTurnKey);
      const samePlayer = players.find(p => p.playerId === currentActiveId);
      if (!samePlayer) return;
      this.io.to(this.gameId).emit('activePlayerChanged', {
        activePlayerId: samePlayer.playerId,
        activePlayerName: samePlayer.playerName,
        turnState: 'movement',
      });
      this.io.to(this.gameId).emit('positionUpdate', {
        playerId: samePlayer.playerId,
        position: samePlayer.position,
        orientation: samePlayer.orientation,
      });
      return;
    }
    let idx = players.findIndex(p => p.playerId === currentActiveId);
    if (idx === -1) {
      console.error(`[changeActivePlayer] currentActiveId introuvable => ${currentActiveId}`);
      return;
    }
    idx = (idx + 1) % players.length;
    const newActive = players[idx];
    await redisClient.hSet(gameKey, 'activePlayerId', newActive.playerId);
    console.log(`TurnManager: Nouveau joueur actif => ${newActive.playerName} (ID=${newActive.playerId})`);
    this.io.to(this.gameId).emit('activePlayerChanged', {
      activePlayerId: newActive.playerId,
      activePlayerName: newActive.playerName,
      turnState: 'movement',
    });
    this.io.to(this.gameId).emit('positionUpdate', {
      playerId: newActive.playerId,
      position: newActive.position,
      orientation: newActive.orientation,
    });
  }
}

module.exports = TurnManager;
