-- ============================================================================
-- Script DIAGNOSI privilegi utente PVERTULLO
-- Eseguire come PVERTULLO per capire quali privilegi hai
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 1000

PROMPT ============================================================================
PROMPT DIAGNOSI PRIVILEGI UTENTE PVERTULLO
PROMPT ============================================================================

PROMPT
PROMPT 1. PRIVILEGI DIRETTI (necessari per package)
PROMPT --------------------------------------------
SELECT
    table_schema,
    table_name,
    privilege,
    'DIRETTO' AS tipo_grant
FROM user_tab_privs
WHERE table_schema = 'UNIRE_REL2'
ORDER BY table_name, privilege;

PROMPT
PROMPT 2. ROLES ASSEGNATI
PROMPT -------------------
SELECT granted_role, default_role
FROM user_role_privs
ORDER BY granted_role;

PROMPT
PROMPT 3. PRIVILEGI TRAMITE ROLE (NON funzionano per package)
PROMPT -------------------------------------------------------
SELECT
    r.role,
    tp.table_schema,
    tp.table_name,
    tp.privilege,
    'TRAMITE ROLE' AS tipo_grant
FROM user_role_privs r
JOIN role_tab_privs tp ON r.granted_role = tp.role
WHERE tp.table_schema = 'UNIRE_REL2'
ORDER BY tp.table_name, tp.privilege;

PROMPT
PROMPT 4. TEST ACCESSO TABELLE (se vedi risultati, hai accesso)
PROMPT ---------------------------------------------------------

-- Test accesso alle tabelle principali
DECLARE
    v_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Test accesso tabelle UNIRE_REL2:');
    DBMS_OUTPUT.PUT_LINE('');

    -- TC_DATI_GARA_ESTERNA
    BEGIN
        SELECT COUNT(*) INTO v_count FROM UNIRE_REL2.TC_DATI_GARA_ESTERNA WHERE ROWNUM = 1;
        DBMS_OUTPUT.PUT_LINE('✓ TC_DATI_GARA_ESTERNA: Accesso OK (via ' ||
            CASE WHEN EXISTS (SELECT 1 FROM user_tab_privs WHERE table_name = 'TC_DATI_GARA_ESTERNA')
                 THEN 'GRANT DIRETTO'
                 ELSE 'ROLE o PUBLIC'
            END || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ TC_DATI_GARA_ESTERNA: NO ACCESSO - ' || SQLERRM);
    END;

    -- TC_DATI_CLASSIFICA_ESTERNA
    BEGIN
        SELECT COUNT(*) INTO v_count FROM UNIRE_REL2.TC_DATI_CLASSIFICA_ESTERNA WHERE ROWNUM = 1;
        DBMS_OUTPUT.PUT_LINE('✓ TC_DATI_CLASSIFICA_ESTERNA: Accesso OK (via ' ||
            CASE WHEN EXISTS (SELECT 1 FROM user_tab_privs WHERE table_name = 'TC_DATI_CLASSIFICA_ESTERNA')
                 THEN 'GRANT DIRETTO'
                 ELSE 'ROLE o PUBLIC'
            END || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ TC_DATI_CLASSIFICA_ESTERNA: NO ACCESSO - ' || SQLERRM);
    END;

    -- TC_MANIFESTAZIONE
    BEGIN
        SELECT COUNT(*) INTO v_count FROM UNIRE_REL2.TC_MANIFESTAZIONE WHERE ROWNUM = 1;
        DBMS_OUTPUT.PUT_LINE('✓ TC_MANIFESTAZIONE: Accesso OK (via ' ||
            CASE WHEN EXISTS (SELECT 1 FROM user_tab_privs WHERE table_name = 'TC_MANIFESTAZIONE')
                 THEN 'GRANT DIRETTO'
                 ELSE 'ROLE o PUBLIC'
            END || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ TC_MANIFESTAZIONE: NO ACCESSO - ' || SQLERRM);
    END;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT INTERPRETAZIONE RISULTATI
PROMPT ============================================================================
PROMPT
PROMPT Se nella sezione 1 (PRIVILEGI DIRETTI) vedi le tabelle:
PROMPT   ✓ OK - Puoi compilare il package
PROMPT
PROMPT Se nella sezione 1 è VUOTA ma nella sezione 3 vedi le tabelle:
PROMPT   ✗ PROBLEMA - Hai privilegi solo tramite ROLE
PROMPT   ✗ Devi eseguire lo script 00_grant_privileges.sql come UNIRE_REL2 o DBA
PROMPT
PROMPT Se nella sezione 4 vedi "via ROLE o PUBLIC":
PROMPT   ✗ PROBLEMA - Serve GRANT DIRETTO per compilare package
PROMPT
PROMPT ============================================================================
