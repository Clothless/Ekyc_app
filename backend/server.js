const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const baseUrl = 'http://localhost:5000';

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'ekyc',
  password: 'adel2003',
  port: 5432,
});

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ limit: '10mb', extended: true }));

const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}
app.use('/uploads', express.static(uploadDir));

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + '-' + file.originalname);
  },
});
const upload = multer({ storage });

app.post('/save-id-card', upload.fields([
  { name: 'idCardFront', maxCount: 1 },
  { name: 'idCardFace', maxCount: 1 },
  { name: 'selfie', maxCount: 1 },
]), async (req, res) => {
  try {
    const { identity_number, card_number, expiryDate, birthdate, family_name, given_name, document_type } = req.body;

    const formatDate = (dateString) => {
      if (!dateString) return null;
      const parts = dateString.split('.');
      if (parts.length === 3) return `${parts[2]}-${parts[1]}-${parts[0]}`;
      return null;
    };

    const formattedBirthdate = formatDate(birthdate);
    const formattedExpiryDate = formatDate(expiryDate);

    const frontImageUrl = req.files['idCardFront'] ? `${baseUrl}/uploads/${req.files['idCardFront'][0].filename}` : null;
    const idCardFaceUrl = req.files['idCardFace'] ? `${baseUrl}/uploads/${req.files['idCardFace'][0].filename}` : null;
    const selfieUrl = req.files['selfie'] ? `${baseUrl}/uploads/${req.files['selfie'][0].filename}` : null;

    const checkResult = await pool.query(
      `SELECT * FROM id_cards WHERE identity_number = $1 AND document_type = $2`,
      [identity_number, document_type]
    );

    if (checkResult.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `The identity number already exists for document type: ${document_type}`,
      });
    }

    const result = await pool.query(
      `INSERT INTO id_cards (
        identity_number, card_number, expiry_date, birthdate, family_name, given_name,
        front_image_url, front_face_url, selfie_face_url, document_type
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [
        identity_number,
        card_number,
        formattedExpiryDate,
        formattedBirthdate,
        family_name,
        given_name,
        frontImageUrl,
        idCardFaceUrl,
        selfieUrl,
        document_type,
      ]
    );

    res.json({
      success: true,
      message: '✅ ID Card saved successfully!',
      data: result.rows[0],
    });

  } catch (error) {
    console.error('❌ Database Error:', error);
    res.status(500).json({ success: false, message: 'Server error occurred.', error: error.message });
  }
});

app.listen(5000, () => {
  console.log('🚀 Server running on http://localhost:5000');
});