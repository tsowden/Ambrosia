// routes/authRoutes.js
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middlewares/auth');

// Inscription
router.post('/register', authController.register);

// Connexion
router.post('/login', authController.login);

// Profil (protégé)
router.get('/profile', authMiddleware, authController.getProfile);

// Modifier profil
router.put('/profile', authMiddleware, authController.updateProfile);

// Supprimer compte
router.delete('/profile', authMiddleware, authController.deleteAccount);

module.exports = router;
