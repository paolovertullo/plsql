from github import Github, GithubException
import os

REPO_NAME       = "paolovertullo/plsql"
NEW_DESCRIPTION = "Roy Kent — AI Operations Center · MCP + n8n + Aider"

FILES = {
"README.md": "# Roy Kent — AI Operations Center\n\nInfrastruttura AI locale: Roy Kent (LM Studio) + MCP custom + n8n + Aider + Dashboard\n\n## Cartelle\n\n| Cartella | Contenuto |\n|---|---|\n| `dashboard/` | HTML monitoring dashboard |\n| `mcp-tools/` | MCP custom Python |\n| `n8n-workflows/` | Export JSON flussi n8n |\n| `system-prompt/` | System prompt Roy e versioni |\n| `aider/` | Config Aider |\n| `docs/` | Architettura e roadmap |\n",
"dashboard/README.md": "# Dashboard\n\nFile HTML standalone — apri nel browser.\n",
"mcp-tools/roy_tools.py": "from mcp.server.fastmcp import FastMCP\nimport requests, json\n\nmcp = FastMCP('roy-kent-tools')\nN8N = 'http://localhost:5678/webhook'\n\ndef _call(endpoint, payload):\n    try:\n        r = requests.post(f'{N8N}/{endpoint}', json=payload, timeout=30)\n        return json.dumps(r.json(), ensure_ascii=False, indent=2)\n    except Exception as e:\n        return f'Errore: {e}'\n\n# @mcp.tool()\n# def estrai_dati_oracle(periodo: str) -> str:\n#     \"\"\"Estrae dati da Oracle per il periodo indicato\"\"\"\n#     return _call('oracle-extract', {'periodo': periodo})\n\nif __name__ == '__main__':\n    mcp.run()\n",
"mcp-tools/requirements.txt": "mcp[cli]>=1.0.0\nrequests>=2.31.0\n",
"mcp-tools/README.md": "# MCP Tools\n\nUn server, tutti i tool dentro.\nAggiungi un @mcp.tool() per ogni nuovo flusso n8n.\n",
"n8n-workflows/README.md": "# n8n Workflows\n\nExport JSON dei flussi n8n.\nEsporta da n8n → menu ⋯ → Export → salva qui → commit.\n\n| File | Tool MCP | Stato |\n|---|---|---|\n| *(nessuno ancora)* | | |\n",
"system-prompt/system-prompt-current.txt": "Sei Roy Kent — diretto, preciso, niente fronzoli.\n\nSTILE: conciso, tecnico quando serve, segnala anomalie.\n\nINFRASTRUTTURA:\n— n8n: localhost:5678\n— LM Studio: localhost:1234\n\nTOOL MCP: (aggiorna quando aggiungi tool)\n",
"system-prompt/README.md": "# System Prompt\n\n`system-prompt-current.txt` — copia in LM Studio → Model Settings → System Prompt\n\nOgni nuovo tool MCP = aggiorna il prompt + salva versione precedente come `system-prompt-YYYY-MM-DD.txt`\n",
"aider/README.md": "# Aider\n\n```bash\npip install aider-chat\naider --openai-api-base http://localhost:1234/v1 --openai-api-key fake --model openai/qwen2.5-14b\n```\n\nLavora sempre su branch dedicato, mai su main.\n",
"docs/architettura.md": "# Architettura\n\nTu → Roy (LM Studio) → MCP custom Python → webhook n8n → sistemi esterni\n\nMCP ufficiali (GitHub, Gmail) per accesso diretto semplice.\nMCP custom per bridge verso i tuoi flussi n8n.\n",
"docs/roadmap.md": "# Roadmap\n\n## Fase 1 (ora)\n- [ ] n8n in locale\n- [ ] Primi flussi n8n\n- [ ] MCP custom funzionante\n- [ ] GitHub + Filesystem MCP\n\n## Fase 2 (1-3 mesi)\n- [ ] Gmail MCP\n- [ ] Aider sul progetto Android\n- [ ] Roy salva su GitHub autonomamente\n\n## Fase 3 (6+ mesi)\n- [ ] Roy supervisiona Aider\n- [ ] Loop semi-autonomo\n",
}

def main():
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        raise ValueError("GITHUB_TOKEN non trovato")
    g    = Github(token)
    repo = g.get_repo(REPO_NAME)
    repo.edit(description=NEW_DESCRIPTION)
    print("✓ Descrizione aggiornata")
    for path, content in FILES.items():
        try:
            existing = repo.get_contents(path)
            repo.update_file(path, f"setup: update {path}", content, existing.sha)
            print(f"↺ {path}")
        except GithubException:
            repo.create_file(path, f"setup: create {path}", content)
            print(f"+ {path}")
    print("\n✅ Done — https://github.com/paolovertullo/plsql")

if __name__ == "__main__":
    main()
