-- ============================================================================
-- Script SEMPLIFICATO per estrarre struttura TC_DATI_GARA_ESTERNA
-- Se 00_extract_table_structures.sql da errori, usa questo
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 2000

SPOOL extract_simple.txt

PROMPT ============================================================================
PROMPT TC_DATI_GARA_ESTERNA - Struttura completa
PROMPT ============================================================================
PROMPT
PROMPT Formato: COLUMN_NAME | DATA_TYPE | LENGTH | PRECISION | SCALE | NULLABLE
PROMPT

SELECT
    column_id || '|' ||
    column_name || '|' ||
    data_type || '|' ||
    NVL(TO_CHAR(data_length), '') || '|' ||
    NVL(TO_CHAR(data_precision), '') || '|' ||
    NVL(TO_CHAR(data_scale), '') || '|' ||
    nullable AS column_info
FROM all_tab_columns
WHERE owner = 'UNIRE_REL2'
  AND table_name = 'TC_DATI_GARA_ESTERNA'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT DESC alternativo
PROMPT ============================================================================

DESC UNIRE_REL2.TC_DATI_GARA_ESTERNA

SPOOL OFF

PROMPT File 'extract_simple.txt' creato!
