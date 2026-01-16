-- ============================================================================
-- Test in BATCH di tutte le gare SALTO OSTACOLI 2025
-- ATTENZIONE: Può richiedere molto tempo se ci sono molte gare
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT ============================================================================
PROMPT Test in BATCH - Tutte le gare SALTO OSTACOLI 2025
PROMPT ============================================================================

DECLARE
    v_risultati PKG_CALCOLI_PREMI_MANIFEST.t_tabella_premi;
    v_count_gare NUMBER := 0;
    v_count_ok NUMBER := 0;
    v_count_err NUMBER := 0;
    v_gara_id NUMBER;

    CURSOR c_gare IS
        SELECT DISTINCT dg.sequ_id_dati_gara_esterna AS gara_id,
               dg.desc_nome_gara_esterna,
               dg.data_gara_esterna,
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
          AND ce.importo_masaf_calcolato IS NOT NULL
          AND ce.fk_sequ_id_cavallo IS NOT NULL
        GROUP BY dg.sequ_id_dati_gara_esterna, dg.desc_nome_gara_esterna, dg.data_gara_esterna
        HAVING COUNT(DISTINCT ce.fk_sequ_id_cavallo) >= 1
        ORDER BY dg.data_gara_esterna;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Inizio test batch...');
    DBMS_OUTPUT.PUT_LINE('');

    FOR rec IN c_gare LOOP
        v_count_gare := v_count_gare + 1;

        BEGIN
            -- Esegui handler
            v_risultati := PKG_CALCOLI_PREMI_MANIFEST.HANDLER_SALTO_OSTACOLI(
                p_gara_id => rec.gara_id,
                p_anno => 2025,
                p_modalita_test => TRUE
            );

            v_count_ok := v_count_ok + 1;

            IF MOD(v_count_gare, 10) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Processate ' || v_count_gare || ' gare...');
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                v_count_err := v_count_err + 1;
                DBMS_OUTPUT.PUT_LINE('✗ ERRORE Gara ' || rec.gara_id || ': ' || SQLERRM);
        END;

        -- Commit ogni 50 gare per evitare rollback troppo grandi
        IF MOD(v_count_gare, 50) = 0 THEN
            COMMIT;
        END IF;

    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('RIEPILOGO TEST BATCH');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('Totale gare processate: ' || v_count_gare);
    DBMS_OUTPUT.PUT_LINE('Successo: ' || v_count_ok);
    DBMS_OUTPUT.PUT_LINE('Errori: ' || v_count_err);
    DBMS_OUTPUT.PUT_LINE('============================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERRORE BATCH: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT Analisi differenze aggregate
PROMPT ============================================================================

-- Report differenze aggregate per tutte le gare testate
SELECT
    COUNT(DISTINCT old.fk_sequ_id_dati_gara_esterna) AS tot_gare,
    COUNT(*) AS tot_cavalli,
    SUM(CASE WHEN ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0)) < 0.01
             THEN 1 ELSE 0 END) AS ok_count,
    SUM(CASE WHEN ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0)) >= 0.01
             THEN 1 ELSE 0 END) AS diff_count,
    ROUND(AVG(ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0))), 2) AS avg_diff,
    ROUND(MAX(ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0))), 2) AS max_diff,
    ROUND(SUM(old.importo_masaf_calcolato), 2) AS tot_vecchio,
    ROUND(SUM(new.PREMIO_CALCOLATO), 2) AS tot_nuovo,
    ROUND(SUM(new.PREMIO_CALCOLATO) - SUM(old.importo_masaf_calcolato), 2) AS diff_totale
FROM tc_dati_classifica_esterna old
JOIN PVERTULLO.TC_TEST_SNAPSHOT new
    ON old.fk_sequ_id_dati_gara_esterna = new.GARA_ID
    AND old.fk_sequ_id_cavallo = new.CAVALLO_ID
    AND new.VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025'
JOIN tc_dati_gara_esterna dg
    ON dg.sequ_id_dati_gara_esterna = old.fk_sequ_id_dati_gara_esterna
WHERE dg.data_gara_esterna LIKE '2025%'
  AND old.fk_sequ_id_cavallo IS NOT NULL;

PROMPT
PROMPT ============================================================================
PROMPT Gare con maggiori differenze
PROMPT ============================================================================

-- Top 10 gare con maggiori differenze
SELECT * FROM (
    SELECT
        old.fk_sequ_id_dati_gara_esterna AS gara_id,
        dg.desc_nome_gara_esterna,
        COUNT(*) AS num_cavalli,
        SUM(CASE WHEN ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0)) >= 0.01
                 THEN 1 ELSE 0 END) AS cavalli_con_diff,
        ROUND(SUM(ABS(new.PREMIO_CALCOLATO - NVL(old.importo_masaf_calcolato, 0))), 2) AS diff_totale
    FROM tc_dati_classifica_esterna old
    JOIN PVERTULLO.TC_TEST_SNAPSHOT new
        ON old.fk_sequ_id_dati_gara_esterna = new.GARA_ID
        AND old.fk_sequ_id_cavallo = new.CAVALLO_ID
        AND new.VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025'
    JOIN tc_dati_gara_esterna dg
        ON dg.sequ_id_dati_gara_esterna = old.fk_sequ_id_dati_gara_esterna
    WHERE dg.data_gara_esterna LIKE '2025%'
      AND old.fk_sequ_id_cavallo IS NOT NULL
    GROUP BY old.fk_sequ_id_dati_gara_esterna, dg.desc_nome_gara_esterna
    ORDER BY diff_totale DESC
)
WHERE ROWNUM <= 10;

PROMPT
PROMPT ============================================================================
PROMPT Test batch completato
PROMPT ============================================================================
