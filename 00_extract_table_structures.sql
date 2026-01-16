-- ============================================================================
-- Script per estrarre struttura tabelle UNIRE_REL2
-- Eseguire come PVERTULLO (o qualsiasi utente con accesso SELECT)
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 1000
SET LONG 100000
SET LONGCHUNKSIZE 100000

SPOOL extract_table_structures.txt

PROMPT ============================================================================
PROMPT STRUTTURA TABELLE UNIRE_REL2 per PKG_CALCOLI_PREMI_MANIFEST
PROMPT ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT 1. TC_DATI_GARA_ESTERNA (PRINCIPALE - usato con %ROWTYPE)
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_DATI_GARA_ESTERNA'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT 2. TC_DATI_CLASSIFICA_ESTERNA
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_DATI_CLASSIFICA_ESTERNA'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT 3. TC_DATI_EDIZIONE_ESTERNA
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_DATI_EDIZIONE_ESTERNA'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT 4. TC_EDIZIONE
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_EDIZIONE'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT 5. TC_MANIFESTAZIONE
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_MANIFESTAZIONE'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT 6. TC_CAVALLO
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_CAVALLO'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT 7. TD_MANIFESTAZIONE_TIPOLOGICHE
PROMPT ============================================================================

SELECT
    RPAD(column_name, 40) AS column_name,
    RPAD(data_type, 20) AS data_type,
    RPAD(NVL(TO_CHAR(data_length), ' '), 10) AS data_length,
    RPAD(NVL(TO_CHAR(data_precision), ' '), 10) AS data_precision,
    RPAD(NVL(TO_CHAR(data_scale), ' '), 10) AS data_scale,
    RPAD(nullable, 8) AS nullable,
    column_id
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TD_MANIFESTAZIONE_TIPOLOGICHE'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT GENERAZIONE TYPE PER TC_DATI_GARA_ESTERNA
PROMPT ============================================================================
PROMPT
PROMPT Copia e incolla questo TYPE nel package spec:
PROMPT

SELECT 'TYPE t_dati_gara_rec IS RECORD (' || CHR(10) ||
       LISTAGG(
           '    ' ||
           LOWER(column_name) ||
           LPAD(' ', 40 - LENGTH(column_name)) ||
           CASE
               WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL THEN
                   'NUMBER(' || data_precision ||
                   CASE WHEN data_scale > 0 THEN ',' || data_scale ELSE '' END || ')'
               WHEN data_type = 'NUMBER' THEN 'NUMBER'
               WHEN data_type = 'VARCHAR2' THEN 'VARCHAR2(' || data_length || ')'
               WHEN data_type = 'CHAR' THEN 'CHAR(' || data_length || ')'
               WHEN data_type = 'DATE' THEN 'DATE'
               ELSE data_type
           END,
           ',' || CHR(10)
       ) WITHIN GROUP (ORDER BY column_id) || CHR(10) ||
       ');' AS type_definition
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_DATI_GARA_ESTERNA';

PROMPT
PROMPT ============================================================================
PROMPT Fine estrazione
PROMPT ============================================================================

SPOOL OFF

PROMPT
PROMPT File 'extract_table_structures.txt' creato con successo!
PROMPT Invia questo file per generare i TYPE nel package spec.
PROMPT
