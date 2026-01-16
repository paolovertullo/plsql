-- ============================================================================
-- Test di NON-REGRESSIONE per SALTO OSTACOLI
-- Confronta vecchio algoritmo vs nuovo algoritmo refactored
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT ============================================================================
PROMPT FASE 1: Selezione gare SALTO OSTACOLI da testare
PROMPT ============================================================================

COLUMN gara_id FORMAT 99999999
COLUMN desc_nome FORMAT A50
COLUMN num_cavalli FORMAT 9999
COLUMN data_gara FORMAT A10

-- Seleziona prime 5 gare Salto Ostacoli del 2025 con dati calcolati
SELECT dg.sequ_id_dati_gara_esterna AS gara_id,
       dg.desc_nome_gara_esterna AS desc_nome,
       dg.data_gara_esterna AS data_gara,
       COUNT(DISTINCT ce.fk_sequ_id_cavallo) AS num_cavalli
FROM tc_dati_gara_esterna dg
JOIN tc_dati_classifica_esterna ce
    ON ce.fk_sequ_id_dati_gara_esterna = dg.sequ_id_dati_gara_esterna
JOIN tc_dati_edizione_esterna ee
    ON ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
JOIN tc_edizione ed
    ON ed.sequ_id_edizione = ee.fk_sequ_id_edizione
JOIN tc_manifestazione mf
    ON mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
WHERE dg.data_gara_esterna LIKE '2025%'
  AND mf.fk_codi_disciplina = 4  -- Salto Ostacoli
  AND ce.importo_masaf_calcolato IS NOT NULL  -- Già calcolato con vecchio algoritmo
  AND ce.fk_sequ_id_cavallo IS NOT NULL
GROUP BY dg.sequ_id_dati_gara_esterna, dg.desc_nome_gara_esterna, dg.data_gara_esterna
HAVING COUNT(DISTINCT ce.fk_sequ_id_cavallo) >= 3  -- Almeno 3 cavalli
ORDER BY dg.data_gara_esterna
FETCH FIRST 5 ROWS ONLY;

PROMPT
PROMPT Seleziona una GARA_ID dalla lista sopra e modificala nella variabile sotto:
PROMPT

PROMPT ============================================================================
PROMPT FASE 2: Esecuzione nuovo algoritmo su gara specifica
PROMPT ============================================================================

DECLARE
    -- *** MODIFICA QUI IL GARA_ID DA TESTARE ***
    v_gara_id CONSTANT NUMBER := 123456;  -- <-- INSERISCI QUI IL GARA_ID

    v_risultati PKG_CALCOLI_PREMI_MANIFEST.t_tabella_premi;
    v_disciplina_id NUMBER;
    v_count_new NUMBER;
    v_count_old NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('TEST NON-REGRESSIONE - Gara ID: ' || v_gara_id);
    DBMS_OUTPUT.PUT_LINE('============================================================');

    -- Verifica che la gara abbia dati vecchi
    SELECT COUNT(*)
      INTO v_count_old
      FROM tc_dati_classifica_esterna
     WHERE fk_sequ_id_dati_gara_esterna = v_gara_id
       AND importo_masaf_calcolato IS NOT NULL;

    IF v_count_old = 0 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ ATTENZIONE: La gara ' || v_gara_id || ' non ha dati calcolati con vecchio algoritmo!');
        DBMS_OUTPUT.PUT_LINE('Seleziona una gara dalla lista FASE 1.');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('✓ Gara con ' || v_count_old || ' cavalli già calcolati (vecchio algoritmo)');
    DBMS_OUTPUT.PUT_LINE('');

    -- Recupera disciplina
    SELECT mf.fk_codi_disciplina
      INTO v_disciplina_id
      FROM tc_dati_gara_esterna dg
      JOIN tc_dati_edizione_esterna ee ON ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
      JOIN tc_edizione ed ON ed.sequ_id_edizione = ee.fk_sequ_id_edizione
      JOIN tc_manifestazione mf ON mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
     WHERE dg.sequ_id_dati_gara_esterna = v_gara_id;

    IF v_disciplina_id != 4 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ ATTENZIONE: La gara non è SALTO OSTACOLI (disciplina=' || v_disciplina_id || ')');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('⏳ Esecuzione nuovo algoritmo in modalità TEST...');

    -- Esegui nuovo handler in modalità TEST
    v_risultati := PKG_CALCOLI_PREMI_MANIFEST.HANDLER_SALTO_OSTACOLI(
        p_gara_id => v_gara_id,
        p_anno => 2025,
        p_modalita_test => TRUE  -- Inserisce in tc_test_snapshot
    );

    COMMIT;

    -- Conta quanti record inseriti
    SELECT COUNT(*)
      INTO v_count_new
      FROM PVERTULLO.TC_TEST_SNAPSHOT
     WHERE GARA_ID = v_gara_id
       AND VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025';

    DBMS_OUTPUT.PUT_LINE('✓ Nuovo algoritmo eseguito: ' || v_count_new || ' record in tc_test_snapshot');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('Procedi con FASE 3 per vedere il confronto');
    DBMS_OUTPUT.PUT_LINE('============================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERRORE: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT FASE 3: Confronto risultati vecchio vs nuovo algoritmo
PROMPT ============================================================================

COLUMN cavallo_id FORMAT 99999999
COLUMN nome_cavallo FORMAT A30
COLUMN posizione FORMAT 999
COLUMN vecchio_premio FORMAT 999999.99
COLUMN nuovo_premio FORMAT 999999.99
COLUMN differenza FORMAT 9999.99
COLUMN esito FORMAT A10

-- Confronto dettagliato
SELECT
    old.fk_sequ_id_cavallo AS cavallo_id,
    old.desc_cavallo AS nome_cavallo,
    old.nume_piazzamento AS posizione,
    old.importo_masaf_calcolato AS vecchio_premio,
    new.PREMIO_CALCOLATO AS nuovo_premio,
    (new.PREMIO_CALCOLATO - old.importo_masaf_calcolato) AS differenza,
    CASE
        WHEN ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0)) < 0.01 THEN '✓ OK'
        ELSE '✗ DIFF'
    END AS esito
FROM tc_dati_classifica_esterna old
LEFT JOIN PVERTULLO.TC_TEST_SNAPSHOT new
    ON old.fk_sequ_id_dati_gara_esterna = new.GARA_ID
    AND old.fk_sequ_id_cavallo = new.CAVALLO_ID
    AND new.VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025'
WHERE old.fk_sequ_id_dati_gara_esterna = 123456  -- <-- STESSO GARA_ID USATO SOPRA
  AND old.fk_sequ_id_cavallo IS NOT NULL
ORDER BY old.nume_piazzamento;

PROMPT
PROMPT ============================================================================
PROMPT FASE 4: Statistiche differenze
PROMPT ============================================================================

-- Statistiche aggregate
SELECT
    COUNT(*) AS tot_cavalli,
    SUM(CASE WHEN ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0)) < 0.01
             THEN 1 ELSE 0 END) AS ok_count,
    SUM(CASE WHEN ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0)) >= 0.01
             THEN 1 ELSE 0 END) AS diff_count,
    ROUND(AVG(ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0))), 2) AS avg_diff,
    ROUND(MAX(ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0))), 2) AS max_diff,
    ROUND(SUM(old.importo_masaf_calcolato), 2) AS tot_vecchio,
    ROUND(SUM(new.PREMIO_CALCOLATO), 2) AS tot_nuovo
FROM tc_dati_classifica_esterna old
LEFT JOIN PVERTULLO.TC_TEST_SNAPSHOT new
    ON old.fk_sequ_id_dati_gara_esterna = new.GARA_ID
    AND old.fk_sequ_id_cavallo = new.CAVALLO_ID
    AND new.VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025'
WHERE old.fk_sequ_id_dati_gara_esterna = 123456;  -- <-- STESSO GARA_ID

PROMPT
PROMPT ============================================================================
PROMPT Test completato
PROMPT ============================================================================
PROMPT
PROMPT Se ci sono differenze (DIFF_COUNT > 0), analizzare le cause:
PROMPT - Arrotondamenti diversi?
PROMPT - Logica cambiata?
PROMPT - Bug nel vecchio o nuovo algoritmo?
PROMPT
PROMPT ============================================================================
