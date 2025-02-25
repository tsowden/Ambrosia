// game/turnManager.js

const redisClient = require('../config/redis');
const { getCardHandlerForCategory } = require('./cardHandlers');
const { getRandomCard, getCardById } = require('../models/card');
const maze = require('../models/map');

/** Convertit (x,y) -> "A1..P20" */
function xyToGridLabel(x, y) {
  const colLetter = String.fromCharCode(65 + x);
  const rowNumber = y + 1;
  return `${colLetter}${rowNumber}`;
}

class TurnManager {
  constructor(gameId, io) {
    this.gameId = gameId;
    this.io = io;
  }

  /**
   * Étape "movement" : on bouge le joueur, on passe le turnState à 'drawStep'
   */
  async handleMove(playerId, move) {
    const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
    const players = JSON.parse(gameData.players || '[]');
    const player = players.find((p) => p.playerId === playerId);

    if (!player) {
      console.error(`handleMove: Player ${playerId} not found`);
      this.io.to(this.gameId).emit('moveError', { message: 'Player not found' });
      return;
    }

    // Vérif des moves autorisés
    const validMoves = this.getValidMoves(player, maze);
    if (
      (move === 'forward' && !validMoves.canMoveForward) ||
      (move === 'left' && !validMoves.canMoveLeft) ||
      (move === 'right' && !validMoves.canMoveRight)
    ) {
      this.io.to(this.gameId).emit('moveError', { message: 'Invalid move' });
      return;
    }

    // Applique
    const result = this.processPlayerMove(player, move, maze);
    if (!result.success) {
      this.io.to(this.gameId).emit('moveError', { message: result.message });
      return;
    }

    // Sauvegarde la nouvelle position
    await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

    // Calcule snippet
    const snippet = this.getLocalMapSnippet(
      player.position.x,
      player.position.y,
      player.orientation,
      maze
    );

    // Log position
    const currentCoord = xyToGridLabel(player.position.x, player.position.y);
    console.log(`[GAME-LOG] handleMove => Player "${player.playerName}" = ${currentCoord} (orient=${player.orientation})`);

    // Envoie positionUpdate
    this.io.to(this.gameId).emit('positionUpdate', {
      playerId,
      position: player.position,
      orientation: player.orientation,
      localMapSnippet: snippet
    });

    // On ne pioche pas encore : on passe en "drawStep"
    this.io.to(this.gameId).emit('turnStateChanged', {
      turnState: 'drawStep',
      playerId,
    });
  }

  /**
   * Le joueur appelle handleDrawCard() => on pioche
   * => turnState='cardDrawn'
   */
  async handleDrawCard(playerId) {
    const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
    const players = JSON.parse(gameData.players || '[]');
    const player = players.find((p) => p.playerId === playerId);
    if (!player) {
      console.error(`handleDrawCard: Player ${playerId} not found`);
      return;
    }

    // Pioche
    const card = await this.drawCard(player);
    if (!card) {
      console.error(`handleDrawCard: No card?`);
      return;
    }

    // LOG minimal: id et name
    console.log(`[GAME-LOG] handleDrawCard => cardId=${card.card_id}, cardName=${card.card_name}`);

    // Émet: turnState='cardDrawn'
    this.io.to(this.gameId).emit('turnStateChanged', {
      turnState: 'cardDrawn',
      playerId,
      // Pour info, si vous voulez l'envoyer : cardName: card.card_name
    });
  }

  /**
   * Calcul snippet local (5 cases) selon l'orientation
   */
  getLocalMapSnippet(x, y, orientation, maze) {
    const forwardPos = (xx, yy, o) => {
      if (o === 'north') return { x: xx,     y: yy - 1 };
      if (o === 'south') return { x: xx,     y: yy + 1 };
      if (o === 'east')  return { x: xx + 1, y: yy };
      if (o === 'west')  return { x: xx - 1, y: yy };
      return { x: xx, y: yy };
    };

    const leftPos = (xx, yy, o) => {
      if (o === 'north') return { x: xx - 1, y: yy };
      if (o === 'east')  return { x: xx,     y: yy - 1 };
      if (o === 'south') return { x: xx + 1, y: yy };
      if (o === 'west')  return { x: xx,     y: yy + 1 };
      return { x: xx, y: yy };
    };

    const rightPos = (xx, yy, o) => {
      if (o === 'north') return { x: xx + 1, y: yy };
      if (o === 'east')  return { x: xx,     y: yy + 1 };
      if (o === 'south') return { x: xx - 1, y: yy };
      if (o === 'west')  return { x: xx,     y: yy - 1 };
      return { x: xx, y: yy };
    };

    const getCellValue = (xx, yy) => {
      if (yy < 0 || yy >= maze.length)    return -1;
      if (xx < 0 || xx >= maze[0].length) return -1;
      return maze[yy][xx].accessible ? 0 : 1;
    };

    const meVal = getCellValue(x, y);
    const f1 = forwardPos(x, y, orientation);
    const f1Val = getCellValue(f1.x, f1.y);
    const f2 = forwardPos(f1.x, f1.y, orientation);
    const f2Val = getCellValue(f2.x, f2.y);
    const l  = leftPos(x, y, orientation);
    const lVal = getCellValue(l.x, l.y);
    const r  = rightPos(x, y, orientation);
    const rVal = getCellValue(r.x, r.y);

    return { me: meVal, f1: f1Val, f2: f2Val, left: lVal, right: rVal };
  }

  /**
   * getValidMoves => forward, left, right
   * 'left' et 'right' signifient "pivoter puis avancer"
   */
  getValidMoves(player, maze) {
    const { x, y } = player.position;
    const orientation = player.orientation;

    const orientations = ['north', 'east', 'south', 'west'];
    const idx = orientations.indexOf(orientation);

    const offsets = {
      north: { dx: 0,  dy: -1 },
      east:  { dx: 1,  dy: 0 },
      south: { dx: 0,  dy: 1 },
      west:  { dx: -1, dy: 0 },
    };

    const isAccessible = (pos) =>
      pos.y >= 0 && pos.y < maze.length &&
      pos.x >= 0 && pos.x < maze[0].length &&
      maze[pos.y][pos.x].accessible;

    // forward
    const forward = {
      x: x + offsets[orientation].dx,
      y: y + offsets[orientation].dy,
    };

    // left => pivot + check la case "en avant" dans la nouvelle orientation
    const getTurnMove = (direction) => {
      let newIdx = idx;
      if (direction === 'left')  newIdx = (idx + 3) % 4;
      if (direction === 'right') newIdx = (idx + 1) % 4;
      const newOrientation = orientations[newIdx];
      return {
        x: x + offsets[newOrientation].dx,
        y: y + offsets[newOrientation].dy,
      };
    };

    const leftMove = getTurnMove('left');
    const rightMove= getTurnMove('right');

    return {
      canMoveForward: isAccessible(forward),
      canMoveLeft:    isAccessible(leftMove),
      canMoveRight:   isAccessible(rightMove),
    };
  }

  /**
   * processPlayerMove => applique la rotation ou l'avancée
   */
  processPlayerMove(player, move, maze) {
    const { x, y } = player.position;
    const orientation = player.orientation;

    const orientations = ['north', 'east', 'south', 'west'];
    const idx = orientations.indexOf(orientation);

    const offsets = {
      north: { dx: 0,  dy: -1 },
      east:  { dx: 1,  dy: 0 },
      south: { dx: 0,  dy: 1 },
      west:  { dx: -1, dy: 0 },
    };

    if (move === 'forward') {
      const { dx, dy } = offsets[orientation];
      const newX = x + dx;
      const newY = y + dy;
      // check accessible
      if (
        newY >= 0 && newY < maze.length &&
        newX >= 0 && newX < maze[0].length &&
        maze[newY][newX].accessible
      ) {
        player.position.x = newX;
        player.position.y = newY;
        return { success: true };
      }
      return { success: false, message: 'Chemin bloqué' };
    } else if (move === 'left' || move === 'right') {
      let newIdx = idx;
      if (move === 'left')  newIdx = (idx + 3) % 4;
      if (move === 'right') newIdx = (idx + 1) % 4;
      player.orientation = orientations[newIdx];
      return { success: true };
    }
    return { success: false, message: 'Mouvement invalide' };
  }

  /**
   * drawCard => pioche forcée ou aléatoire + appelle le handler
   * => Retourne la carte
   */
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

  /**
   * changeActivePlayer => passe au joueur suivant. 
   * Pas de pioche auto.
   */
  async changeActivePlayer() {
    const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
    if (!gameData) {
      console.error(`changeActivePlayer: no data for ${this.gameId}`);
      return;
    }

    const players = JSON.parse(gameData.players || '[]');
    const currentActiveId = gameData.activePlayerId;

    // doubleTurn ?
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
      const snippet = this.getLocalMapSnippet(samePlayer.position.x, samePlayer.position.y, samePlayer.orientation, maze);
      this.io.to(this.gameId).emit('positionUpdate', {
        playerId: samePlayer.playerId,
        position: samePlayer.position,
        orientation: samePlayer.orientation,
        localMapSnippet: snippet
      });
      return;
    }

    let idx = players.findIndex(p => p.playerId === currentActiveId);
    if (idx === -1) {
      console.error(`changeActivePlayer: currentActiveId introuvable`);
      return;
    }

    idx = (idx + 1) % players.length;
    const newActive = players[idx];
    await redisClient.hSet(`game:${this.gameId}`, 'activePlayerId', newActive.playerId);

    console.log(`TurnManager: Nouveau joueur actif => ${newActive.playerName} (ID=${newActive.playerId})`);
    this.io.to(this.gameId).emit('activePlayerChanged', {
      activePlayerId: newActive.playerId,
      activePlayerName: newActive.playerName,
      turnState: 'movement',
    });

    // Envoie snippet
    const snippet = this.getLocalMapSnippet(newActive.position.x, newActive.position.y, newActive.orientation, maze);
    this.io.to(this.gameId).emit('positionUpdate', {
      playerId: newActive.playerId,
      position: newActive.position,
      orientation: newActive.orientation,
      localMapSnippet: snippet
    });
  }
}

module.exports = TurnManager;
