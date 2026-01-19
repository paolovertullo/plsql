SET SERVEROUTPUT ON SIZE 1000000;

DECLARE
    TYPE t_problema IS RECORD (
        gara_id          NUMBER,
        nome_gara        VARCHAR2(500),
        num_differenze   NUMBER,
        dettagli         CLOB
    );
    TYPE t_tabella_problemi IS TABLE OF t_problema;
    v_problemi           t_tabella_problemi := t_tabella_problemi();
    v_idx                PLS_INTEGER := 0;

    v_count_gare         NUMBER := 0;
    v_count_ok           NUMBER := 0;
    v_count_diff         NUMBER := 0;

    v_risultato_v2       PKG_CALCOLI_PREMI_MANIFEST.t_tabella_premi;
    v_count_diff_gara    NUMBER;
    v_dettagli           CLOB;
    v_nome_gara          VARCHAR2(500);
BEGIN
    DBMS_OUTPUT.DISABLE;  -- Ultra silence during processing

    FOR r_gara IN (
        SELECT dg.sequ_id_dati_gara_esterna AS gara_id,
               dg.nome_gara
          FROM tc_dati_gara_esterna dg
         WHERE dg.anno_manifestazione = 2025
           AND PKG_CALCOLI_PREMI_MANIFEST.GET_DISCIPLINA(dg.sequ_id_dati_gara_esterna) = 7  -- MONTA DA LAVORO
         ORDER BY dg.sequ_id_dati_gara_esterna
    ) LOOP
        v_count_gare := v_count_gare + 1;
        v_count_diff_gara := 0;
        v_dettagli := '';
        v_nome_gara := r_gara.nome_gara;

        BEGIN
            v_risultato_v2 := PKG_CALCOLI_PREMI_MANIFEST.handler_monta_da_lavoro_v2(
                p_gara_id => r_gara.gara_id,
                p_anno => 2025,
                p_modalita_test => TRUE
            );

            FOR i IN 1..v_risultato_v2.COUNT LOOP
                FOR r_curr IN (
                    SELECT importo_masaf_calcolato
                      FROM tc_premi_cavalli_esterna
                     WHERE sequ_id_premi_cavalli_esterna = v_risultato_v2(i).premio_id
                ) LOOP
                    IF ABS(NVL(r_curr.importo_masaf_calcolato, 0) - NVL(v_risultato_v2(i).importo, 0)) > 0.01 THEN
                        v_count_diff_gara := v_count_diff_gara + 1;
                        v_dettagli := v_dettagli ||
                            '  Premio ID ' || v_risultato_v2(i).premio_id ||
                            ': attuale=' || r_curr.importo_masaf_calcolato ||
                            ', v2=' || v_risultato_v2(i).importo || CHR(10);
                    END IF;
                END LOOP;
            END LOOP;

            IF v_count_diff_gara = 0 THEN
                v_count_ok := v_count_ok + 1;
            ELSE
                v_count_diff := v_count_diff + 1;
                v_idx := v_idx + 1;
                v_problemi.EXTEND;
                v_problemi(v_idx).gara_id := r_gara.gara_id;
                v_problemi(v_idx).nome_gara := v_nome_gara;
                v_problemi(v_idx).num_differenze := v_count_diff_gara;
                v_problemi(v_idx).dettagli := v_dettagli;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                v_count_diff := v_count_diff + 1;
                v_idx := v_idx + 1;
                v_problemi.EXTEND;
                v_problemi(v_idx).gara_id := r_gara.gara_id;
                v_problemi(v_idx).nome_gara := v_nome_gara;
                v_problemi(v_idx).num_differenze := 999;
                v_problemi(v_idx).dettagli := 'ERRORE: ' || SQLERRM;
        END;

        ROLLBACK;  -- Keep test environment clean
    END LOOP;

    DBMS_OUTPUT.ENABLE(1000000);  -- Re-enable for results

    -- Print concise summary
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('TEST NON REGRESSIONE - MONTA DA LAVORO V2 (2025)');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('Gare analizzate      : ' || v_count_gare);
    DBMS_OUTPUT.PUT_LINE('Gare OK              : ' || v_count_ok);
    DBMS_OUTPUT.PUT_LINE('Gare con differenze  : ' || v_count_diff);
    DBMS_OUTPUT.PUT_LINE('Percentuale successo : ' ||
        ROUND(v_count_ok * 100 / NULLIF(v_count_gare, 0), 2) || '%');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');

    IF v_count_diff = 0 THEN
        DBMS_OUTPUT.PUT_LINE('>>> TUTTI I TEST PASSATI! <<<');
    ELSE
        DBMS_OUTPUT.PUT_LINE('>>> ATTENZIONE: ' || v_count_diff || ' GARE CON DIFFERENZE <<<');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('DETTAGLIO PROBLEMI:');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------');
        FOR i IN 1..v_problemi.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Gara ID: ' || v_problemi(i).gara_id);
            DBMS_OUTPUT.PUT_LINE('Nome: ' || v_problemi(i).nome_gara);
            DBMS_OUTPUT.PUT_LINE('Differenze: ' || v_problemi(i).num_differenze);
            DBMS_OUTPUT.PUT_LINE(v_problemi(i).dettagli);
        END LOOP;
    END IF;

    DBMS_OUTPUT.PUT_LINE('================================================================================');
END;
/
