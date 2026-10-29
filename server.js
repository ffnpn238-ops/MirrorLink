// MirrorLink relay: pairs one iPhone (/ingest) with one browser (/view) by a short-lived code.
// Frames are forwarded in memory only. Nothing is written to disk or logged.
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT) || 3000;
const page = path.join(import.meta.dirname, 'public', 'index.html');
const sessions = new Map(); // code -> { viewer, phone, expires }
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no look-alike characters

const lanAddresses = () =>
  Object.values(os.networkInterfaces()).flat()
    .filter((i) => i.family === 'IPv4' && !i.internal)
    .map((i) => `ws://${i.address}:${PORT}`);

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/api/session') {
    if (sessions.size >= 500) return res.writeHead(503).end();
    const code = Array.from({ length: 8 }, () => ALPHABET[crypto.randomInt(ALPHABET.length)]).join('');
    sessions.set(code, { viewer: null, phone: null, expires: Date.now() + 10 * 60_000 });
    // Local use: show LAN addresses. Hosted: show the public address the page was loaded from.
    const host = req.headers.host ?? '';
    const local = /^(localhost|127\.|\[::1\])/.test(host);
    const proto = req.headers['x-forwarded-proto'] === 'https' ? 'wss' : 'ws';
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify({ code, addresses: local ? lanAddresses() : [`${proto}://${host}`] }));
  }
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    return fs.createReadStream(page).pipe(res);
  }
  res.writeHead(404).end();
});

const wss = new WebSocketServer({ server, maxPayload: 8 << 20 });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://local');
  const role = url.pathname.slice(1); // "view" or "ingest"
  const s = sessions.get(url.searchParams.get('code'));
  if (!s || s.expires < Date.now() || !['view', 'ingest'].includes(role)) {
    return ws.close(4001, 'Invalid or expired code');
  }
  const slot = role === 'view' ? 'viewer' : 'phone';
  s[slot]?.close(4002, 'Replaced');
  s[slot] = ws;
  const tell = () => s.viewer?.readyState === 1 && s.viewer.send(JSON.stringify({ type: 'peers', phone: !!s.phone }));
  tell();

  ws.on('message', (data, isBinary) => {
    if (isBinary) {
      // Only the phone sends frames; drop them if the viewer is falling behind.
      if (slot === 'phone' && s.viewer?.readyState === 1 && s.viewer.bufferedAmount < 2 << 20) {
        s.viewer.send(data, { binary: true });
      }
      return;
    }
    try {
      const m = JSON.parse(data);
      if (m.type === 'ping') ws.send(JSON.stringify({ type: 'pong', t: m.t }));
    } catch { /* ignore malformed text */ }
  });
  ws.on('error', () => ws.terminate());
  ws.on('close', () => {
    if (s[slot] === ws) { s[slot] = null; tell(); }
  });
});

setInterval(() => {
  for (const [code, s] of sessions) {
    if (s.expires < Date.now()) { s.viewer?.close(); s.phone?.close(); sessions.delete(code); }
  }
}, 30_000);

server.listen(PORT, () => {
  console.log(`MirrorLink running at http://localhost:${PORT}`);
});
