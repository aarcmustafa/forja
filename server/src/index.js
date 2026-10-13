const express = require('express');
const cors = require('cors');

const config = require('./config');
const playlistsRouter = require('./routes/playlists');
const m3uRouter = require('./routes/m3u');

const app = express();

// ==========================================================
//  Middleware
// ==========================================================
app.use(cors());
app.use(express.json());

// Logger بسيط
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - start;
    console.log(`${req.method} ${req.path} → ${res.statusCode} (${ms}ms)`);
  });
  next();
});

// ==========================================================
//  Routes
// ==========================================================
app.get('/', (req, res) => {
  res.json({
    name: 'Estetn Farja Server',
    version: '1.0.0',
    status: 'running',
    playlists: config.playlists.length,
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.use('/api/playlists', playlistsRouter);
app.use('/api/m3u', m3uRouter);

// 404
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'المسار غير موجود',
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('خطأ:', err);
  res.status(500).json({
    success: false,
    error: 'خطأ في الخادم',
  });
});

// ==========================================================
//  Start
// ==========================================================
const PORT = config.port;
app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('═══════════════════════════════════════');
  console.log('  🎬 Estetn Farja Server');
  console.log('═══════════════════════════════════════');
  console.log(`  ✓ Port: ${PORT}`);
  console.log(`  ✓ Playlists loaded: ${config.playlists.length}`);
  console.log(`  ✓ Ready: http://localhost:${PORT}`);
  console.log('═══════════════════════════════════════');
  console.log('');
});
