const express = require('express');
const config = require('../config');

const router = express.Router();

/**
 * GET /api/playlists
 * يُرجع قائمة الباقات المتاحة (بدون روابط حقيقية)
 */
router.get('/', (req, res) => {
  const playlists = config.playlists.map((p) => ({
    id: p.index,
    name: `Playlist ${p.index}`,
    // الرابط الوهمي — يشير إلى خادمك
    apiPath: `/api/m3u/${p.index}`,
  }));

  res.json({
    success: true,
    count: playlists.length,
    playlists,
  });
});

module.exports = router;
