-- ============================================================================
-- Creazione SYNONYM per accesso tabelle UNIRE_REL2 da PVERTULLO
-- Eseguire questo script SOLO se non puoi ottenere GRANT diretti
-- ============================================================================

PROMPT ============================================================================
PROMPT Creazione SYNONYM per tabelle UNIRE_REL2
PROMPT ============================================================================

-- Synonym per tabelle principali
CREATE OR REPLACE SYNONYM TC_DATI_GARA_ESTERNA
    FOR UNIRE_REL2.TC_DATI_GARA_ESTERNA;

CREATE OR REPLACE SYNONYM TC_DATI_CLASSIFICA_ESTERNA
    FOR UNIRE_REL2.TC_DATI_CLASSIFICA_ESTERNA;

CREATE OR REPLACE SYNONYM TC_DATI_EDIZIONE_ESTERNA
    FOR UNIRE_REL2.TC_DATI_EDIZIONE_ESTERNA;

CREATE OR REPLACE SYNONYM TC_EDIZIONE
    FOR UNIRE_REL2.TC_EDIZIONE;

CREATE OR REPLACE SYNONYM TC_MANIFESTAZIONE
    FOR UNIRE_REL2.TC_MANIFESTAZIONE;

CREATE OR REPLACE SYNONYM TC_CAVALLO
    FOR UNIRE_REL2.TC_CAVALLO;

CREATE OR REPLACE SYNONYM TD_MANIFESTAZIONE_TIPOLOGICHE
    FOR UNIRE_REL2.TD_MANIFESTAZIONE_TIPOLOGICHE;

PROMPT ============================================================================
PROMPT Verifica synonym creati
PROMPT ============================================================================

SELECT synonym_name, table_owner, table_name
FROM user_synonyms
WHERE table_owner = 'UNIRE_REL2'
ORDER BY synonym_name;

PROMPT
PROMPT ============================================================================
PROMPT NOTA: I synonym NON risolvono il problema dei privilegi!
PROMPT Servono comunque GRANT diretti da UNIRE_REL2 a PVERTULLO
PROMPT ============================================================================
