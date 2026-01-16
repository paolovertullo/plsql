-- ============================================================================
-- Generatore automatico TYPE per TC_DATI_GARA_ESTERNA
-- Genera il codice TYPE da inserire nel package spec
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 300

PROMPT ============================================================================
PROMPT Generazione TYPE t_dati_gara_rec
PROMPT ============================================================================
PROMPT

DECLARE
    v_type_def CLOB := '';
    v_line VARCHAR2(500);
    v_count NUMBER := 0;
    v_total NUMBER := 0;

    CURSOR c_columns IS
        SELECT
            column_name,
            data_type,
            data_length,
            data_precision,
            data_scale,
            column_id
        FROM all_tab_columns
        WHERE owner = 'UNIRE_REL2'
          AND table_name = 'TC_DATI_GARA_ESTERNA'
        ORDER BY column_id;
BEGIN
    -- Conta colonne
    SELECT COUNT(*)
      INTO v_total
      FROM all_tab_columns
     WHERE owner = 'UNIRE_REL2'
       AND table_name = 'TC_DATI_GARA_ESTERNA';

    DBMS_OUTPUT.PUT_LINE('-- ============================================================================');
    DBMS_OUTPUT.PUT_LINE('-- TYPE per TC_DATI_GARA_ESTERNA (' || v_total || ' colonne)');
    DBMS_OUTPUT.PUT_LINE('-- Inserire nel package spec al posto di tc_dati_gara_esterna%ROWTYPE');
    DBMS_OUTPUT.PUT_LINE('-- ============================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('TYPE t_dati_gara_rec IS RECORD (');

    FOR rec IN c_columns LOOP
        v_count := v_count + 1;

        -- Costruisce la riga
        v_line := '    ' || LOWER(rec.column_name);

        -- Padding per allineamento
        v_line := RPAD(v_line, 45);

        -- Tipo di dato
        IF rec.data_type = 'NUMBER' THEN
            IF rec.data_precision IS NOT NULL THEN
                v_line := v_line || 'NUMBER(' || rec.data_precision;
                IF rec.data_scale > 0 THEN
                    v_line := v_line || ',' || rec.data_scale;
                END IF;
                v_line := v_line || ')';
            ELSE
                v_line := v_line || 'NUMBER';
            END IF;
        ELSIF rec.data_type = 'VARCHAR2' THEN
            v_line := v_line || 'VARCHAR2(' || rec.data_length || ')';
        ELSIF rec.data_type = 'CHAR' THEN
            v_line := v_line || 'CHAR(' || rec.data_length || ')';
        ELSIF rec.data_type = 'DATE' THEN
            v_line := v_line || 'DATE';
        ELSE
            v_line := v_line || rec.data_type;
        END IF;

        -- Virgola (tranne per ultima colonna)
        IF v_count < v_total THEN
            v_line := v_line || ',';
        END IF;

        DBMS_OUTPUT.PUT_LINE(v_line);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(');');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('-- ============================================================================');
    DBMS_OUTPUT.PUT_LINE('-- Fine TYPE - ' || v_total || ' colonne generate');
    DBMS_OUTPUT.PUT_LINE('-- ============================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERRORE: Tabella TC_DATI_GARA_ESTERNA non trovata!');
        DBMS_OUTPUT.PUT_LINE('Verifica:');
        DBMS_OUTPUT.PUT_LINE('  1. Di avere accesso alla tabella UNIRE_REL2.TC_DATI_GARA_ESTERNA');
        DBMS_OUTPUT.PUT_LINE('  2. Che la tabella esista e sia nello schema UNIRE_REL2');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERRORE: ' || SQLERRM);
        RAISE;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT Copia il TYPE generato sopra e inseriscilo nel package spec
PROMPT Sostituisci tutte le occorrenze di:
PROMPT   tc_dati_gara_esterna%ROWTYPE
PROMPT con:
PROMPT   t_dati_gara_rec
PROMPT ============================================================================
