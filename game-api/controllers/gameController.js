// game-api/controllers/gameController.js

const { v4: uuidv4 } = require('uuid');
const redisClient = require('../config/redis');
const mapData = require('../models/map');

function generateGameId(length = 6) {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

const centralAccessibleCoordinates = [
  { x: 4, y: 5 },
  { x: 4, y: 7 },
  { x: 4, y: 8 },
  { x: 4, y: 10 },
  { x: 4, y: 14 },
  { x: 5, y: 5 },
  { x: 5, y: 6 },
  { x: 5, y: 8 },
  { x: 5, y: 9 },
  { x: 5, y: 10 },
  { x: 5, y: 11 },
  { x: 5, y: 12 },
  { x: 5, y: 13 },
  { x: 5, y: 14 },
  { x: 6, y: 6 },
  { x: 6, y: 8 },
  { x: 6, y: 13 },
  { x: 7, y: 6 },
  { x: 7, y: 7 },
  { x: 7, y: 8 },
  { x: 7, y: 9 },
  { x: 7, y: 13 },
  { x: 7, y: 14 },
  { x: 8, y: 5 },
  { x: 8, y: 6 },
  { x: 8, y: 9 },
  { x: 8, y: 12 },
  { x: 8, y: 13 },
  { x: 9, y: 6 },
  { x: 9, y: 9 },
  { x: 9, y: 12 },
  { x: 10, y: 5 },
  { x: 10, y: 6 },
  { x: 10, y: 7 },
  { x: 10, y: 8 },
  { x: 10, y: 9 },
  { x: 10, y: 10 },
  { x: 10, y: 11 },
  { x: 10, y: 12 },
  { x: 11, y: 6 },
  { x: 11, y: 8 },
  { x: 11, y: 10 },
  { x: 11, y: 12 },
  { x: 11, y: 13 },
];

function getRandomCentralPosition() {
  const randomIndex = Math.floor(Math.random() * centralAccessibleCoordinates.length);
  return centralAccessibleCoordinates[randomIndex];
}

function getRandomOrientation() {
  const orientations = ['north', 'south', 'east', 'west'];
  const randomIndex = Math.floor(Math.random() * orientations.length);
  return orientations[randomIndex];
}

/**
 * createGame
 * - Génère un gameId unique
 * - Stocke { players, activePlayerId, status, maze } dans redis
 */
const createGame = async (req, res) => {
  const { playerName } = req.body;
  console.log(`createGame: Requête reçue pour créer une partie. playerName="${playerName}"`);

  try {
    // 1) Génération d'un gameId unique non-existant
    let gameId;
    do {
      gameId = generateGameId();
    } while (await redisClient.exists(`game:${gameId}`));
    console.log(`createGame: Génération d'un nouveau gameId="${gameId}"`);

    // 2) Générer un playerId pour le host
    const playerId = uuidv4();
    console.log(`createGame: Nouveau playerId="${playerId}" pour le host "${playerName}"`);

    // 3) Position de départ, orientation
    const startingPosition = getRandomCentralPosition();
    const startingOrientation = getRandomOrientation();

    // 4) Convertir la map en string
    const mapDataString = JSON.stringify(mapData);
    console.log(`[createGame] mapData length=${mapData.length} rows, firstRowLength=${mapData[0].length} columns`);

    // 5) Construire l'objet de la partie
    const gameData = {
      players: JSON.stringify([
        {
          playerId,
          playerName,
          ready: false,
          isHost: true,
          position: startingPosition,
          orientation: startingOrientation,
          berries: 0,
          tutorialDone: false,
          avatarBase64: '',
        },
      ]),
      activePlayerId: playerId,
      status: 'waiting',
      maze: mapDataString,
    };

    // 6) Stocker en Redis (HASH) : on insère tous les champs en une fois
    await redisClient.hSet(`game:${gameId}`, {
      players:        gameData.players,
      activePlayerId: gameData.activePlayerId,
      status:         gameData.status,
      maze:           gameData.maze,
    });

    console.log(`createGame: Partie créée avec gameId="${gameId}". Host="${playerName}" (playerId="${playerId}")`);

    // 7) Vérification : on relit la Hash
    const debugGame = await redisClient.hGetAll(`game:${gameId}`);
    if (!debugGame.maze) {
      console.error(`[createGame] Maze not found in Redis for game:${gameId}!`);
    } else {
      console.log(`[createGame] Maze found in Redis => length=${debugGame.maze.length} chars`);
    }

    // 8) Réponse
    res.json({ gameId, playerId });
  } catch (error) {
    console.error('createGame: Erreur lors de la création de la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la création de la partie' });
  }
};

/**
 * joinGame
 * - Ajoute un nouveau joueur dans `players`
 * - N'écrase pas le champ 'maze' => on modifie seulement 'players'
 */
const joinGame = async (req, res) => {
  const { gameId, playerName } = req.body;
  console.log(`joinGame: Requête reçue pour rejoindre gameId="${gameId}" avec playerName="${playerName}"`);
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    if (!gameData || !gameData.players) {
      console.error(`joinGame: Aucune partie trouvée avec gameId="${gameId}"`);
      return res.status(404).json({ error: 'Partie introuvable' });
    }

    // Récupérer players
    const players = JSON.parse(gameData.players || '[]');

    // Générer un nouvel ID
    const playerId = uuidv4();
    console.log(`joinGame: Nouveau playerId="${playerId}" pour le joueur "${playerName}" rejoignant la partie.`);

    // Position random
    const startingPosition = getRandomCentralPosition();
    const startingOrientation = getRandomOrientation();

    // Pousser dans le tableau
    players.push({
      playerId,
      playerName,
      ready: false,
      isHost: false,
      position: startingPosition,
      orientation: startingOrientation,
      berries: 0,
      tutorialDone: false,
      avatarBase64: '',
    });

    // Stocker le nouveau players (et on NE TOUCHE PAS aux autres champs)
    await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
    console.log(`joinGame: Joueur "${playerName}" (id="${playerId}") ajouté à la partie "${gameId}"`);

    res.json({ playerId });
  } catch (error) {
    console.error('joinGame: Erreur lors de la connexion à la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la connexion à la partie' });
  }
};

/**
 * getActivePlayer
 */
const getActivePlayer = async (req, res) => {
  const { gameId } = req.params;
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    res.json({ activePlayerId: gameData.activePlayerId });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
};

module.exports = {
  createGame,
  joinGame,
  getActivePlayer,
};
