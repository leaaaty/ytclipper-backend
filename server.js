import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { randomUUID } from 'crypto';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Rate limiting
app.use(rateLimit({
  windowMs: 60*60*1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false
}));

const TMP = os.tmpdir();
const API_KEY = process.env.API_KEY || '';

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], ...opts });
    let stdout = '', stderr = '';
    p.stdout.on('data', d => { stdout += d.toString(); });
    p.stderr.on('data', d => { stderr += d.toString(); });
    p.on('error', reject);
    p.on('close', code => code === 0 ? resolve({ stdout, stderr }) : reject(new Error(`${cmd} exited ${code}\n${stderr}`)));
  });
}

app.post('/download', async (req, res) => {
  try {
    if (API_KEY) {
      const key = req.headers['x-api-key'] || req.query.api_key;
      if (!key || key !== API_KEY) return res.status(401).send('Invalid API key');
    }

    const { url, format='video', range='full', start, end } = req.body;
    if (!url) return res.status(400).send('Missing url');

    const id = `${Date.now()}-${randomUUID()}`;
    const outPattern = path.join(TMP, `${id}.%(ext)s`);

    // Use standalone yt-dlp binary
    const ytdlpPath = '/usr/local/bin/yt-dlp';
    const ytdlpArgs = [
      '-f', format === 'audio' ? 'bestaudio' : 'bestvideo+bestaudio/best',
      '-o', outPattern,
      url
    ];

    console.log('Running yt-dlp with args:', ytdlpArgs.join(' '));
    try {
      await run(ytdlpPath, ytdlpArgs);
    } catch (err) {
      console.error('yt-dlp failed:', err.message);
      console.log('TMP contents after yt-dlp:', fs.readdirSync(TMP));
      return res.status(500).send(`yt-dlp failed: ${err.message}`);
    }

    const found = fs.readdirSync(TMP).find(f => f.startsWith(id));
    if (!found) return res.status(500).send('File not found — yt-dlp may have failed or video requires login');
    const downloadedPath = path.join(TMP, found);

    // ffmpeg process
    const ext = format === 'audio' ? 'mp3' : 'mp4';
    const outputFilename = `${id}_out.${ext}`;
    const outputPath = path.join(process.cwd(), 'public', outputFilename);
    if (!fs.existsSync('public')) fs.mkdirSync('public');

    const ffArgs = [];
    if (range === 'custom' && start) ffArgs.push('-ss', start);
    ffArgs.push('-i', downloadedPath);
    if (range === 'custom' && end) ffArgs.push('-to', end);

    if (format === 'audio') {
      ffArgs.push('-vn', '-acodec', 'libmp3lame', '-q:a', '2', outputPath);
    } else {
      ffArgs.push('-c', 'copy', outputPath);
    }

    await run('ffmpeg', ffArgs);
    try { fs.unlinkSync(downloadedPath); } catch {}

    const host = req.headers.host;
    const protocol = req.headers['x-forwarded-proto'] || req.protocol;
    const downloadUrl = `${protocol}://${host}/file/${outputFilename}`;

    return res.json({ downloadUrl });

  } catch (err) {
    console.error('Unexpected error in /download:', err);
    res.status(500).send(err.message || 'Processing error');
  }
});

app.use('/file', express.static(path.join(process.cwd(), 'public')));

const PORT = process.env.PORT || 3000;

app.get('/debug-env', (req, res) => {
  res.json({
    PORT: process.env.PORT,
    API_KEY: process.env.API_KEY ? "✅ set" : "❌ not set"
  });
});

app.listen(PORT, () => console.log(`Server running on ${PORT}`));