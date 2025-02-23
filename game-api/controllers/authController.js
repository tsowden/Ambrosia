// controllers/authController.js

const db = require('../config/db');           // ta config MySQL
const jwt = require('jsonwebtoken');          // pour générer des tokens
const bcrypt = require('bcrypt');             // pour hacher / comparer les mots de passe
const SECRET_KEY = process.env.JWT_SECRET || 'votre_cle_secrete_jwt';

// ---------------------------
// 1) REGISTER
// ---------------------------
exports.register = async (req, res) => {
  try {
    const { email, pseudo, password, avatarBase64 } = req.body;

    // Vérifier si l'email est déjà pris
    const [rowsEmail] = await db.query('SELECT id FROM users WHERE email=?', [email]);
    if (rowsEmail.length > 0) {
      return res.status(400).json({ error: 'Cet email est déjà utilisé.' });
    }

    // Vérifier si le pseudo est déjà pris
    const [rowsPseudo] = await db.query('SELECT id FROM users WHERE pseudo=?', [pseudo]);
    if (rowsPseudo.length > 0) {
      return res.status(400).json({ error: 'Ce pseudo est déjà utilisé.' });
    }

    // Hachage du mot de passe
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Insertion BDD
    const [result] = await db.query(
      `INSERT INTO users (email, pseudo, password, avatarBase64) VALUES (?, ?, ?, ?)`,
      [email, pseudo, hashedPassword, avatarBase64 || '']
    );

    const insertedId = result.insertId;

    // Génération du token
    const token = jwt.sign({ userId: insertedId }, SECRET_KEY, { expiresIn: '7d' });

    return res.json({
      message: 'Inscription réussie',
      token,
      user: {
        id: insertedId,
        email,
        pseudo,
        avatarBase64: avatarBase64 || ''
      }
    });
  } catch (err) {
    console.error('register error:', err);
    return res.status(500).json({ error: 'Erreur serveur (register)' });
  }
};

// ---------------------------
// 2) LOGIN
// ---------------------------
exports.login = async (req, res) => {
  try {
    const { pseudo, password } = req.body;

    // On cherche par pseudo
    const [rows] = await db.query('SELECT * FROM users WHERE pseudo=?', [pseudo]);
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Pseudo ou mot de passe incorrect.' });
    }

    const user = rows[0];
    // Vérifie le mdp
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Pseudo ou mot de passe incorrect.' });
    }

    // Génération du token
    const token = jwt.sign({ userId: user.id }, SECRET_KEY, { expiresIn: '7d' });

    return res.json({
      message: 'Connexion réussie',
      token,
      user: {
        id: user.id,
        pseudo: user.pseudo,
        email: user.email,
        avatarBase64: user.avatarBase64 || ''
      }
    });
  } catch (err) {
    console.error('login error:', err);
    return res.status(500).json({ error: 'Erreur serveur (login)' });
  }
};

// ---------------------------
// 3) GET PROFILE
// ---------------------------
exports.getProfile = async (req, res) => {
  try {
    const userId = req.userId;
    const [rows] = await db.query(
      'SELECT id, email, pseudo, avatarBase64, createdAt FROM users WHERE id=?',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }

    const user = rows[0];
    return res.json({
      id: user.id,
      email: user.email,
      pseudo: user.pseudo,
      avatarBase64: user.avatarBase64 || '',
      createdAt: user.createdAt
    });
  } catch (err) {
    console.error('getProfile error:', err);
    return res.status(500).json({ error: 'Erreur serveur (getProfile)' });
  }
};

// ---------------------------
// 4) UPDATE PROFILE
// ---------------------------
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.userId;
    const { newPseudo, newAvatarBase64 } = req.body;

    if (newPseudo) {
      const [rowsCheck] = await db.query('SELECT id FROM users WHERE pseudo=? AND id<>?', [newPseudo, userId]);
      if (rowsCheck.length > 0) {
        return res.status(400).json({ error: 'Ce pseudo est déjà utilisé.' });
      }
    }

    await db.query(
      `UPDATE users SET pseudo=?, avatarBase64=? WHERE id=?`,
      [newPseudo, newAvatarBase64, userId]
    );

    return res.json({ message: 'Profil mis à jour avec succès' });
  } catch (err) {
    console.error('updateProfile error:', err);
    return res.status(500).json({ error: 'Erreur serveur (updateProfile)' });
  }
};

// ---------------------------
// 5) DELETE ACCOUNT
// ---------------------------
exports.deleteAccount = async (req, res) => {
  try {
    const userId = req.userId;
    await db.query('DELETE FROM users WHERE id=?', [userId]);
    return res.json({ message: 'Compte supprimé avec succès' });
  } catch (err) {
    console.error('deleteAccount error:', err);
    return res.status(500).json({ error: 'Erreur serveur (deleteAccount)' });
  }
};
