const express = require('express');
const multer = require('multer');
const { Pool } = require('pg');
const cors = require('cors');
const path = require('path');
const fs = require('fs');


const app = express();
app.use(cors());
app.use('/uploads', express.static('uploads'));


const pool = new Pool({
  user: 'adel',
  host: 'localhost',
  database: 'ekyc_db',
  password: 'seconnecter',
  port: 5432,
});



const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

const upload = multer({ storage });

// Create table if not exists
(async () => {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS verification (
        id SERIAL PRIMARY KEY,
        nom VARCHAR(255),
        prenom VARCHAR(255),
        national_id VARCHAR(255) UNIQUE,
        card_number VARCHAR(255) UNIQUE,
        birth_date DATE,
        front_id_path VARCHAR(255),
        back_id_path VARCHAR(255),
        selfie_path VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
  } finally {
    client.release();
  }
})();

    // Vérification doublon NIN

app.post('/submit-form', upload.fields([
  { name: 'frontidCard', maxCount: 1 },
  { name: 'backidCard', maxCount: 1 },
  { name: 'selfie', maxCount: 1 }
]), async (req, res) => {
  try {
    
    const { nom, prenom, nationalId, birthDate } = req.body;
    const frontIdPath = req.files.frontidCard[0].path;
    const backIdPath = req.files.backidCard[0].path;
    const selfiePath = req.files.selfie[0].path;

    const client = await pool.connect();
    const result = await client.query(
      'INSERT INTO verification (nom, prenom, national_id, birth_date, front_id_path, back_id_path, selfie_path) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *',
      [nom, prenom, nationalId, birthDate, frontIdPath, backIdPath, selfiePath]
    );
    client.release();


         //Verify NIN format
        if (!/^\d{18}$/.test(nationalId)) {
          return res.status(400).json({ error: 'Format NIN invalide' });
        }
    
        // Check for existing NIN
        const existing = await pool.query(
          'SELECT id FROM verification WHERE national_id = $1',
          [nationalId]
        );
        
        if (existing.rows.length > 0) {
          return res.status(400).json({ error: 'NIN déjà enregistré' });
        }

    res.status(201).json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: error.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});