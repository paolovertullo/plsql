-- ============================================================================
-- Script di compilazione package PKG_CALCOLI_PREMI_MANIFEST
-- Versione: 2.0 - Refactored con parametrizzazione anno
-- ============================================================================

-- Imposta lo schema corretto
-- ALTER SESSION SET CURRENT_SCHEMA = PVERTULLO;

PROMPT ============================================================================
PROMPT Compilazione PKG_CALCOLI_PREMI_MANIFEST - PACKAGE SPEC
PROMPT ============================================================================

@@PKG_CALCOLI_PREMI_MANIFEST.pks

SHOW ERRORS PACKAGE PKG_CALCOLI_PREMI_MANIFEST;

PROMPT
PROMPT ============================================================================
PROMPT Compilazione PKG_CALCOLI_PREMI_MANIFEST - PACKAGE BODY
PROMPT ============================================================================

@@PKG_CALCOLI_PREMI_MANIFEST.pkb

SHOW ERRORS PACKAGE BODY PKG_CALCOLI_PREMI_MANIFEST;

PROMPT
PROMPT ============================================================================
PROMPT Verifica compilazione
PROMPT ============================================================================

SELECT object_name, object_type, status,
       TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS last_compile
FROM user_objects
WHERE object_name = 'PKG_CALCOLI_PREMI_MANIFEST'
ORDER BY object_type;

PROMPT
PROMPT ============================================================================
PROMPT Verifica errori di compilazione
PROMPT ============================================================================

SELECT line, position, text
FROM user_errors
WHERE name = 'PKG_CALCOLI_PREMI_MANIFEST'
ORDER BY sequence;

PROMPT
PROMPT ============================================================================
PROMPT Fine compilazione
PROMPT ============================================================================
