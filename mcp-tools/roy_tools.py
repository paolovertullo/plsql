from mcp.server.fastmcp import FastMCP
import requests, json

mcp = FastMCP("roy-kent-tools")
N8N = "http://localhost:5678/webhook"

def _call(endpoint: str, payload: dict) -> str:
    try:
        r = requests.post(f"{N8N}/{endpoint}", json=payload, timeout=30)
        r.raise_for_status()
        return json.dumps(r.json(), ensure_ascii=False, indent=2)
    except requests.exceptions.ConnectionError:
        return f"Errore: n8n non raggiungibile su {N8N}"
    except Exception as e:
        return f"Errore: {e}"

@mcp.tool()
def health_check() -> str:
    """Verifica che n8n sia online e raggiungibile."""
    try:
        r = requests.get("http://localhost:5678/healthz", timeout=5)
        return "n8n online" if r.ok else f"n8n risponde con status {r.status_code}"
    except:
        return "n8n offline"

@mcp.tool()
def esegui_flusso(webhook_path: str, payload: dict = {}) -> str:
    """Chiama un webhook n8n generico. webhook_path es: 'polyedro-check' """
    return _call(webhook_path, payload)

# Aggiungi qui i tuoi flussi specifici man mano che li crei in n8n:

# @mcp.tool()
# def polyedro_check_cartellino(mese: str, anno: int) -> str:
#     """Verifica le giornate mancanti sul cartellino Polyedro."""
#     return _call("polyedro-check", {"mese": mese, "anno": anno})

# @mcp.tool()
# def polyedro_inserisci_presenza(data: str, causale: str = "ordinario") -> str:
#     """Inserisce una presenza su Polyedro per la data indicata (es. 2026-02-23)."""
#     return _call("polyedro-inserisci", {"data": data, "causale": causale})

if __name__ == "__main__":
    mcp.run()
