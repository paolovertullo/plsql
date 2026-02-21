from mcp.server.fastmcp import FastMCP
import requests, json

mcp = FastMCP('roy-kent-tools')
N8N = 'http://localhost:5678/webhook'

def _call(endpoint, payload):
    try:
        r = requests.post(f'{N8N}/{endpoint}', json=payload, timeout=30)
        return json.dumps(r.json(), ensure_ascii=False, indent=2)
    except Exception as e:
        return f'Errore: {e}'

# @mcp.tool()
# def estrai_dati_oracle(periodo: str) -> str:
#     """Estrae dati da Oracle per il periodo indicato"""
#     return _call('oracle-extract', {'periodo': periodo})

if __name__ == '__main__':
    mcp.run()
