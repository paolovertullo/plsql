# Estrazione Struttura Tabelle e Generazione TYPE

Questa guida spiega come estrarre la struttura delle tabelle UNIRE_REL2 e generare TYPE espliciti per il package, evitando la necessità di GRANT diretti per `%ROWTYPE`.

## 🎯 Obiettivo

Risolvere l'errore `PLS-00201: identifier must be declared` creando TYPE espliciti invece di usare `%ROWTYPE`.

## 📋 Script Disponibili

| Script | Scopo | Complessità |
|--------|-------|-------------|
| `00_generate_type_definition.sql` | **⭐ CONSIGLIATO** - Genera TYPE automaticamente | Facile |
| `00_extract_table_simple.sql` | Estrae struttura formato semplice | Facile |
| `00_extract_table_structures.sql` | Estrae tutte le tabelle con dettagli | Medio |

## 🚀 PROCEDURA CONSIGLIATA

### Passo 1: Genera il TYPE automaticamente

Connettiti come PVERTULLO:

```sql
sqlplus PVERTULLO/password@database

-- Genera TYPE per TC_DATI_GARA_ESTERNA
@00_generate_type_definition.sql
```

**Output atteso:**

```sql
TYPE t_dati_gara_rec IS RECORD (
    fk_sequ_id_dati_ediz_esterna      NUMBER(12),
    sequ_id_dati_gara_esterna         NUMBER(12),
    codi_gara_esterna                 VARCHAR2(10),
    desc_nome_gara_esterna            VARCHAR2(100),
    data_gara_esterna                 CHAR(8),
    ...
);
```

### Passo 2: Copia l'output

1. Seleziona tutto il TYPE generato (da `TYPE t_dati_gara_rec IS RECORD (` fino a `);`)
2. Copialo negli appunti

### Passo 3: Inviamelo

Incolla l'output qui nella chat. Io lo inserirò nel package spec e aggiornerò tutte le reference da:
- `tc_dati_gara_esterna%ROWTYPE` → `t_dati_gara_rec`

---

## 🔧 PROCEDURA ALTERNATIVA (se script non funziona)

### Opzione A: Estrazione Semplice

```sql
@00_extract_table_simple.sql
```

Crea il file `extract_simple.txt` con la struttura in formato testo.

### Opzione B: Estrazione Completa

```sql
@00_extract_table_structures.sql
```

Crea il file `extract_table_structures.txt` con tutte le tabelle.

### Opzione C: DESC Manuale

```sql
DESC UNIRE_REL2.TC_DATI_GARA_ESTERNA
```

Copia l'output e mandamelo.

---

## 📝 ESEMPIO OUTPUT ATTESO

Questo è un esempio di come dovrebbe apparire l'output:

```
TYPE t_dati_gara_rec IS RECORD (
    fk_sequ_id_dati_ediz_esterna      NUMBER(12),
    sequ_id_dati_gara_esterna         NUMBER(12),
    codi_gara_esterna                 VARCHAR2(10),
    desc_nome_gara_esterna            VARCHAR2(100),
    data_gara_esterna                 CHAR(8),
    desc_gruppo_categoria             VARCHAR2(50),
    desc_codice_categoria             VARCHAR2(50),
    desc_altezza_ostacoli             VARCHAR2(50),
    flag_gran_premio                  NUMBER(1),
    codi_utente_inserimento           VARCHAR2(20),
    dttm_inserimento                  DATE,
    codi_utente_aggiornamento         VARCHAR2(20),
    dttm_aggiornamento                DATE,
    flag_prova_a_squadre              NUMBER(1),
    nume_mance                        NUMBER(2),
    codi_prontuario                   VARCHAR2(50),
    nume_cavalli_italiani             VARCHAR2(5),
    desc_formula                      VARCHAR2(50),
    data_dressage                     VARCHAR2(8),
    data_cross                        VARCHAR2(8),
    fk_codi_categoria                 NUMBER,
    fk_codi_tipo_classifica           NUMBER,
    fk_codi_livello_cavallo           NUMBER,
    fk_codi_tipo_evento               NUMBER,
    fk_codi_tipo_prova                NUMBER,
    fk_codi_regola_sesso              NUMBER,
    fk_codi_regola_libro              NUMBER,
    fk_codi_eta                       NUMBER,
    flag_premio_masaf                 NUMBER(1)
);
```

---

## ⚠️ TROUBLESHOOTING

### Errore: "table or view does not exist"

Verifica di avere accesso:

```sql
SELECT COUNT(*) FROM UNIRE_REL2.TC_DATI_GARA_ESTERNA WHERE ROWNUM = 1;
```

Se funziona, lo script dovrebbe funzionare.

### Errore: "LISTAGG not supported"

Usa lo script alternativo:

```sql
@00_extract_table_simple.sql
```

### Output troppo lungo troncato

Aumenta la dimensione:

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 500
```

---

## 🔄 COSA FARÒ CON L'OUTPUT

Una volta ricevuto l'output:

1. ✅ Aggiungerò il TYPE nel package spec (`.pks`)
2. ✅ Sostituirò tutte le occorrenze nel package spec:
   - `tc_dati_gara_esterna%ROWTYPE` → `t_dati_gara_rec`
3. ✅ Sostituirò nel package body (`.pkb`):
   - Variabili che usavano `%ROWTYPE`
4. ✅ Testerò la compilazione
5. ✅ Farò commit delle modifiche

---

## 📊 COSA ESTRAE

Lo script estrae:

- Nome colonna
- Tipo di dato (NUMBER, VARCHAR2, CHAR, DATE, etc.)
- Lunghezza (per VARCHAR2/CHAR)
- Precisione e scala (per NUMBER)
- Nullable (Y/N)

E genera automaticamente il TYPE RECORD compatibile.

---

## 🎯 PROSSIMO PASSO

**Esegui ora:**

```sql
sqlplus PVERTULLO/password@database
@00_generate_type_definition.sql
```

**E incolla l'output qui!** 🚀

Ci metterò ~5 minuti per aggiornare il package e fare il commit.
