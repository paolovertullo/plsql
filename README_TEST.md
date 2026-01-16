# Test di Non-Regressione - PKG_CALCOLI_PREMI_MANIFEST v2.0

Questa guida spiega come testare il package refactored per verificare che non ci siano regressioni rispetto al vecchio algoritmo.

## 📋 File Disponibili

| File | Descrizione |
|------|-------------|
| `PKG_CALCOLI_PREMI_MANIFEST.pks` | Package specification (refactored) |
| `PKG_CALCOLI_PREMI_MANIFEST.pkb` | Package body (refactored) |
| `01_compile_packages.sql` | Script compilazione package |
| `02_setup_test_snapshot.sql` | Setup tabella test e sequence |
| `03_test_non_regressione_salto_ostacoli.sql` | Test dettagliato singola gara |
| `04_test_singola_gara.sql` | Test rapido singola gara |
| `05_test_batch_tutte_gare_2025.sql` | Test batch tutte le gare 2025 |

## 🚀 Procedura Completa di Test

### Passo 1: Compilare i Package

Connettiti a Oracle con SQL*Plus o SQL Developer:

```sql
-- Connessione
sqlplus PVERTULLO/password@database

-- Compila i package
@01_compile_packages.sql
```

Verifica che non ci siano errori di compilazione. Se ci sono errori, verifica:
- Privilegi sulle tabelle
- Schema PVERTULLO (sia per il package che per tc_test_snapshot)

### Passo 2: Setup Ambiente Test

```sql
-- Setup sequence e verifica tabella
@02_setup_test_snapshot.sql
```

Questo script:
- Verifica che `PVERTULLO.TC_TEST_SNAPSHOT` esista
- Crea la sequence `SEQ_TC_TEST_SNAPSHOT` se non esiste
- Mostra la struttura della tabella

### Passo 3: Test Singola Gara (Consigliato per primo test)

```sql
-- Test con ID gara specifico
@04_test_singola_gara.sql 123456
```

Sostituisci `123456` con un ID gara reale di Salto Ostacoli del 2025.

Questo script:
1. Esegue il nuovo handler in modalità test
2. Inserisce risultati in `tc_test_snapshot`
3. Confronta totale vecchio vs nuovo algoritmo

### Passo 4: Test Dettagliato con Confronto (Se serve analisi approfondita)

```sql
-- Test dettagliato con confronto riga per riga
@03_test_non_regressione_salto_ostacoli.sql
```

Questo script richiede interazione:
1. Mostra lista gare disponibili
2. Ti chiede di modificare il GARA_ID nello script
3. Esegue test e mostra confronto dettagliato cavallo per cavallo

### Passo 5: Test Batch (Opzionale - per test completi)

⚠️ **ATTENZIONE**: Questo script può richiedere molto tempo!

```sql
-- Test su TUTTE le gare Salto Ostacoli 2025
@05_test_batch_tutte_gare_2025.sql
```

Questo script:
- Processa tutte le gare Salto Ostacoli 2025
- Mostra statistiche aggregate
- Identifica gare con maggiori differenze

## 📊 Interpretazione Risultati

### Risultato Atteso (✓ OK)

```
ESITO: ✓ OK - Totali coincidono
DIFF_COUNT: 0
AVG_DIFF: 0.00
MAX_DIFF: 0.00
```

Questo significa **nessuna regressione** - il nuovo algoritmo produce gli stessi risultati del vecchio.

### Risultato con Differenze (⚠️ DA ANALIZZARE)

```
ESITO: ✗ DIFFERENZA: 0.05 €
DIFF_COUNT: 3
AVG_DIFF: 0.02
MAX_DIFF: 0.05
```

Possibili cause:
1. **Arrotondamenti diversi** - Differenze < 0.01€ sono accettabili
2. **Bug nel vecchio algoritmo** - Il nuovo potrebbe aver corretto errori
3. **Bug nel nuovo algoritmo** - Da correggere
4. **Logica cambiata** - Verifica se intenzionale

## 🔍 Query Utili per Analisi

### Trovare Gare di Test

```sql
-- Gare Salto Ostacoli 2025 con dati calcolati
SELECT dg.sequ_id_dati_gara_esterna AS gara_id,
       dg.desc_nome_gara_esterna,
       dg.data_gara_esterna,
       COUNT(ce.fk_sequ_id_cavallo) AS num_cavalli
FROM tc_dati_gara_esterna dg
JOIN tc_dati_classifica_esterna ce
    ON ce.fk_sequ_id_dati_gara_esterna = dg.sequ_id_dati_gara_esterna
JOIN tc_dati_edizione_esterna ee
    ON ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
JOIN tc_edizione ed ON ed.sequ_id_edizione = ee.fk_sequ_id_edizione
JOIN tc_manifestazione mf ON mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
WHERE dg.data_gara_esterna LIKE '2025%'
  AND mf.fk_codi_disciplina = 4
  AND ce.importo_masaf_calcolato IS NOT NULL
GROUP BY dg.sequ_id_dati_gara_esterna, dg.desc_nome_gara_esterna, dg.data_gara_esterna
ORDER BY dg.data_gara_esterna;
```

### Verificare Risultati Test

```sql
-- Conta record in tc_test_snapshot
SELECT VERSIONE_ALGORITMO,
       COUNT(DISTINCT GARA_ID) AS num_gare,
       COUNT(*) AS num_record
FROM PVERTULLO.TC_TEST_SNAPSHOT
GROUP BY VERSIONE_ALGORITMO;
```

### Pulire Dati Test

```sql
-- Rimuovi test precedenti
DELETE FROM PVERTULLO.TC_TEST_SNAPSHOT
WHERE VERSIONE_ALGORITMO = 'V2.0-REFACTORED-2025';
COMMIT;
```

## 🐛 Troubleshooting

### Errore: "table or view does not exist"
- Verifica che `PVERTULLO.TC_TEST_SNAPSHOT` esista
- Verifica privilegi SELECT/INSERT sulla tabella

### Errore: "sequence does not exist"
- Esegui `02_setup_test_snapshot.sql` per creare la sequence

### Errore: "no data found"
- La gara specificata non ha dati calcolati con vecchio algoritmo
- Usa query "Trovare Gare di Test" per trovare gare valide

### Performance lenta su batch
- Normale per molte gare
- Considera di limitare il periodo (es. solo Gennaio 2025)
- Usa COMMIT ogni N gare (già implementato ogni 50)

## ✅ Checklist Test Completi

- [ ] Package compilato senza errori
- [ ] Sequence e tabella test verificate
- [ ] Test su almeno 3 gare diverse:
  - [ ] Gara CSIO Roma
  - [ ] Gara Finale Circuito Classico
  - [ ] Gara categoria SPORT/ELITE
- [ ] Nessuna differenza > 0.01€ trovata
- [ ] Test batch eseguito (se richiesto)
- [ ] Documentate eventuali differenze accettabili

## 📝 Note

- **Modalità Test**: `p_modalita_test => TRUE` inserisce in `tc_test_snapshot` senza modificare produzione
- **Anno**: Per ora solo 2025, quando disponibile 2026 usa `p_anno => 2026`
- **Commit**: Gli script fanno COMMIT automatico
- **Rollback**: In caso errore gli script fanno ROLLBACK automatico

## 🔄 Dopo Test Positivi

Una volta verificata la non-regressione:

1. Sostituisci il package in produzione
2. Aggiorna parametri 2026 quando disponibili
3. Ripeti test con `p_anno => 2026`
4. Documentazione finale

---

**Versione**: 2.0 - Refactored
**Data**: Gennaio 2026
**Discipline Completate**: Salto Ostacoli (1/6)
**Prossime**: Allevatoriale, Completo, Dressage, Endurance, Monta da Lavoro
