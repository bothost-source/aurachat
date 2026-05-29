const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ message: 'Moderation route working' });
});

module.exports = router;
