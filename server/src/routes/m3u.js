const express = require('express');
const axios = require('axios');
const config = require('../config');
const SimpleCache = require('../utils/cache');

const router = express.Router();
const cache = new SimpleCache(30 * 60 * 1000); // 30 دقيقة

/**
 * GET /api/m3u/:id
 * يجلب محتوى M3U من الرابط الحقيقي ويعيده (بدون كشف الرابط)
 */
router.get('/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);

  if (isNaN(id) || id < 1) {
    return res.status(400).json({
      success: false,
      error: 'رقم الباقة غير صالح',
    });
  }

  // البحث عن الرابط الحقيقي
  const playlist = config.playlists.find((p) => p.index === id);
  if (!playlist) {
    return res.status(404).json({
      success: false,
      error: 'الباقة غير موجودة',
    });
  }

  // التحقق من الذاكرة المؤقتة
  const cacheKey = `m3u_${id}`;
  const cached = cache.get(cacheKey);
  if (cached) {
    res.setHeader('X-Cache', 'HIT');
    res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
    return res.send(cached);
  }

  try {
    const response = await axios.get(playlist.url, {
      timeout: config.fetchTimeout,
      responseType: 'text',
      headers: {
        'User-Agent': config.userAgent,
        Accept: '*/*',
      },
      maxContentLength: 100 * 1024 * 1024, // 100MB
    });

    const content = response.data;

    // حفظ في الذاكرة
    cache.set(cacheKey, content);

    res.setHeader('X-Cache', 'MISS');
    res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
    res.setHeader('Cache-Control', 'public, max-age=1800');
    res.send(content);
  } catch (err) {
    console.error(`فشل جلب الباقة ${id}:`, err.message);
    res.status(500).json({
      success: false,
      error: 'فشل جلب الباقة من المصدر',
    });
  }
});

/**
 * GET /api/m3u/:id/info
 * يُرجع معلومات عن الباقة (عدد القنوات مثلاً)
 */
router.get('/:id/info', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id) || id < 1) {
    return res.status(400).json({ success: false });
  }

  const playlist = config.playlists.find((p) => p.index === id);
  if (!playlist) {
    return res.status(404).json({ success: false });
  }

  res.json({
    success: true,
    id,
    cached: cache.has(`m3u_${id}`),
  });
});

module.exports = router;
