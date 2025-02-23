require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const redisClient = require('./config/redis');
const handleSocketEvents = require('./sockets/socketHandlers');
const gameRoutes = require('./routes/gameRoutes');
const authRoutes = require('./routes/authRoutes');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use(cors());

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*', 
    methods: ['GET', 'POST'],
  },
});

app.use((req, res, next) => {
  req.io = io;
  next();
});

app.use((req, res, next) => {
  console.log(`Requête ${req.method} reçue sur ${req.url}`);
  next();
});

app.use('/api/game', gameRoutes);
app.use('/api/auth', authRoutes);

io.on('connection', (socket) => {
  console.log('Backend: Un joueur s\'est connecté');
  handleSocketEvents(io, socket);

  socket.on('disconnect', () => {
    console.log('Backend: Un joueur s\'est déconnecté');
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Backend: Serveur accessible sur toutes les interfaces, port ${port}`);
});

