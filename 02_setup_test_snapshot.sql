-- ============================================================================
-- Setup TC_TEST_SNAPSHOT e sequence per test di non-regressione
-- ============================================================================

PROMPT ============================================================================
PROMPT Verifica esistenza tabella TC_TEST_SNAPSHOT
PROMPT ============================================================================

SELECT COUNT(*) AS table_exists
FROM user_tables
WHERE table_name = 'TC_TEST_SNAPSHOT';

PROMPT
PROMPT ============================================================================
PROMPT Creazione SEQUENCE per ID_SNAP_ROW (se non esiste)
PROMPT ============================================================================

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_count
      FROM user_sequences
     WHERE sequence_name = 'SEQ_TC_TEST_SNAPSHOT';

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE PVERTULLO.SEQ_TC_TEST_SNAPSHOT
                           START WITH 1
                           INCREMENT BY 1
                           NOCACHE
                           NOCYCLE';
        DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_TC_TEST_SNAPSHOT creata');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_TC_TEST_SNAPSHOT già esistente');
    END IF;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT Pulizia dati test precedenti (OPZIONALE)
PROMPT ============================================================================

-- Decommentare per pulire i dati precedenti
-- DELETE FROM PVERTULLO.TC_TEST_SNAPSHOT WHERE VERSIONE_ALGORITMO LIKE 'V2.0-REFACTORED-%';
-- COMMIT;

PROMPT
PROMPT ============================================================================
PROMPT Verifica struttura tabella
PROMPT ============================================================================

DESC PVERTULLO.TC_TEST_SNAPSHOT;

PROMPT
PROMPT ============================================================================
PROMPT Setup completato
PROMPT ============================================================================
