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
  { x:4, y:5 },   // E6
  { x:4, y:7 },   // E8
  { x:4, y:8 },   // E9
  { x:4, y:10 },  // E11
  { x:4, y:14 },  // E15
  { x:5, y:5 },   // F6
  { x:5, y:6 },   // F7
  { x:5, y:8 },   // F9
  { x:5, y:9 },   // F10
  { x:5, y:10 },  // F11
  { x:5, y:11 },  // F12
  { x:5, y:12 },  // F13
  { x:5, y:13 },  // F14
  { x:5, y:14 },  // F15
  { x:6, y:6 },   // G7
  { x:6, y:8 },   // G9
  { x:6, y:13 },  // G14
  { x:7, y:6 },   // H7
  { x:7, y:7 },   // H8
  { x:7, y:8 },   // H9
  { x:7, y:9 },   // H10
  { x:7, y:13 },  // H14
  { x:7, y:14 },  // H15
  { x:8, y:5 },   // I6
  { x:8, y:6 },   // I7
  { x:8, y:9 },   // I10
  { x:8, y:12 },  // I13
  { x:8, y:13 },  // I14
  { x:9, y:6 },   // J7
  { x:9, y:9 },   // J10
  { x:9, y:12 },  // J13
  { x:10, y:5 },  // K6
  { x:10, y:6 },  // K7
  { x:10, y:7 },  // K8
  { x:10, y:8 },  // K9
  { x:10, y:9 },  // K10
  { x:10, y:10 }, // K11
  { x:10, y:11 }, // K12
  { x:10, y:12 }, // K13
  { x:11, y:6 },  // L7
  { x:11, y:8 },  // L9
  { x:11, y:10 }, // L11
  { x:11, y:12 }, // L13
  { x:11, y:13 }, // L14
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


const createGame = async (req, res) => {
  const { playerName } = req.body;
  console.log(`createGame: Requête reçue pour créer une partie. playerName="${playerName}"`);
  try {
    let gameId;
    do {
      gameId = generateGameId();
    } while (await redisClient.exists(`game:${gameId}`));

    console.log(`createGame: Génération d'un nouveau gameId="${gameId}"`);

    const playerId = uuidv4();
    console.log(`createGame: Nouveau playerId="${playerId}" pour le host "${playerName}"`);

    // Position de départ aléatoire parmi le bloc central
    const startingPosition = getRandomCentralPosition();
    const startingOrientation = getRandomOrientation();

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
      maze: JSON.stringify(mapData),
    };

    await redisClient.hSet(
      `game:${gameId}`,
      'players',
      gameData.players,
      'activePlayerId',
      gameData.activePlayerId,
      'status',
      gameData.status,
      'maze',
      gameData.maze
    );

    console.log(`createGame: Partie créée avec gameId="${gameId}". Host="${playerName}" (playerId="${playerId}")`);

    res.json({ gameId, playerId });
  } catch (error) {
    console.error('createGame: Erreur lors de la création de la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la création de la partie' });
  }
};

const joinGame = async (req, res) => {
  const { gameId, playerName } = req.body;
  console.log(`joinGame: Requête reçue pour rejoindre gameId="${gameId}" avec playerName="${playerName}"`);
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    if (!gameData || !gameData.players) {
      console.error(`joinGame: Aucune partie trouvée avec gameId="${gameId}"`);
      return res.status(404).json({ error: 'Partie introuvable' });
    }

    const players = JSON.parse(gameData.players || '[]');
    const playerId = uuidv4();
    console.log(`joinGame: Nouveau playerId="${playerId}" pour le joueur "${playerName}" rejoignant la partie.`);

    const startingPosition = getRandomCentralPosition();
    const startingOrientation = getRandomOrientation();

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

    await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
    console.log(`joinGame: Joueur "${playerName}" (id="${playerId}") ajouté à la partie "${gameId}"`);

    res.json({ playerId });
  } catch (error) {
    console.error('joinGame: Erreur lors de la connexion à la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la connexion à la partie' });
  }
};

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
