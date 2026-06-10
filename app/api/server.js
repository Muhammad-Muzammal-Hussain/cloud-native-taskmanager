// server.js - Task Manager REST API
const express = require('express');
const { pool, initSchema } = require('./db');

const app = express();
const port = parseInt(process.env.PORT || '3000', 10);
app.use(express.json());

let dbReady = false;

// --- Health & readiness probes (used by Kubernetes) ---------------------
// liveness: the process is up
app.get('/api/healthz', (req, res) => res.json({ status: 'ok' }));
// readiness: the DB is reachable (don't send traffic until true)
app.get('/api/readyz', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ready' });
  } catch (e) {
    res.status(503).json({ status: 'not-ready', error: e.message });
  }
});

// --- Task CRUD ----------------------------------------------------------
app.get('/api/tasks', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/tasks', async (req, res) => {
  const title = (req.body.title || '').trim();
  if (!title) return res.status(400).json({ error: 'title is required' });
  try {
    const { rows } = await pool.query(
      'INSERT INTO tasks (title) VALUES ($1) RETURNING *', [title]);
    res.status(201).json(rows[0]);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/tasks/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'UPDATE tasks SET done = NOT done WHERE id = $1 RETURNING *',
      [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM tasks WHERE id = $1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'not found' });
    res.status(204).end();
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// --- Startup with DB retry (DB pod may come up after the API pod) -------
async function start() {
  for (let attempt = 1; attempt <= 30; attempt++) {
    try {
      await initSchema();
      dbReady = true;
      console.log('Database schema ready.');
      break;
    } catch (e) {
      console.log(`DB not ready (attempt ${attempt}/30): ${e.message}`);
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  app.listen(port, () => console.log(`Task API listening on :${port}`));
}

start();
