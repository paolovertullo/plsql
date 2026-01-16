CREATE OR REPLACE PACKAGE PVERTULLO.PKG_CALCOLI_PREMI_MANIFEST
AUTHID CURRENT_USER
AS
    TYPE t_premio_rec IS RECORD
    ( 
        cavallo_id      NUMBER,
        nome_cavallo    VARCHAR2 (100),
        premio          NUMBER,
        posizione       NUMBER,
        note            VARCHAR2 (500),
        vincite_fise    NUMBER
    );

    TYPE t_tabella_premi IS TABLE OF t_premio_rec;

    -- TYPE per TC_DATI_GARA_ESTERNA (sostituisce %ROWTYPE per compatibilita' privilegi)
    -- Definizione esplicita basata sulla struttura della tabella UNIRE_REL2.TC_DATI_GARA_ESTERNA
    TYPE t_dati_gara_rec IS RECORD (
        fk_sequ_id_dati_ediz_esterna      NUMBER(12),
        sequ_id_dati_gara_esterna         NUMBER(12),
        fk_sequ_id_gara_manifestazioni    NUMBER(12),
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
        flag_premio_masaf                 NUMBER(1),
        fk_sequ_id_documenti              NUMBER(12),
        fk_sequ_id_nomina_funzionario     NUMBER(12),
        desc_calcolo_premi                VARCHAR2(1500)
    );



    -- Restituisce una tabella premi per una gara specifica,
    -- determinando automaticamente la disciplina e richiamando l'handler corretto.
    FUNCTION FN_CALCOLO_PREMI_MANIFEST (p_gara_id IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    -- Simula il calcolo premi di una gara, senza salvarne l�esito.
    -- Utilizzato a scopo previsionale.
    FUNCTION FN_CALCOLO_PREMI_MANIFEST_SIM (p_gara_id        IN NUMBER,
                                            p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    -- Restituisce la descrizione di un codice tipologico.
    FUNCTION FN_DESC_TIPOLOGICA (p_codice IN NUMBER)
        RETURN VARCHAR2;

    -- Verifica se una gara � premiata dal MASAF.0 non � premiata 1 � premiata
    FUNCTION FN_GARA_PREMIATA_MASAF (p_id_gara_esterna IN NUMBER)
        RETURN NUMBER;

    FUNCTION FN_INCENTIVO_MASAF_GARA_FISE (p_id_gara_esterna IN NUMBER)
        RETURN NUMBER;

    FUNCTION FN_IS_CAVALLO_PREMIATO (p_id_classifica   IN NUMBER,
                                     p_id_gara         IN NUMBER,
                                     p_max_posizioni   IN NUMBER)
        RETURN BOOLEAN;

    FUNCTION FN_PREMIO_DISTRIBUZIONE_FISE (num_partiti          IN NUMBER,
                                           posizione            IN NUMBER,
                                           num_con_parimerito   IN NUMBER,
                                           montepremi           IN NUMBER)
        RETURN NUMBER;
   FUNCTION fn_premio_distribuzione_csio (posizione            IN NUMBER,
                                           num_con_parimerito   IN NUMBER,
                                           montepremi           IN NUMBER)
        RETURN NUMBER;
  FUNCTION FN_PREMIO_DISTR_TROFEO_COMPL (num_partiti          IN NUMBER,
                                           posizione            IN NUMBER,
                                           num_con_parimerito   IN NUMBER,
                                           montepremi           IN NUMBER)
        RETURN NUMBER;
  FUNCTION FN_PREMIO_DISTR_7_ALLEV (num_partiti          IN NUMBER,
                                           posizione            IN NUMBER,
                                           num_con_parimerito   IN NUMBER,
                                           montepremi           IN NUMBER)
        RETURN NUMBER;
 FUNCTION FN_PREMIO_DISTR_ENDURANCE (num_partiti          IN NUMBER,
                                           posizione            IN NUMBER,
                                           num_con_parimerito   IN NUMBER,
                                           montepremi           IN NUMBER)
        RETURN NUMBER;
    TYPE t_lista_posizioni IS TABLE OF NUMBER
        INDEX BY PLS_INTEGER;

    -- Record per singolo cavallo in classifica
    TYPE T_CLASSIFICA_ELEMENT IS RECORD
    (
        ID_CAVALLO    NUMBER,
        POSIZIONE     NUMBER,
        PUNTEGGIO     NUMBER,
        VINCITE_FISE  NUMBER,
        POSIZIONE_FISE NUMBER
    );

    -- Tabella indicizzata per la classifica completa
    TYPE T_CLASSIFICA IS TABLE OF T_CLASSIFICA_ELEMENT
        INDEX BY PLS_INTEGER;

    -- Record con fascia e premio assegnati
    TYPE T_PREMIO_ELEMENT IS RECORD
    (
        ID_CAVALLO    NUMBER,
        PREMIO        NUMBER,
        FASCIA        NUMBER
    );

    -- Mappatura finale dei premi
    TYPE T_MAPPATURA_PREMI IS TABLE OF T_PREMIO_ELEMENT
        INDEX BY PLS_INTEGER;

    ---------------------------------------------------------------------------
    -- SEZIONE PARAMETRI CONFIGURABILI PER ANNO
    ---------------------------------------------------------------------------
    -- Questa sezione contiene tutti i parametri che possono cambiare
    -- annualmente secondo il disciplinare MASAF
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- ANNO 2025 - PARAMETRI SALTO OSTACOLI
    ---------------------------------------------------------------------------

    -- CSIO ROMA - MASTER TALENT PIAZZA DI SIENA
    C_2025_SO_CSIO_7_FINALE        CONSTANT NUMBER := 5000;
    C_2025_SO_CSIO_7_PROVA         CONSTANT NUMBER := 3500;
    C_2025_SO_CSIO_6_FINALE        CONSTANT NUMBER := 4000;
    C_2025_SO_CSIO_6_PROVA         CONSTANT NUMBER := 2000;

    -- FINALE CIRCUITO CLASSICO - CRITERIUM
    C_2025_SO_CC_CRIT_4_FINALE     CONSTANT NUMBER := 3700;
    C_2025_SO_CC_CRIT_4_PROVA      CONSTANT NUMBER := 1300;
    C_2025_SO_CC_CRIT_5_FINALE     CONSTANT NUMBER := 3700;
    C_2025_SO_CC_CRIT_5_PROVA      CONSTANT NUMBER := 1300;
    C_2025_SO_CC_CRIT_67_FINALE    CONSTANT NUMBER := 3800;
    C_2025_SO_CC_CRIT_67_PROVA     CONSTANT NUMBER := 1300;
    C_2025_SO_CC_CRIT_7P_FINALE CONSTANT NUMBER := 3700;  -- 7+ anni
    C_2025_SO_CC_CRIT_7P_PROVA  CONSTANT NUMBER := 1300;  -- 7+ anni
    C_2025_SO_CC_CRIT_8_FINALE     CONSTANT NUMBER := 4000;
    C_2025_SO_CC_CRIT_8_PROVA      CONSTANT NUMBER := 2000;

    -- FINALE CIRCUITO CLASSICO - CAMPIONATO
    C_2025_SO_CC_CAMP_4_FINALE     CONSTANT NUMBER := 20000;
    C_2025_SO_CC_CAMP_4_PROVA      CONSTANT NUMBER := 10000;
    C_2025_SO_CC_CAMP_5_FINALE     CONSTANT NUMBER := 20000;
    C_2025_SO_CC_CAMP_5_PROVA      CONSTANT NUMBER := 12000;
    C_2025_SO_CC_CAMP_67_FINALE    CONSTANT NUMBER := 24000;
    C_2025_SO_CC_CAMP_67_PROVA     CONSTANT NUMBER := 8000;
    C_2025_SO_CC_CAMP_8_FINALE     CONSTANT NUMBER := 20000;
    C_2025_SO_CC_CAMP_8_PROVA      CONSTANT NUMBER := 8000;
    C_2025_SO_CC_CAMP_8_PROVA3     CONSTANT NUMBER := 10000;

    -- CATEGORIA SPORT
    C_2025_SO_SPORT_EURO_PART      CONSTANT NUMBER := 50;
    C_2025_SO_SPORT_MIN_PART       CONSTANT NUMBER := 6;

    -- CATEGORIA BREVETTO (7+ anni)
    C_2025_SO_BREVETTO_EURO_PART   CONSTANT NUMBER := 50;
    C_2025_SO_BREVETTO_MIN_PART    CONSTANT NUMBER := 6;

    -- CATEGORIA SELEZIONE - Montepremi fissi per età e giornata
    C_2025_SO_SEL_5_G1             CONSTANT NUMBER := 2000;
    C_2025_SO_SEL_5_G2             CONSTANT NUMBER := 2000;
    C_2025_SO_SEL_5_G3             CONSTANT NUMBER := 3500;
    C_2025_SO_SEL_6_G1             CONSTANT NUMBER := 2500;
    C_2025_SO_SEL_6_G2             CONSTANT NUMBER := 2500;
    C_2025_SO_SEL_6_G3             CONSTANT NUMBER := 4000;
    C_2025_SO_SEL_7_G1             CONSTANT NUMBER := 3000;
    C_2025_SO_SEL_7_G2             CONSTANT NUMBER := 3000;
    C_2025_SO_SEL_7_G3             CONSTANT NUMBER := 4500;

    -- CATEGORIA ELITE/ALTO - Euro per partente per età e periodo
    C_2025_SO_ELITE_4_P1           CONSTANT NUMBER := 135;
    C_2025_SO_ELITE_4_P2           CONSTANT NUMBER := 150;
    C_2025_SO_ELITE_5_P1           CONSTANT NUMBER := 135;
    C_2025_SO_ELITE_5_P2           CONSTANT NUMBER := 150;
    C_2025_SO_ELITE_MIN_PART       CONSTANT NUMBER := 6;

    -- CATEGORIA ELITE/ALTO 6 ANNI - Periodo 1
    C_2025_SO_ELITE_6_P1_G1_PART   CONSTANT NUMBER := 150;
    C_2025_SO_ELITE_6_P1_G2        CONSTANT NUMBER := 2400;
    C_2025_SO_ELITE_6_P1_G3        CONSTANT NUMBER := 3500;
    -- CATEGORIA ELITE/ALTO 6 ANNI - Periodo 2
    C_2025_SO_ELITE_6_P2_G2        CONSTANT NUMBER := 2900;
    C_2025_SO_ELITE_6_P2_G3        CONSTANT NUMBER := 4400;

    -- CATEGORIA ELITE/ALTO 7 ANNI - Periodo 1
    C_2025_SO_ELITE_7_P1_G3        CONSTANT NUMBER := 3800;
    C_2025_SO_ELITE_7_P1_G12       CONSTANT NUMBER := 2700;
    -- CATEGORIA ELITE/ALTO 7 ANNI - Periodo 2
    C_2025_SO_ELITE_7_P2_G3        CONSTANT NUMBER := 5000;
    C_2025_SO_ELITE_7_P2_G12       CONSTANT NUMBER := 3300;

    -- CAMPIONATO MONDO GIOVANI CAVALLI (LANAKEN)
    C_2025_SO_LANAKEN_CONTRIB      CONSTANT NUMBER := 2000;
    C_2025_SO_LANAKEN_FINALE_1     CONSTANT NUMBER := 6000;
    C_2025_SO_LANAKEN_FINALE_2_5   CONSTANT NUMBER := 3600;
    C_2025_SO_LANAKEN_FINALE_6_10  CONSTANT NUMBER := 2400;
    C_2025_SO_LNKN_FIN_OLTRE CONSTANT NUMBER := 2000;  -- Lanaken oltre 10°
    C_2025_SO_LANAKEN_QUAL_1       CONSTANT NUMBER := 1000;
    C_2025_SO_LANAKEN_QUAL_2_5     CONSTANT NUMBER := 600;
    C_2025_SO_LANAKEN_QUAL_6_10    CONSTANT NUMBER := 400;

    -- PERCENTUALI SPLIT GIUDIZIO/PRECISIONE
    C_2025_SO_PERC_SPORT_GIU       CONSTANT NUMBER := 1.0;   -- 100%
    C_2025_SO_PERC_SPORT_PREC      CONSTANT NUMBER := 0.0;   -- 0%
    C_2025_SO_PERC_ELITE4_GIU      CONSTANT NUMBER := 0.5;   -- 50%
    C_2025_SO_PERC_ELITE4_PREC     CONSTANT NUMBER := 0.5;   -- 50%
    C_2025_SO_PERC_ELITE5_GIU      CONSTANT NUMBER := 0.4;   -- 40%
    C_2025_SO_PERC_ELITE5_PREC     CONSTANT NUMBER := 0.6;   -- 60%

    -- INCENTIVO 10% FISE
    C_2025_SO_INCENTIVO_FISE_PERC  CONSTANT NUMBER := 0.1;   -- 10%

    -- PERCENTUALI DISTRIBUZIONE MASAF (uguali per tutti gli anni)
    C_MASAF_FASCIA_1_PERC          CONSTANT NUMBER := 0.5;   -- 50%
    C_MASAF_FASCIA_2_PERC          CONSTANT NUMBER := 0.3;   -- 30%
    C_MASAF_FASCIA_3_PERC          CONSTANT NUMBER := 0.2;   -- 20%

    ---------------------------------------------------------------------------
    -- ANNO 2026 - PARAMETRI SALTO OSTACOLI
    -- TODO: Popolare quando disponibili i nuovi valori del disciplinare 2026
    ---------------------------------------------------------------------------
    C_2026_SO_CSIO_7_FINALE        CONSTANT NUMBER := 5000;  -- DA AGGIORNARE
    C_2026_SO_CSIO_7_PROVA         CONSTANT NUMBER := 3500;  -- DA AGGIORNARE
    C_2026_SO_CSIO_6_FINALE        CONSTANT NUMBER := 4000;  -- DA AGGIORNARE
    C_2026_SO_CSIO_6_PROVA         CONSTANT NUMBER := 2000;  -- DA AGGIORNARE
    -- ... altri parametri 2026 da aggiungere quando disponibili

    ---------------------------------------------------------------------------
    -- FINE SEZIONE PARAMETRI CONFIGURABILI
    ---------------------------------------------------------------------------

    -- Procedure helper per MERGE in tc_test_snapshot (testing non regressione)
    PROCEDURE MERGE_TEST_SNAPSHOT(
        p_gara_id              IN NUMBER,
        p_disciplina_id        IN NUMBER,
        p_cavallo_id           IN NUMBER,
        p_nome_cavallo         IN VARCHAR2,
        p_posizione            IN NUMBER,
        p_premio_calcolato     IN NUMBER,
        p_note_calcolo         IN VARCHAR2,
        p_versione_algoritmo   IN VARCHAR2);

    PROCEDURE CALCOLA_FASCE_PREMIABILI_MASAF (
        p_classifica    IN     t_classifica,
        p_montepremi    IN     NUMBER,
        p_premiabili    IN     NUMBER,
        p_priorita_fasce_alte   in     boolean default false,
        -- false (default, salto ostacoli): riempi F3 � F2 � F1 (pochi partecipanti = fasce basse) true (allevatoriale): riempi F1 � F2 � F3 (pochi partecipanti = fasce alte)
        -- TRUE per allevatoriale perch� assegna F1 se 1 solo partecipante - F1 e F2 per due partecipanti, FALSE per salto ad ostacoli assegna F3 se 1 solo partecipante e F2 e F3 se 2 partecipanti
        p_mappa_premi      OUT t_mappatura_premi,
        p_desc_fasce OUT VARCHAR2);

    PROCEDURE FN_CALCOLA_MONTEPREMI_SALTO (
        p_dati_gara   IN t_dati_gara_rec,
        p_periodo     IN NUMBER,
        p_num_part    IN NUMBER,
        p_giornata    IN NUMBER,
        p_anno        IN NUMBER DEFAULT 2025,
        p_desc_calcolo_premio OUT varchar2,
        p_montepremi    OUT NUMBER)
        ;

    FUNCTION FN_CALCOLA_MONTEPREMI_ALLEV (
        p_dati_gara   IN t_dati_gara_rec,
        p_num_part    IN NUMBER)
        RETURN NUMBER;
        
    FUNCTION FN_CALCOLA_MONTEPREMI_COMPLETO (
        p_dati_gara   IN t_dati_gara_rec,
        p_num_part    IN NUMBER)
        RETURN NUMBER;

    PROCEDURE FN_CALCOLA_N_PREMIABILI_MASAF (
        p_dati_gara   IN t_dati_gara_rec,
        p_num_part    IN NUMBER,
        p_n_premiabili OUT NUMBER,
        p_desc_premiabili OUT VARCHAR2);
     --   RETURN NUMBER;

    FUNCTION FN_CONTA_PARIMERITO (
        p_dati_gara   IN t_dati_gara_rec,
        p_posizione   IN NUMBER)
        RETURN NUMBER;

    --aggiorna le fk di cavalli che hanno null nella tc_dati_classifica_esterna per una gara
    --� un fallback per casi di mancato riconoscimento
    PROCEDURE aggiorna_fk_cavallo_classifica (p_gara_id NUMBER);

    -- Ricava la disciplina associata ad una gara esterna.
    FUNCTION GET_DISCIPLINA (p_gara_id IN NUMBER)
        RETURN NUMBER;

    -- Restituisce tutte le informazioni associate ad una gara esterna.
    FUNCTION FN_INFO_GARA_ESTERNA (p_gara_id IN NUMBER)
        RETURN t_dati_gara_rec;

    TYPE tc_dati_gara_esterna_obj IS RECORD
    (
        fk_sequ_id_dati_ediz_esterna      NUMBER (12),
        sequ_id_dati_gara_esterna         NUMBER (12),
        fk_sequ_id_gara_manifestazioni    NUMBER (12),
        codi_gara_esterna                 VARCHAR2 (10),
        desc_nome_gara_esterna            VARCHAR2 (100),
        data_gara_esterna                 CHAR (8),
        desc_gruppo_categoria             VARCHAR2 (50),
        desc_codice_categoria             VARCHAR2 (50),
        desc_altezza_ostacoli             VARCHAR2 (50),
        flag_gran_premio                  NUMBER (1),
        codi_utente_inserimento           VARCHAR2 (20),
        dttm_inserimento                  DATE,
        codi_utente_aggiornamento         VARCHAR2 (20),
        dttm_aggiornamento                DATE,
        flag_prova_a_squadre              NUMBER (1),
        nume_mance                        NUMBER (2),
        codi_prontuario                   VARCHAR2 (50),
        nume_cavalli_italiani             VARCHAR2 (5),
        desc_formula                      VARCHAR2 (50),
        data_dressage                     VARCHAR2 (8),
        data_cross                        VARCHAR2 (8),
        fk_codi_categoria                 NUMBER,
        fk_codi_tipo_classifica           NUMBER,
        fk_codi_livello_cavallo           NUMBER,
        fk_codi_tipo_evento               NUMBER,
        fk_codi_tipo_prova                NUMBER,
        fk_codi_regola_sesso              NUMBER,
        fk_codi_regola_libro              NUMBER,
        fk_codi_eta                       NUMBER,
        flag_premio_masaf                 NUMBER (1)
    );

    -- TYPE tc_dati_gara_esterna_tbl
    --     IS TABLE OF UNIRE_REL2.TC_DATI_GARA_ESTERNA%ROWTYPE;


    FUNCTION FN_PERIODO_SALTO_OSTACOLI (p_data_gara VARCHAR2)
        RETURN NUMBER;


    -- Simulazioni premi per ciascuna disciplina MASAF.
    FUNCTION FN_CALCOLO_SALTO_OSTACOLI_SIM (p_gara_id        IN NUMBER,
                                            p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    FUNCTION FN_CALCOLO_DRESSAGE_SIM (p_gara_id        IN NUMBER,
                                      p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    FUNCTION FN_CALCOLO_ENDURANCE_SIM (p_gara_id        IN NUMBER,
                                       p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    FUNCTION FN_CALCOLO_ALLEVATORIALE_SIM (p_gara_id        IN NUMBER,
                                           p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    FUNCTION FN_CALCOLO_COMPLETO_SIM (p_gara_id        IN NUMBER,
                                      p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    FUNCTION FN_CALCOLO_MONTA_DA_LAVORO_SIM (p_gara_id        IN NUMBER,
                                             p_num_partenti   IN NUMBER)
        RETURN t_tabella_premi
        PIPELINED;

    -- Handler di calcolo premi per disciplina
    -- p_anno: Anno di riferimento (default 2025) - usa parametri specifici dell'anno
    -- p_modalita_test: Se TRUE inserisce in tc_test_snapshot, se FALSE aggiorna tc_dati_classifica_esterna (default FALSE)
    FUNCTION HANDLER_SALTO_OSTACOLI (p_gara_id IN NUMBER, p_anno IN NUMBER DEFAULT 2025, p_modalita_test IN BOOLEAN DEFAULT FALSE)
        RETURN t_tabella_premi;

    FUNCTION HANDLER_DRESSAGE (p_gara_id IN NUMBER, p_anno IN NUMBER DEFAULT 2025, p_modalita_test IN BOOLEAN DEFAULT FALSE)
        RETURN t_tabella_premi;

    FUNCTION HANDLER_ENDURANCE (p_gara_id IN NUMBER, p_anno IN NUMBER DEFAULT 2025, p_modalita_test IN BOOLEAN DEFAULT FALSE)
        RETURN t_tabella_premi;

    FUNCTION HANDLER_ALLEVATORIALE (p_gara_id IN NUMBER, p_anno IN NUMBER DEFAULT 2025, p_modalita_test IN BOOLEAN DEFAULT FALSE)
        RETURN t_tabella_premi;

    FUNCTION HANDLER_COMPLETO (p_gara_id IN NUMBER, p_anno IN NUMBER DEFAULT 2025, p_modalita_test IN BOOLEAN DEFAULT FALSE)
        RETURN t_tabella_premi;

    FUNCTION HANDLER_MONTA_DA_LAVORO (p_gara_id IN NUMBER, p_anno IN NUMBER DEFAULT 2025, p_modalita_test IN BOOLEAN DEFAULT FALSE)
        RETURN t_tabella_premi;

    -- Dispatcher principale: invoca il calcolo premi per la gara specificata
    -- e restituisce i premi in uscita in formato tabellare.
    --non dovrebbe servire piu' l'output dei risultati
    PROCEDURE ELABORA_PREMI_GARA (p_gara_id         IN     NUMBER,
                                  p_forza_elabora   IN     NUMBER,
                                  p_risultato          OUT VARCHAR2);

    --p_risultati OUT t_tabella_premi);

    -- Procedura per l'elaborazione dei premi FOALS per un intero anno.
    -- Gestisce la logica per l'accorpamento delle classifiche se necessario.
    PROCEDURE ELABORA_PREMI_FOALS_PER_ANNO (v_anno IN VARCHAR2);

    TYPE t_lista_cavalli IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    f1_ids   t_lista_cavalli;
    f2_ids   t_lista_cavalli;
    f3_ids   t_lista_cavalli;


    -- Procedure di calcolo premio per cavallo (per disciplina e anno)
    PROCEDURE CALCOLA_PREMIO_SALTO_OST_2025 (
        p_dati_gara                    IN     t_dati_gara_rec,
        p_posizione                    IN     NUMBER,
        p_SEQU_ID_CLASSIFICA_ESTERNA   IN     NUMBER,
        p_mappa_premi                  IN     PKG_CALCOLI_PREMI_MANIFEST.T_MAPPATURA_PREMI,
        p_premio_cavallo                  OUT NUMBER);
 

    PROCEDURE CALCOLA_PREMIO_ENDURANCE_2025 (
        p_dati_gara                    IN     t_dati_gara_rec,
        p_posizione                    IN     NUMBER,
        p_montepremi_tot               IN     NUMBER,
        p_num_con_parimerito           IN     NUMBER,
        p_SEQU_ID_CLASSIFICA_ESTERNA   IN     NUMBER,
        p_premio_cavallo                  OUT NUMBER);

--    PROCEDURE CALCOLA_PREMIO_DRESSAGE_2025  (
--    p_dati_gara                    IN     tc_dati_gara_esterna%rowtype,
--    p_posizione                    IN     NUMBER,
--    p_sequ_id_classifica_esterna   IN     NUMBER,
--    p_mappa_premi                  IN     PKG_CALCOLI_PREMI_MANIFEST.T_MAPPATURA_PREMI,  
--    p_premio_cavallo                  OUT NUMBER);

    PROCEDURE CALCOLA_PREMIO_ALLEV_2025 (
        p_dati_gara                    IN     t_dati_gara_rec,
        p_posizione                    IN     NUMBER,
        p_SEQU_ID_CLASSIFICA_ESTERNA   IN     NUMBER,
        p_mappa_premi                  IN     PKG_CALCOLI_PREMI_MANIFEST.T_MAPPATURA_PREMI,
        p_premio_cavallo                  OUT NUMBER);

    -- Calcola e registra i premi FOALS per una o due gare specifiche.
    -- Se il numero di partenti � insufficiente, gestisce la classifica unica.
    PROCEDURE CALCOLA_PREMIO_FOALS_2025 (
        p_id_gara_1   IN NUMBER,
        p_id_gara_2   IN NUMBER DEFAULT NULL);

    PROCEDURE CALCOLA_PREMIO_COMPLETO_2025 (
        p_dati_gara                    IN     t_dati_gara_rec,
        p_posizione                    IN     NUMBER,
        p_SEQU_ID_CLASSIFICA_ESTERNA   IN     NUMBER,
        p_mappa_premi                  IN     PKG_CALCOLI_PREMI_MANIFEST.T_MAPPATURA_PREMI,
        p_premio_cavallo                  OUT NUMBER);
 

    PROCEDURE CALCOLA_PREMIO_MONTA_2025 (
        p_dati_gara                    IN     t_dati_gara_rec,
        p_posizione                    IN     NUMBER,
        p_tot_partenti                 IN     NUMBER,
        p_num_con_parimerito           IN     NUMBER,
        p_SEQU_ID_CLASSIFICA_ESTERNA   IN     NUMBER,
        p_premio_cavallo                  OUT NUMBER);
        
 -------------------------------------------------------------------------------
 -------------------------------------------------------------------------------
 --     Procedure per le premi aggiunti o incentivi 
 -------------------------------------------------------------------------------
 -------------------------------------------------------------------------------
      
  PROCEDURE ELABORA_INCENTIVO_10_FISE  (
        p_edizione_id  IN NUMBER DEFAULT NULL,
    p_anno         IN NUMBER,
    p_risultato    OUT VARCHAR2);
 
    PROCEDURE    VALIDA_EDIZ_CON_INCENTIVI_10 (
    p_anno         IN NUMBER,
    p_risultato    OUT VARCHAR2
);
 -------------------------------------------------------------------------------
 -------------------------------------------------------------------------------
 --     Procedure per le classifiche di accesso alle finali 
 -------------------------------------------------------------------------------
 -------------------------------------------------------------------------------
--     TYPE t_premio_rec IS RECORD
--    (
--        cavallo_id      NUMBER,
--        nome_cavallo    VARCHAR2 (100),
--        premio          NUMBER,
--        posizione       NUMBER,
--        note            VARCHAR2 (500)
--    );
--
--    TYPE t_tabella_premi IS TABLE OF t_premio_rec;
--
--
--
--    -- Restituisce una tabella premi per una gara specifica,
--    -- determinando automaticamente la disciplina e richiamando l'handler corretto.
--    FUNCTION FN_CALCOLO_PREMI_MANIFEST (p_gara_id IN NUMBER)
--        RETURN t_tabella_premi
--        PIPELINED;
        
        
 TYPE t_endurance_row IS RECORD (
  cavallo_id            NUMBER,
  anno_nascita          NUMBER,
  categoria             VARCHAR2(10),
  num_partecipazioni    NUMBER,
  totale_punti          NUMBER,
  esito_controlli       NUMBER,
  esito_partecipazione  NUMBER
);

TYPE t_endurance_tab IS TABLE OF t_endurance_row;

FUNCTION get_endurance_classifica(
  p_anno IN NUMBER
) RETURN t_endurance_tab PIPELINED;
        
        
        
        
END PKG_CALCOLI_PREMI_MANIFEST;
/