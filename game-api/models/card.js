// models/card.js
const db = require('../config/db'); 


// async function getRandomCard() {
//   try {
//     const [rows] = await db.query('SELECT * FROM cards ORDER BY RAND() LIMIT 1');

//     if (!rows || rows.length === 0) {
//       return null;
//     }
//     return rows[0];
//   } catch (error) {
//     console.error('Erreur lors de la récupération de la carte:', error);
//     throw error; 
//   }
// }

const DEBUG_CARD_IDS = [2, 3, 4, 10, 11, 12]; // IDs pour le debug, par exemple

async function getRandomCard() {
  try {
    let query = 'SELECT * FROM cards ORDER BY RAND() LIMIT 1';
    let params = [];
    if (DEBUG_CARD_IDS.length > 0) {
      query = `SELECT * FROM cards WHERE card_id IN (${DEBUG_CARD_IDS.map(() => '?').join(', ')}) ORDER BY RAND() LIMIT 1`;
      params = DEBUG_CARD_IDS;
    }
    const [rows] = await db.query(query, params);
    if (!rows || rows.length === 0) {
      return null;
    }
    return rows[0];
  } catch (error) {
    console.error('Erreur lors de la récupération de la carte:', error);
    throw error;
  }
}

async function getCardById(cardId) {
  try {
    const query = 'SELECT * FROM cards WHERE card_id = ? LIMIT 1';
    const [rows] = await db.query(query, [cardId]);
    if (!rows || rows.length === 0) {
      return null;
    }
    return rows[0];
  } catch (error) {
    console.error('Erreur lors de la récupération de la carte par ID:', error);
    throw error;
  }
}

module.exports = { getRandomCard, getCardById };

