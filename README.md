# Agent-Roy

AI agent locale basato su LM Studio con tool GitHub, dashboard web e proxy MCP.

## Struttura

```
Agent-Roy/
├── dashboard/
│   └── roy_kent_dashboard.html   # UI web
├── proxy/
│   ├── proxy.js                  # Bridge Dashboard → LM Studio + tool GitHub
│   ├── package.json
│   ├── .env.example
│   └── start.bat                 # Avvio rapido Windows
├── mcp-tools/
│   └── roy_tools.py              # MCP server Python per LM Studio
└── README.md
```

## Avvio rapido

### 1. Prerequisiti
- Node.js 18+
- LM Studio avviato con un modello caricato e server locale attivo su `:1234`
- Token GitHub con permessi `repo`

### 2. Configura il proxy
```bash
cd proxy
cp .env.example .env
# Edita .env e metti il tuo GITHUB_TOKEN
npm install
```

### 3. Avvia tutto
```bash
# Avvia il proxy (dalla cartella proxy/)
node proxy.js

# Servi il dashboard (dalla cartella dashboard/)
python -m http.server 8080

# Apri nel browser
# http://localhost:8080/roy_kent_dashboard.html
```

Oppure su Windows usa `proxy/start.bat`.

### 4. Tool disponibili (via proxy → GitHub API)

| Tool | Descrizione |
|------|-------------|
| `github_list_repos` | Lista repo di un utente |
| `github_get_repo` | Dettagli di un repo |
| `github_list_issues` | Issue aperte/chiuse |
| `github_create_issue` | Crea una issue |
| `github_list_prs` | Pull request |
| `github_get_file` | Legge un file dal repo |
| `github_push_file` | Crea/aggiorna un file |
| `github_list_commits` | Commit recenti |
| `github_search_code` | Cerca codice |
| `n8n_health` | Verifica se n8n è online |

## Architettura

```
Browser (dashboard HTML)
    ↓ POST /chat
Roy Kent Proxy (localhost:3333)
    ↓ /v1/chat/completions
LM Studio (localhost:1234)
    ↑ tool_calls → esegue via Octokit
GitHub API
```
