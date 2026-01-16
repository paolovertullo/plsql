-- ============================================================================
-- Script GRANT privilegi da UNIRE_REL2 a PVERTULLO
-- Eseguire questo script come utente UNIRE_REL2 o come DBA
-- ============================================================================

PROMPT ============================================================================
PROMPT GRANT privilegi da UNIRE_REL2 a PVERTULLO
PROMPT ============================================================================
PROMPT
PROMPT Questo script deve essere eseguito come:
PROMPT - Utente UNIRE_REL2 (owner delle tabelle)
PROMPT - Oppure DBA con privilegi di grant
PROMPT
PROMPT ============================================================================

-- Privilegi SELECT (obbligatori per %ROWTYPE nei package)
GRANT SELECT ON UNIRE_REL2.TC_DATI_GARA_ESTERNA TO PVERTULLO;
GRANT SELECT ON UNIRE_REL2.TC_DATI_CLASSIFICA_ESTERNA TO PVERTULLO;
GRANT SELECT ON UNIRE_REL2.TC_DATI_EDIZIONE_ESTERNA TO PVERTULLO;
GRANT SELECT ON UNIRE_REL2.TC_EDIZIONE TO PVERTULLO;
GRANT SELECT ON UNIRE_REL2.TC_MANIFESTAZIONE TO PVERTULLO;
GRANT SELECT ON UNIRE_REL2.TC_CAVALLO TO PVERTULLO;
GRANT SELECT ON UNIRE_REL2.TD_MANIFESTAZIONE_TIPOLOGICHE TO PVERTULLO;

PROMPT ✓ Privilegi SELECT concessi

-- Privilegi INSERT/UPDATE (necessari per salvare risultati)
GRANT INSERT, UPDATE ON UNIRE_REL2.TC_DATI_CLASSIFICA_ESTERNA TO PVERTULLO;
GRANT UPDATE ON UNIRE_REL2.TC_DATI_GARA_ESTERNA TO PVERTULLO;

PROMPT ✓ Privilegi INSERT/UPDATE concessi

PROMPT
PROMPT ============================================================================
PROMPT Verifica privilegi concessi
PROMPT ============================================================================

-- Mostra i privilegi concessi a PVERTULLO
SELECT
    table_schema,
    table_name,
    privilege
FROM dba_tab_privs
WHERE grantee = 'PVERTULLO'
  AND table_schema = 'UNIRE_REL2'
ORDER BY table_name, privilege;

PROMPT
PROMPT ============================================================================
PROMPT GRANT completati con successo!
PROMPT ============================================================================
PROMPT
PROMPT Ora puoi compilare il package in PVERTULLO:
PROMPT   sqlplus PVERTULLO/password@database
PROMPT   @01_compile_packages.sql
PROMPT
PROMPT ============================================================================
