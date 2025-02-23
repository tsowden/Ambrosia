const express = require('express');
const router = express.Router();
const redisClient = require('../config/redis');
const { createGame, joinGame, getActivePlayer } = require('../controllers/gameController');

router.post('/create-game', createGame);

router.post('/join-game', joinGame);

router.get('/active-player/:gameId', getActivePlayer);

module.exports = router;
