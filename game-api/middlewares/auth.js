// middlewares/auth.js
const jwt = require('jsonwebtoken');
const SECRET_KEY = process.env.JWT_SECRET || 'votre_cle_secrete_jwt';

module.exports = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ error: 'Accès non autorisé, token manquant' });
  }

  const token = authHeader.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Accès non autorisé, token invalide' });
  }

  try {
    const decoded = jwt.verify(token, SECRET_KEY);
    // On stocke l’id user dans req
    req.userId = decoded.userId;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Token invalide ou expiré' });
  }
};
