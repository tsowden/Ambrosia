const mysql = require('mysql2/promise');

const db = mysql.createPool({
  host: process.env.MYSQL_HOST,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE
});

console.log('Connecté à MySQL2/promise');

module.exports = db;
