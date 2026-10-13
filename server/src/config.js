require('dotenv').config();

/**
 * تحميل الروابط الحقيقية من متغيرات البيئة
 */
function loadPlaylists() {
  const playlists = [];

  // تحميل PLAYLIST_1 → PLAYLIST_50
  for (let i = 1; i <= 50; i++) {
    const url = process.env[`PLAYLIST_${i}`];
    if (url && url.trim()) {
      playlists.push({
        index: i,
        url: url.trim(),
      });
    }
  }

  return playlists;
}

module.exports = {
  port: parseInt(process.env.PORT || '3000', 10),
  apiSecret: process.env.API_SECRET || '',
  playlists: loadPlaylists(),

  // إعدادات الجلب
  fetchTimeout: 90000, // 90 ثانية
  userAgent:
    'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36',
};
