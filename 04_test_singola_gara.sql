-- ============================================================================
-- Test rapido su singola gara SALTO OSTACOLI
-- Usa questo script per test veloci durante lo sviluppo
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ============================================================================
PROMPT Test rapido SALTO OSTACOLI
PROMPT ============================================================================

DEFINE gara_id = &1

PROMPT Gara ID: &gara_id

DECLARE
    v_risultati PKG_CALCOLI_PREMI_MANIFEST.t_tabella_premi;
    v_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Esecuzione handler SALTO OSTACOLI in modalità TEST...');

    -- Esegui handler
    v_risultati := PKG_CALCOLI_PREMI_MANIFEST.HANDLER_SALTO_OSTACOLI(
        p_gara_id => &gara_id,
        p_anno => 2025,
        p_modalita_test => TRUE
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('✓ Esecuzione completata');

    -- Mostra risultati
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Risultati inseriti in tc_test_snapshot:');

    FOR rec IN (
        SELECT CAVALLO_ID, NOME_CAVALLO, POSIZIONE, PREMIO_CALCOLATO
        FROM PVERTULLO.TC_TEST_SNAPSHOT
        WHERE GARA_ID = &gara_id
          AND VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025'
        ORDER BY POSIZIONE
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Pos ' || LPAD(rec.POSIZIONE, 3) ||
                           ' - ' || RPAD(rec.NOME_CAVALLO, 30) ||
                           ' - €' || LPAD(TO_CHAR(rec.PREMIO_CALCOLATO, '99999.99'), 10));
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERRORE: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

-- Confronto veloce con vecchio algoritmo
SELECT
    CASE
        WHEN ABS(SUM(new.PREMIO_CALCOLATO) - SUM(old.importo_masaf_calcolato)) < 1 THEN '✓ OK - Totali coincidono'
        ELSE '✗ DIFFERENZA: ' || TO_CHAR(SUM(new.PREMIO_CALCOLATO) - SUM(old.importo_masaf_calcolato), '99999.99') || ' €'
    END AS esito_confronto
FROM tc_dati_classifica_esterna old
LEFT JOIN PVERTULLO.TC_TEST_SNAPSHOT new
    ON old.fk_sequ_id_dati_gara_esterna = new.GARA_ID
    AND old.fk_sequ_id_cavallo = new.CAVALLO_ID
    AND new.VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025'
WHERE old.fk_sequ_id_dati_gara_esterna = &gara_id
  AND old.fk_sequ_id_cavallo IS NOT NULL;

UNDEFINE gara_id
