/**
 * Roy Kent · MCP Proxy
 * Dashboard → questo proxy → LM Studio API
 * Gestisce il loop tool_calls: intercetta, esegue via @modelcontextprotocol/server-github, reinvia
 */

import express from 'express';
import cors from 'cors';
import fetch from 'node-fetch';
import { Octokit } from '@octokit/rest';

const app = express();
app.use(cors());
app.use(express.json());

const LM_URL   = process.env.LM_URL   || 'http://localhost:1234/v1';
const GH_TOKEN = process.env.GITHUB_TOKEN || '';
const PORT     = process.env.PORT     || 3333;

const octokit = new Octokit({ auth: GH_TOKEN });

// ─── Tool definitions (passate al modello) ───────────────────────────────────
const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'github_list_repos',
      description: 'Lista i repository GitHub di un utente o organizzazione',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string', description: 'Username o org GitHub' }
        },
        required: ['owner']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_get_repo',
      description: 'Dettagli di un repository GitHub',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string' },
          repo:  { type: 'string' }
        },
        required: ['owner', 'repo']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_list_issues',
      description: 'Lista le issue aperte di un repository',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string' },
          repo:  { type: 'string' },
          state: { type: 'string', enum: ['open','closed','all'], default: 'open' }
        },
        required: ['owner', 'repo']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_create_issue',
      description: 'Crea una nuova issue in un repository',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string' },
          repo:  { type: 'string' },
          title: { type: 'string' },
          body:  { type: 'string' }
        },
        required: ['owner', 'repo', 'title']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_list_prs',
      description: 'Lista le pull request di un repository',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string' },
          repo:  { type: 'string' },
          state: { type: 'string', enum: ['open','closed','all'], default: 'open' }
        },
        required: ['owner', 'repo']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_get_file',
      description: 'Legge il contenuto di un file da un repository GitHub',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string' },
          repo:  { type: 'string' },
          path:  { type: 'string', description: 'Percorso del file nel repo, es. README.md' },
          ref:   { type: 'string', description: 'Branch o commit SHA, default main' }
        },
        required: ['owner', 'repo', 'path']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_push_file',
      description: 'Crea o aggiorna un file in un repository GitHub',
      parameters: {
        type: 'object',
        properties: {
          owner:   { type: 'string' },
          repo:    { type: 'string' },
          path:    { type: 'string' },
          content: { type: 'string', description: 'Contenuto del file (testo)' },
          message: { type: 'string', description: 'Commit message' },
          branch:  { type: 'string', description: 'Branch, default main' }
        },
        required: ['owner', 'repo', 'path', 'content', 'message']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_list_commits',
      description: 'Lista i commit recenti di un repository',
      parameters: {
        type: 'object',
        properties: {
          owner: { type: 'string' },
          repo:  { type: 'string' },
          per_page: { type: 'number', description: 'Quanti commit, max 30', default: 10 }
        },
        required: ['owner', 'repo']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'github_search_code',
      description: 'Cerca codice nei repository GitHub',
      parameters: {
        type: 'object',
        properties: {
          q: { type: 'string', description: 'Query di ricerca GitHub, es. "filename:README repo:owner/repo"' }
        },
        required: ['q']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'n8n_health',
      description: 'Verifica se n8n è online su localhost:5678',
      parameters: { type: 'object', properties: {} }
    }
  }
];

// ─── Esecutori tool ───────────────────────────────────────────────────────────
async function executeTool(name, args) {
  try {
    switch(name) {

      case 'github_list_repos': {
        const { data } = await octokit.repos.listForUser({ username: args.owner, per_page: 20 });
        return data.map(r => ({ name: r.name, private: r.private, stars: r.stargazers_count, updated: r.updated_at }));
      }

      case 'github_get_repo': {
        const { data } = await octokit.repos.get({ owner: args.owner, repo: args.repo });
        return { name: data.name, description: data.description, stars: data.stargazers_count,
                 language: data.language, default_branch: data.default_branch, open_issues: data.open_issues_count };
      }

      case 'github_list_issues': {
        const { data } = await octokit.issues.listForRepo({ owner: args.owner, repo: args.repo, state: args.state || 'open', per_page: 20 });
        return data.map(i => ({ number: i.number, title: i.title, state: i.state, created_at: i.created_at }));
      }

      case 'github_create_issue': {
        const { data } = await octokit.issues.create({ owner: args.owner, repo: args.repo, title: args.title, body: args.body || '' });
        return { number: data.number, url: data.html_url, title: data.title };
      }

      case 'github_list_prs': {
        const { data } = await octokit.pulls.list({ owner: args.owner, repo: args.repo, state: args.state || 'open', per_page: 20 });
        return data.map(p => ({ number: p.number, title: p.title, state: p.state, created_at: p.created_at }));
      }

      case 'github_get_file': {
        const { data } = await octokit.repos.getContent({ owner: args.owner, repo: args.repo, path: args.path, ref: args.ref || 'main' });
        const content = Buffer.from(data.content, 'base64').toString('utf8');
        return { path: data.path, sha: data.sha, content: content.slice(0, 8000) }; // tronca per non esplodere il ctx
      }

      case 'github_push_file': {
        // Recupera SHA se il file esiste già
        let sha;
        try {
          const { data } = await octokit.repos.getContent({ owner: args.owner, repo: args.repo, path: args.path, ref: args.branch || 'main' });
          sha = data.sha;
        } catch(e) { /* file nuovo */ }
        const { data } = await octokit.repos.createOrUpdateFileContents({
          owner: args.owner, repo: args.repo, path: args.path,
          message: args.message,
          content: Buffer.from(args.content).toString('base64'),
          branch: args.branch || 'main',
          ...(sha ? { sha } : {})
        });
        return { commit: data.commit.sha, url: data.content.html_url };
      }

      case 'github_list_commits': {
        const { data } = await octokit.repos.listCommits({ owner: args.owner, repo: args.repo, per_page: args.per_page || 10 });
        return data.map(c => ({ sha: c.sha.slice(0,7), message: c.commit.message.split('\n')[0], date: c.commit.author.date, author: c.commit.author.name }));
      }

      case 'github_search_code': {
        const { data } = await octokit.search.code({ q: args.q, per_page: 10 });
        return data.items.map(i => ({ name: i.name, path: i.path, repo: i.repository.full_name, url: i.html_url }));
      }

      case 'n8n_health': {
        try {
          const r = await fetch('http://localhost:5678/healthz', { signal: AbortSignal.timeout(4000) });
          return { status: r.ok ? 'online' : 'error', code: r.status };
        } catch(e) {
          return { status: 'offline', error: e.message };
        }
      }

      default:
        return { error: `Tool "${name}" non implementato` };
    }
  } catch(e) {
    return { error: e.message };
  }
}

// ─── Loop tool_calls ─────────────────────────────────────────────────────────
async function chatWithTools(messages, model, temperature, max_tokens) {
  const msgs = [...messages];
  const callLog = []; // log per il dashboard

  for(let round = 0; round < 8; round++) { // max 8 round di tool use
    const body = { model, messages: msgs, tools: TOOLS, tool_choice: 'auto', temperature, max_tokens, stream: false };
    const res = await fetch(`${LM_URL}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if(!res.ok) throw new Error(`LM Studio error ${res.status}`);
    const data = await res.json();
    const choice = data.choices[0];
    const msg = choice.message;
    msgs.push(msg);

    // Nessun tool call → risposta finale
    if(!msg.tool_calls || msg.tool_calls.length === 0) {
      return { content: msg.content, tool_calls_log: callLog, usage: data.usage };
    }

    // Esegui tutti i tool call in parallelo
    await Promise.all(msg.tool_calls.map(async tc => {
      const args = JSON.parse(tc.function.arguments || '{}');
      console.log(`[tool] ${tc.function.name}`, args);
      const result = await executeTool(tc.function.name, args);
      callLog.push({ name: tc.function.name, args, result, ts: new Date().toISOString() });
      msgs.push({
        role: 'tool',
        tool_call_id: tc.id,
        content: JSON.stringify(result)
      });
    }));
  }
  return { content: 'Errore: troppi round di tool use', tool_calls_log: callLog };
}

// ─── Route principale ─────────────────────────────────────────────────────────
app.post('/chat', async (req, res) => {
  const { messages, model = 'local-model', temperature = 0.7, max_tokens = 2048 } = req.body;
  try {
    const result = await chatWithTools(messages, model, temperature, max_tokens);
    res.json(result);
  } catch(e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

// Health check proxy stesso
app.get('/health', (_, res) => res.json({ status: 'ok', lm_url: LM_URL }));

// Lista modelli (forwarda a LM Studio)
app.get('/models', async (_, res) => {
  try {
    const r = await fetch(`${LM_URL}/models`);
    res.json(await r.json());
  } catch(e) { res.status(500).json({ error: e.message }); }
});

app.listen(PORT, () => console.log(`Roy Kent Proxy · http://localhost:${PORT}`));
