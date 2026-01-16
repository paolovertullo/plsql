CREATE OR REPLACE package body UNIRE_REL2.pkg_calcoli_premi_manifest 
as
    -- VERSIONE 0.3.1 del 29/10/2025 
    --      Rinfozo i calcoli con i dati forniti dai comitati per tutte le discipline inizio con Allevatoriale
    -- 
    --
    -- TODO: Dressage, Monta da lavoro, Endurance fare test approfonditi di distribuzione premi.
    -- TODO: Tutte le simulazioni sono vuote attualmente perchè le firma dei calcola sono tutte cambiate.
    -- TODO: La funzione che dice se ci sono incentivi va rivista profondamente.

    c_debug        constant boolean := true;
    c_debug_info   constant boolean := false; 

    -- metti TRUE se vuoi il debug attivo

    function fn_calcolo_premi_manifest (p_gara_id in number)
        return t_tabella_premi
        pipelined
    is
        l_risultati   t_tabella_premi;
        v_dummy       number;
        v_rec         unire_rel2.pkg_calcoli_premi_manifest.t_premio_rec;
    begin
        -- Questo metodo è richiamato come API dal BackEnd  NON PUO FARE UPDATE

        --   inserisco la logica che se non ci sono i risultati in nume_piazzamento allora restituisco la SIM
        --         se ci sono prendo piazzamento e il dato premio_masaf se è valorizzato
        --        se non è valorizzato allora due strade o chiamo il popola premio_masaf oppure lo calcolo con handler
        -- Prova a selezionare se esiste almeno un NUME_PIAZZAMENTO NULL

        v_dummy := fn_gara_premiata_masaf (p_gara_id);

        dbms_output.put_line (
            '---  FN_CALCOLO_PREMI_MANIFEST ---' || v_dummy || '---');

        if v_dummy = 0
        then
            v_rec.cavallo_id := -1;
            v_rec.nome_cavallo := 'Gara non premiata da MASAF.';
            v_rec.posizione := -1;
            v_rec.note := 'Gara non premiata da MASAF.';
            v_rec.premio := -1;

            pipe row (v_rec);

            return;
        end if;


        begin
            select 1
              into v_dummy
              from tc_dati_classifica_esterna
             where     fk_sequ_id_dati_gara_esterna = p_gara_id
                   and nume_piazzamento is null
                   and rownum = 1;

            -- Se trovi almeno un risultato a null, fai vedere la simulazione
            --perchè classifica non ultimata
            for rec
                in (select *
                      from table (
                               fn_calcolo_premi_manifest_sim (p_gara_id, 10)))
            loop
                pipe row (rec);
            end loop;

            return;
        exception
            when no_data_found
            then
                null;               -- Nessun piazzamento NULL, non fare nulla
        end;

        l_risultati := t_tabella_premi ();

        for rec in (select fk_sequ_id_cavallo          as cavallo_id,
                           upper (desc_cavallo)        as nome_cavallo,
                           nume_piazzamento            as posizione,
                           ''                          as note,
                           importo_masaf_calcolato     as premio
                      from tc_dati_classifica_esterna
                     where fk_sequ_id_dati_gara_esterna = p_gara_id)
        loop
            v_rec.cavallo_id := rec.cavallo_id;
            v_rec.nome_cavallo := rec.nome_cavallo;
            v_rec.posizione := rec.posizione;
            v_rec.note := rec.note;
            v_rec.premio := rec.premio;

            v_rec.nome_cavallo :=
                   rec.nome_cavallo
                || case
                       when rec.premio is null and rec.cavallo_id is null
                       then
                           '   --- [CAVALLO NON MASAF] ---'
                       when rec.premio is null
                       then
                           ' [PREMIO DA ELABORARE]'
                       else
                           ''
                   end;



            l_risultati.extend;
            l_risultati (l_risultati.count) := v_rec;
        end loop;

        for i in 1 .. l_risultati.count
        loop
            pipe row (l_risultati (i));
        end loop;

        return;
    end;



    function fn_calcolo_premi_manifest_sim (p_gara_id        in number,
                                            p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        --  l_risultati    t_tabella_premi := t_tabella_premi ();
        v_disciplina   varchar2 (50);
    begin
        -- Questo metodo è richiamato come API dal BackEnd

        -- Recupero la disciplina della gara
        v_disciplina := get_disciplina (p_gara_id);

        -- Dispatch verso l¿handler della disciplina corretta
        case v_disciplina
            when 4
            then
                for rec
                    in (select *
                          from table (
                                   fn_calcolo_salto_ostacoli_sim (
                                       p_gara_id,
                                       p_num_partenti)))
                loop
                    pipe row (rec);
                end loop;
            when 2
            then
                for rec
                    in (select *
                          from table (
                                   fn_calcolo_endurance_sim (p_gara_id,
                                                             p_num_partenti)))
                loop
                    pipe row (rec);
                end loop;
            when 6
            then
                for rec
                    in (select *
                          from table (
                                   fn_calcolo_dressage_sim (p_gara_id,
                                                            p_num_partenti)))
                loop
                    pipe row (rec);
                end loop;
            when 1
            then
                for rec
                    in (select *
                          from table (
                                   fn_calcolo_allevatoriale_sim (
                                       p_gara_id,
                                       p_num_partenti)))
                loop
                    pipe row (rec);
                end loop;
            when 3
            then
                for rec
                    in (select *
                          from table (
                                   fn_calcolo_completo_sim (p_gara_id,
                                                            p_num_partenti)))
                loop
                    pipe row (rec);
                end loop;
            when 7
            then
                for rec
                    in (select *
                          from table (
                                   fn_calcolo_monta_da_lavoro_sim (
                                       p_gara_id,
                                       p_num_partenti)))
                loop
                    pipe row (rec);
                end loop;
            else
                raise_application_error (
                    -20001,
                    'Disciplina non gestita: ' || v_disciplina);
        end case;

        return;
    end;

    function fn_desc_tipologica (p_codice in number)
        return varchar2
    is
        v_descrizione   varchar2 (200);
    begin
        select descrizione
          into v_descrizione
          from td_manifestazione_tipologiche
         where id = p_codice;

        return v_descrizione;
    exception
        when no_data_found
        then
            return null;          --'Codice sconosciuto (' || p_codice || ')';
    end;


    function fn_gara_premiata_masaf (p_id_gara_esterna in number)
        return number
    is
        v_dati_gara               tc_dati_gara_esterna%rowtype;
        v_disciplina_id           number;
        v_categoria_desc          varchar2 (255);
        v_nome_gara               tc_dati_gara_esterna.desc_nome_gara_esterna%type; -- Usiamo direttamente il campo della vista
        v_nome_manifestazione     varchar2 (255);
        v_nome_edizione     varchar2 (255);
        l_eta_cavalli             number;                -- Per l'età numerica
        l_desc_formula            varchar2 (50);
        v_formula                 varchar2 (50);    -- valore della formula nel file access
        l_debug_disciplina_desc   varchar2 (100);
        l_premiata                pls_integer := 0;
        v_data_inizio varchar2(8);
        v_data_fine varchar2(8);
        v_giornata_gara number;
        v_giornate_edizione number;
    begin
        v_dati_gara := fn_info_gara_esterna (p_id_gara_esterna);

        -- Recupero riga dalla tabella gara_esterna
        select upper (mf.desc_denom_manifestazione), upper (mf.desc_formula),upper(ee.desc_denom_edizione),ed.DATA_INIZIO_EDIZIONE,ed.DATA_FINE_EDIZIONE,(TO_DATE(dg.DATA_GARA_ESTERNA, 'YYYYMMDD') - TO_DATE(ed.DATA_INIZIO_EDIZIONE, 'YYYYMMDD')) + 1 AS GIORNATA_GARA, (TO_DATE(ed.DATA_FINE_EDIZIONE, 'YYYYMMDD') - TO_DATE(ed.DATA_INIZIO_EDIZIONE, 'YYYYMMDD')+1),dg.desc_formula
          into v_nome_manifestazione, l_desc_formula,v_nome_edizione,v_data_inizio,v_data_fine,v_giornata_gara,v_giornate_edizione,v_formula
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_id_gara_esterna;

--        if c_debug then
--            dbms_output.put_line ('---  fn_gara_premiata_masaf --- l_desc_formula=' || l_desc_formula || '---');
--            dbms_output.put_line ('---  fn_gara_premiata_masaf --- v_formula=' || v_formula || '---');
--            dbms_output.put_line ('---  fn_gara_premiata_masaf --- p_id_gara_esterna=' || p_id_gara_esterna || '---');
--        end if;
--        
        v_disciplina_id := get_disciplina (p_id_gara_esterna);
        v_nome_gara := upper (v_dati_gara.desc_nome_gara_esterna);

        if v_dati_gara.fk_codi_eta is not null
        then
            l_eta_cavalli :=
                to_number (
                    substr (fn_desc_tipologica (v_dati_gara.fk_codi_eta),
                            0,
                            1));
        else
            l_eta_cavalli :=
                case
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '1 ANNO') >
                         0                   -- Aggiunto prima per specificità
                    then
                        1
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '2 ANNI') >
                         0                   -- Aggiunto prima per specificità
                    then
                        2
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '3 ANNI') >
                         0                                              --ANNI
                    then
                        3
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '4 ANNI') >
                         0                                              --ANNI
                    then
                        4
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '5 ANNI') >
                         0                                              --ANNI
                    then
                        5
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '6 ANNI') >
                         0                                              --ANNI
                    then
                        6
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                '7 ANNI') >
                         0                                              --ANNI
                    then
                        7
                    else
                        null
                end;
        end if;


        if v_dati_gara.fk_codi_categoria is not null
        then
            v_categoria_desc :=
                upper (fn_desc_tipologica (v_dati_gara.fk_codi_categoria));
        else
            v_categoria_desc :=
                case
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                'ELITE') >
                         0                                              --ANNI
                    then
                        'ELITE'
                    when instr (upper (v_dati_gara.desc_nome_gara_esterna),
                                'SPORT') >
                         0                                              --ANNI
                    then
                        'SPORT'
                    else
                        null
                end;
        end if;


--if c_debug then
--dbms_output.put_line ('---  fn_gara_premiata_masaf --- v_disciplina_id=' || v_disciplina_id || '---');
--dbms_output.put_line ('---  fn_gara_premiata_masaf --- v_nome_manifestazione=' || v_nome_manifestazione || '---');
--dbms_output.put_line ('---  fn_gara_premiata_masaf --- v_nome_gara=' || v_nome_gara || '---');
--dbms_output.put_line ('---  fn_gara_premiata_masaf --- l_eta_cavalli=' || l_eta_cavalli || '---');
--end if;

        case v_disciplina_id
            when 1           --ALLEVATORIALE
            then
                l_debug_disciplina_desc := 'Circuito Allevatoriale';
                l_premiata := 0;
                -- dbms_output.put_line ('---  FN_CALCOLO_PREMIATA ---' || v_nome_manifestazione || '---');
                --dbms_output.put_line ('---  FN_CALCOLO_PREMIATA ---' || v_nome_gara || '---');
                
                -- REGOLA 1: Finali Nazionali Circuito Allevatoriale (Fieracavalli Verona)
                if    upper (v_nome_manifestazione) like '%FINALE%NAZIONALE%' --FIERACAVLLI VERONA
                then
                    if        upper (v_nome_gara) like '%OBBEDIENZA%'
                          and upper (v_nome_gara) like '%ANDATURE%'
                       or     upper (v_nome_gara) like '%MORFO%'
                       or     upper (v_nome_gara) like '%SALTO IN%'
                       or  upper (v_nome_gara) like 'PROVA%ATTITUDINE%AL%SALTO%'
                       or (upper (v_nome_gara) like
                              '%CLASSIFICA%' 
                              and upper (v_nome_gara) like
                              '%FINALE%' 
                              and upper (v_nome_gara) like
                              '%SALTO IN%' )
                       or upper (v_nome_gara) like '%COMBINATA%'
                    then
                        l_premiata := 1;
                    end if;
                    
                    if upper (v_nome_gara) like 'PRIMA%PROVA%'
                    or upper (v_nome_gara) like 'SECONDA%PROVA%'
                    then
                        l_premiata := 0;
                    end if;

                end if;

                -- REGOLA 2: PREMI REGIONALI ED INTERREGIONALI
                if     l_premiata = 0
                   and (   upper (v_nome_manifestazione) like
                               '%REGIONAL%'
                        or upper (v_nome_manifestazione) like
                               '%REG%'
                        or upper (v_nome_manifestazione) like
                               '%INTERREGIONAL%')
                then
                    if   v_nome_gara like '%MORFO%'
                          or     v_nome_gara like '%ATTITUDIN%'
                             or     v_nome_gara like '%OBBEDIENZA%'
                               or    ( v_nome_gara like '%COMBINATA%' and v_nome_gara not like ('%CLASSIFICA DI COMBINATA%') )
                               or (    v_nome_gara like '%SALTO IN%'
                           and v_nome_gara like '%CLASSIFICA%' and v_nome_gara like '%FINALE%' )
                    then
                        l_premiata := 1;
                    end if;
                end if;

                -- REGOLA 3: RASSEGNE FOALS
                if     l_premiata = 0
                   and upper (v_nome_manifestazione) like '%FOALS%'
                then
                    if    v_nome_gara like '%MORFO%'
                       or v_nome_gara like '%FOALS%'
                    then
                        l_premiata := 1;
                    end if;
                end if;

                -- REGOLA 4: TAPPE DI PREPARAZIONE
                if     l_premiata = 0
                   and upper (v_nome_manifestazione) like '%TAPP%' 
                   and upper (v_nome_manifestazione) not like
                           '%RASSEGNA FOALS%'
                then
                    --dbms_output.put_line ('---  FN_CALCOLO_PREMIATA --- REGOLA 4: TAPPE DI PREPARAZIONE ---');
                    if v_nome_gara like '%MORFO%'
                       or v_nome_gara like '%OBBEDIENZA%'
                       or (    upper(v_nome_gara) like '%SALTO IN%'
                           and upper (v_nome_gara) like '%CLASSIFICA%' and upper (v_nome_gara) like '%FINALE%' )
                    then
                        l_premiata := 1;
                    end if;
                end if;

                --REGOLE DI ESCLUSIONE
                if     v_nome_gara like '%QUALIFICA%' or v_nome_gara like '%LIBERE %' or v_nome_gara like '%LIBERA %' or v_nome_gara like '%PUNTEGGI%'
                then
                    l_premiata := 0;
                end if;
                
               
                
               
                
                
            when 2           --ENDURANCE
            then
                l_debug_disciplina_desc := 'Endurance';
                l_premiata := 0;                 -- Inizializza a non premiata
                v_nome_manifestazione:= upper (trim (v_nome_manifestazione));

                if (v_nome_manifestazione like '%CAMPIONATO%ENDURANCE%7%8%ANNI%' or v_nome_manifestazione like '%FINALE%ENDURANCE%') AND v_nome_edizione not like '%TAPPA%' then
                            l_premiata := 1;
                            
                end if;
                        
            
            when 3           -- COMPLETO
            then
                l_debug_disciplina_desc := 'Concorso Completo';
                l_premiata := 0;                 -- Inizializza a non premiata


                v_nome_manifestazione := upper (trim (v_nome_manifestazione));
                v_nome_gara := upper (trim (v_nome_gara));

                -- REGOLA 1: MANIFESTAZIONI "CAMPIONATO 6 ANNI DI COMPLETO" e "CAMPIONATO 7 ANNI DI COMPLETO"
                -- Queste manifestazioni sono le finali per le rispettive età e sono premiate MASAF.
                -- Assumiamo che le gare all'interno di queste manifestazioni specifiche per quell'età siano quelle del campionato.
                if v_nome_manifestazione like '%CAMPIONATO%ANNI%'
                then
                        if v_nome_gara like '%CAMPIONATO%MASAF%ANNI%' 
                        then
                            l_premiata := 1;
                        end if;
                end if;

                -- REGOLA 2: MANIFESTAZIONE "FINALE CIRCUITO MASAF DI COMPLETO" (per 4 e 5 anni)
                if     l_premiata = 0
                   and v_nome_manifestazione =
                       'FINALE CIRCUITO MASAF DI COMPLETO'
                then
                    if     (   v_nome_gara like 'FINALE%'
                            or v_nome_gara like '%SPORT%'
                            or v_nome_gara like '%ELITE%')
                       and v_nome_gara not like '%FISE%'
                    then
                        l_premiata := 1;
                    end if;
                end if;

                -- REGOLA 3: MANIFESTAZIONE "TROFEO DEL CAVALLO ITALIANO" (Finale del Trofeo)
                if     l_premiata = 0
                   and v_nome_manifestazione = 'TROFEO DEL CAVALLO ITALIANO'
                then
                    -- Il montepremi MASAF è per la *Finale* del Trofeo (pag. 12).
                    -- Non sono specificate categorie di età o livello per il premio della finale del Trofeo,
                    -- si presume che la gara sia la "finale" stessa.
                    -- Se ci sono più gare in una manifestazione "TROFEO DEL CAVALLO ITALIANO",
                    -- dovremmo identificare quale è effettivamente la "FINALE" del Trofeo.
                    -- Per ora, se la manifestazione ha questo nome, assumiamo che la gara sia la finale premiata.
                    -- Un controllo su v_nome_gara LIKE '%FINALE%' potrebbe essere utile se non tutte le gare
                    -- di questa manifestazione sono la finale.
                    if    v_nome_gara like '%FINALE%'
                       or v_nome_gara like '%TROFEO%'
                    then       -- Aggiunto per essere più specifici sulla gara
                        l_premiata := 1;
                    end if;
                end if;

                -- REGOLA 4: MANIFESTAZIONE "CIRCUITO MASAF COMPLETO" (Tappe per 4 e 5 anni)
                if     l_premiata = 0
                   and v_nome_manifestazione = 'CIRCUITO MASAF COMPLETO'
                then
                    -- Le tappe del circuito sono per cavalli di 4 e 5 anni (pag. 7 disciplinare)
                    -- e "ogni categoria avrà un Montepremi".
                    if l_eta_cavalli in (4, 5) or v_nome_gara like 'MASAF%'
                    then
                        -- Non c'è distinzione sport/élite per il premio di tappa nel disciplinare a pag. 7.
                        -- Quindi, se l'età è 4 o 5, è una tappa premiata.
                        l_premiata := 1;
                    end if;
                end if;

                -- REGOLA 5: MANIFESTAZIONE "CAMPIONATO DEL MONDO"
                if v_nome_manifestazione like 'CAMPIONATO%DEL%MONDO%'
                then
                    l_premiata := 1; --sempre premiate perchè inserisco nel file csv solo quelle a premio
                end if;

                if v_nome_gara like '%FISE%'
                then
                    l_premiata := 0;
                end if;
            when 4           -- SALTO OSTACOLI
            then      
                l_debug_disciplina_desc := 'Salto Ostacoli';

                -- REGOLA 0: Esclusione gare WARM UP (percorsi addestrativi)
                if upper (v_nome_gara) like '%WARM%UP%'
                   or upper (v_nome_gara) like 'WARM UP%'
                   or upper (v_nome_gara) like '%WARM-UP%'
                   or upper (v_nome_gara) like '%WAR%UP%'
                   or upper (v_nome_gara) like '%AMBIENTAMENTO%'
                   or upper (v_nome_gara) like '%ADDESTRA%'
                then
                    l_premiata := 0;
                    return l_premiata;
                end if;

                -- REGOLA 1: Gare del CIRCUITO CLASSICO MASAF con categorie premiate
                if upper (v_nome_manifestazione) like '%CIRCUITO CLASSICO MASAF%'
                then
                    -- Gare ELITE: premiati 4-7 anni
                    if     v_categoria_desc = 'ELITE'
                       and l_eta_cavalli between 4 and 7
                    then
                        l_premiata := 1;
                    -- Gare ALTO LIVELLO: premiati 5-7 anni
                    elsif     v_categoria_desc = 'ALTO'
                          and l_eta_cavalli between 5 and 7
                    then
                        l_premiata := 1;
                    -- Gare SELEZIONE: premiati 5-7 anni
                    elsif     v_categoria_desc = 'SELEZIONE'
                          and l_eta_cavalli between 5 and 7
                    then
                        l_premiata := 1;
                    elsif     v_categoria_desc = 'SPORT'
                          and l_eta_cavalli = 4
                          and instr (upper (v_nome_gara), 'GIUDIZIO') > 0
                    then
                        l_premiata := 1;
                    -- Gare SPORT: premiati 5 anni e oltre (secondo disciplinare, pagina 16)
                    elsif     v_categoria_desc = 'SPORT'
                          and l_eta_cavalli = 5
                          and instr (upper (v_nome_gara), 'PRECISIONE') > 0
                    then
                        l_premiata := 0;
                    elsif     v_categoria_desc = 'SPORT'
                          and l_eta_cavalli = 5
                          and instr (upper (v_nome_gara), 'GIUDIZIO') > 0
                    then
                        l_premiata := 1;
                    elsif     v_categoria_desc = 'SPORT'
                          and l_eta_cavalli = 6
                          and instr (upper (v_nome_gara), 'PRECISIONE') > 0
                    then
                        l_premiata := 1;
                    elsif     v_categoria_desc = 'SPORT'
                          and l_eta_cavalli in (6, 7)
                          and instr (upper (v_nome_gara), 'TEMPO') > 0
                    then
                        l_premiata := 1;
                    elsif     v_categoria_desc = 'SPORT'
                          and l_eta_cavalli = 7
                          and instr (upper (v_nome_gara), 'MISTA') > 0
                    then
                        l_premiata := 1;
                    elsif     v_categoria_desc = 'SPORT'
                          and instr (upper (v_nome_gara), 'C 1') > 0
                    then
                        l_premiata := 0;
                    elsif     v_categoria_desc = 'SPORT'
                          --and l_eta_cavalli = 7    --7 anni e oltre 
                          and instr (upper (v_nome_gara), ' FASI ') > 0
                    then
                        l_premiata := 1;
                    end if;
                end if;


                -- REGOLA 2: Finali del CIRCUITO CLASSICO (Campionati e Criterium)
                if     l_premiata = 0
                   and upper (v_nome_manifestazione) like
                           'FINALE%CIRCUITO%CLASSICO'
                then
                    if upper (v_nome_gara) like '%WARM%' or upper (v_nome_gara) like '%AMBIENTAMENTO%'  
                    then
                        l_premiata := 0;
                    elsif    instr (upper (v_nome_gara), 'CAMPIONATO') > 0
                          or instr (upper (v_nome_gara), 'CRITERIUM') > 0
                          or instr (upper (v_nome_gara), '^ P') > 0
                           or instr (upper (v_nome_gara), 'FINALE') > 0
                    then
                        l_premiata := 1;
                    end if;
                end if;


                -- REGOLA 3: CSIO Roma / Piazza di Siena ¿ Master Talent 6-7 anni
                if     l_premiata = 0
                   and (   upper (v_nome_manifestazione) like '%CSIO ROMA%'
                        or upper (v_nome_manifestazione) like
                               '%PIAZZA DI SIENA%')
                then
                
                    if (upper (v_nome_gara) like '%PROVA%ANNI%MASAF%' or upper (v_nome_gara) like '%FINALE%ANNI%MASAF%' )and upper (v_nome_gara) not like '%FISE%' then
                         l_premiata := 1;
                    else
                         l_premiata := 0;
                    end if;
                    
--                    if l_eta_cavalli in (6, 7)
--                    then
--                        l_premiata := 1;
--                    end if;
                end if;
                
                -- REGOLA 4: CAMPIONATO DEL MONDO CAVALLI GIOVANI 
                if     l_premiata = 0
                   and upper (v_nome_manifestazione) like
                           '%CAMPIONATO%MONDO%GIOVANI%'
                then
                    -- tutte le gare inserite sono le sole a premio MASAF
                        l_premiata := 1;
                end if;

                -- REGOLA 5: ESCLUDI LE GARE CHE HANNO NEL NOME SOLAMENTE FISE
                if     l_premiata = 1
                   and instr (upper (v_nome_gara), 'FISE') > 0 and upper (v_nome_gara) not like '%MASAF%'
                then
                        l_premiata := 0;
                end if;

                -- IMPLEMENTO l'USO DELLA TIPOLOGICA DELLA FISE NEL FILE ACCESS
                -- REGOLA 6: ESCLUDI LE GARE CHE HANNO FORMULA 'AGGI'  perchè nel file access sono le gare aggiunte non da premiare
                if  v_formula = 'AGGI'
                then
                        l_premiata := 0;
                end if;
                if  v_formula = 'MAS2' and l_premiata = 0
                then
                        l_premiata := 1;
                end if;
                if  v_formula = 'MAS2' and l_eta_cavalli in (4,5) and instr (upper (v_nome_gara), 'PRECISIONE') > 0 and v_categoria_desc = 'SPORT'
                then
                        l_premiata := 0;
                end if;
                
                
            when 6           -- DRESSAGE
            then
                l_debug_disciplina_desc := 'Dressage';
                l_premiata := 0;
                
--                if c_debug then 
--                    DBMS_OUTPUT.PUT_LINE('--- DEBUG DRESSAGE ---');
--                    DBMS_OUTPUT.PUT_LINE('--- v_nome_manifestazione: ' || v_nome_manifestazione);
--                    DBMS_OUTPUT.PUT_LINE('--- v_nome_gara: ' || v_nome_gara);
--                    DBMS_OUTPUT.PUT_LINE('--- l_eta_cavalli: ' || l_eta_cavalli);
--                    DBMS_OUTPUT.PUT_LINE('--- v_giornata_gara: ' || v_giornata_gara);
--                    DBMS_OUTPUT.PUT_LINE('--- v_giornate_edizione: ' || v_giornate_edizione);
--                end if;
                
                declare
                    v_nome_manifest_norm varchar2(255) := upper(trim(v_nome_manifestazione));
                begin
                    -- TAPPE: solo seconda giornata ma dipende da quanti giorni sono l'edizione v_giornate_edizione puo' valere 3 o 2 e v_giornata_gara puo valere 1,2,3 
                    if v_nome_manifest_norm like '%MASAF%DRESSAGE%' and v_giornate_edizione-v_giornata_gara = 0 then
                        if v_nome_gara like '%MASAF%' then
                            l_premiata := 1;
                        end if;
                        --5 ANNI FINAL MASAF 2° GIORNATA che in realtà è in giornata 2 di tre quindi sarebbe prima giornata
                    elsif v_nome_manifest_norm like '%MASAF%DRESSAGE%' and v_nome_gara like '%FINAL%MASAF%' then
                        l_premiata := 1;
                    end if;
                    
                    -- REGOLA : nel caso nel nome ci sia indicata la gioranta posso usare quella come informazione
                    if     l_premiata = 0
                        and upper (v_nome_gara) like  '%MASAF%2°%'
                    then
                            l_premiata := 1;
                    end if;
                    
                    -- FINALI: entrambe le giornate (campionato)
                    if v_nome_manifest_norm like 'FINALE%CIRCUITO%DRESSAGE%' then
                    
                        if v_nome_gara like '%FINALE%ANNI%MASAF%' then
                            l_premiata := 1;
                         else 
                            l_premiata := 0;                         
                        end if;

                    end if;
                    
                    
                    
                    
                    -- ESCLUSIONE: Campionato del Mondo
                    if v_nome_manifest_norm like '%CAMPIONATO DEL MONDO%' or v_nome_manifest_norm like '%VERDEN%' then
                        l_premiata := 0;
                    end if;
                end;
            when 7           -- MONTA DA LAVORO
            then
                l_debug_disciplina_desc := 'Monta da Lavoro';
                l_premiata := 0;                 -- Inizializza a non premiata

                declare
                    v_nome_manifest_normalizzato   varchar2 (255)
                        := upper (trim (v_nome_manifestazione));
                    v_nome_gara_normalizzato       varchar2 (255)
                                                       := v_nome_gara; -- v_nome_gara è già UPPER nella procedura principale
                begin
                    -- Controlla se la manifestazione è una Tappa o la Finale del Circuito Monta da Lavoro
                    if    v_nome_manifest_normalizzato =
                          'CIRCUITO MONTA DA LAVORO'
                       or v_nome_manifest_normalizzato =
                          'FINALE CIRCUITO MONTA DA LAVORO'
                    then
                        -- Ora controlla se la categoria della gara è una di quelle premiate MASAF
                        -- Utilizziamo i nomi che hai fornito e li mappiamo alle categorie del disciplinare
                        if    v_nome_gara_normalizzato like '%ESORDIENTI%'
                           or v_nome_gara_normalizzato = 'CATEGORIA 1'
                           or                                         -- Cat.1
                              v_nome_gara_normalizzato = 'DEBUTTANTI'
                           or v_nome_gara_normalizzato = 'CATEGORIA 2'
                           or                                         -- Cat.2
                              v_nome_gara_normalizzato = 'AMATORI'
                           or v_nome_gara_normalizzato = 'CATEGORIA 3'
                           or                                         -- Cat.3
                              v_nome_gara_normalizzato = 'JUNIORES'
                           or v_nome_gara_normalizzato = 'CATEGORIA 4'
                           or                                         -- Cat.4
                              v_nome_gara_normalizzato = 'OPEN' -- Cat.5 
                              or v_nome_gara_normalizzato = 'CATEGORIA 5'
                        then
                            l_premiata := 1;
                        end if;
                    end if;
                end;                                    -- Fine blocco declare
            else
                l_debug_disciplina_desc :=
                    'ID Sconosciuto ' || to_char (v_disciplina_id);
                l_premiata := 0;
        end case;


        if v_dati_gara.fk_codi_tipo_classifica = 77
        then
            l_premiata := 0;  -- Non premiata per tipo classifica ADDESTRATIVA
        end if;
        
        if upper (l_desc_formula) like '%FISE%'
        then
            l_premiata := 0; --Non premiate perchè sono le manifestazioni FISE
            
            -- CASO IN CUI LA GARA E' un INCENTIVO MASAF in GARA FISE
        
            --if FN_INCENTIVO_MASAF_GARA_FISE(p_id_gara_esterna) > 0 then
            --    l_premiata := 1;
            --end if;
        end if;

        return l_premiata;
    exception
        when no_data_found
        then
            if c_debug
            then
                dbms_output.put_line (
                       'NO_DATA_FOUND in FN_GARA_PREMIATA_MASAF for Gara ID: '
                    || p_id_gara_esterna);
            end if;

            return 0;
        when others
        then
            if c_debug
            then
                dbms_output.put_line (
                       'Error in FN_GARA_PREMIATA_MASAF: '
                    || sqlerrm
                    || ' for Gara ID: '
                    || p_id_gara_esterna);
            end if;

            return 0;
    end fn_gara_premiata_masaf;


    function fn_incentivo_masaf_gara_fise (p_id_gara_esterna in number)
        return number
    is
        v_dati_gara                     tc_dati_gara_esterna%rowtype;
        v_disciplina_id                 number;
        v_nome_gara_upper               varchar2 (500);
        v_nome_manifest_upper           varchar2 (500);
        v_livello_tecnico_gara          varchar2 (50) := 'DA DESUMERE'; -- Es. 'H145_SUPERIORE', 'ALTO_LIVELLO_CC_MASAF'
        v_is_estero                     boolean := false;
        l_tipo_incentivo_gara           pls_integer := 0; -- 0 = Nessuno, 1 = Classifica Aggiunta SO, 2 = Incentivo 10%
        l_num_cav_masaf_incentivabili   number := 0;
        --v_result                        number;
    begin
        l_num_cav_masaf_incentivabili := 0;
         --   pkg_calcoli_premi_manifest.fn_gara_premiata_masaf ( p_id_gara_esterna);                                 -- id gara

        --if v_result = 1
       -- then
        --    return 0;  --una gara premiata Masaf non puo' avere incentivi 
        --end if;

        -- 1. Ottieni dettagli gara
        v_dati_gara := fn_info_gara_esterna (p_id_gara_esterna);
        v_disciplina_id := get_disciplina (p_id_gara_esterna);
        v_nome_gara_upper := upper (v_dati_gara.desc_nome_gara_esterna);

        -- Recupero riga dalla tabella gara_esterna
        select upper (mf.desc_denom_manifestazione)
          into v_nome_manifest_upper
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_id_gara_esterna;


        -- 2. Determina informazioni aggiuntive sulla gara (livello, luogo)
        -- Questa logica va adattata ai dati reali disponibili
        if v_disciplina_id = 4
        then                                                 -- Salto Ostacoli
             
        
        
            if    instr (v_nome_gara_upper, '145') > 0
               or instr (v_nome_gara_upper, '150') > 0
               or instr (v_nome_gara_upper, '155') > 0
               or instr (v_nome_gara_upper, '160') > 0 
               or v_nome_manifest_upper like '%CONCORSI%INTERNAZIONALI%ESTERO%'
            then
                v_livello_tecnico_gara := 'H145_SUPERIORE';
            end if;

           
            -- Determina se la gara è all'estero
            -- Ipotizziamo che il nome della manifestazione o un campo specifico lo indichi
            if    instr (v_nome_manifest_upper, 'ESTERO') > 0
               or instr (v_nome_manifest_upper, 'OPGLABBEEK') > 0 -- Aggiungere pattern per località estere
            -- OR v_dati_gara.NAZIONE_EVENTO != 'ITA' -- Se hai un campo nazione
            then
                v_is_estero := true;
            end if;
        end if;
        
        
        

        -- 3. Logica specifica per disciplina per determinare il TIPO di incentivo della GARA
        case v_disciplina_id 
            when 4-- SALTO OSTACOLI (ID 4)
            then                                      
              if v_livello_tecnico_gara = 'H145_SUPERIORE' and v_nome_gara_upper not like  '%MASAF%' and v_nome_manifest_upper not like '%MASAF%' 
                  and v_nome_manifest_upper not like 'FINALE%CIRCUITO%CLASSICO%'
                then
                    l_tipo_incentivo_gara := 2; -- Tipo incentivo: 10% del premio vinto (Italia o Estero)
                end if;
            when 3
            then                                   -- CONCORSO COMPLETO (ID 3)
                l_tipo_incentivo_gara := 2; -- Tipo incentivo: 10% del premio vinto
            when 6
            then                                            -- DRESSAGE (ID 6)
                l_tipo_incentivo_gara := 2; -- Tipo incentivo: 10% del premio vinto
            when 7
            then                                     -- MONTA DA LAVORO (ID 7)
                l_tipo_incentivo_gara := 0; -- Il programma MASAF è il suo circuito. Nessun incentivo AGGIUNTO a gare FITETREC generiche.
            when 2
            then                                           -- ENDURANCE (ID 2)
                l_tipo_incentivo_gara := 0; -- Nessun incentivo specifico menzionato per gare FISE generiche
            when 1
            then                              -- CIRCUITO ALLEVATORIALE (ID 1)
                l_tipo_incentivo_gara := 0;                  -- Gare già MASAF
            else
                l_tipo_incentivo_gara := 0; 
        end case;
        
        
        
        if v_disciplina_id = 3 -- COMPLETO 
        then        
            if    instr (v_nome_manifest_upper, 'MASAF') > 0 or instr (v_nome_manifest_upper, 'CAMPIONATO') > 0 then        
                l_tipo_incentivo_gara:= 0;
            end if;
        end if;
        
        if v_disciplina_id = 6 -- DRESSAGE 
        then        
            if    instr (v_nome_manifest_upper, 'MASAF') > 0 then        
                l_tipo_incentivo_gara:= 0;
            end if;
        end if;


--        if c_debug
--            then
--                dbms_output.put_line (  'v_nome_gara_upper '|| v_nome_gara_upper);
--                dbms_output.put_line (  'v_nome_manifest_upper '|| v_nome_manifest_upper);
--                 dbms_output.put_line (  'l_tipo_incentivo_gara '|| l_tipo_incentivo_gara); 
--                 dbms_output.put_line (  'v_livello_tecnico_gara '|| v_livello_tecnico_gara);
--                 if v_is_estero then
--                  dbms_output.put_line (  'v_is_estero TRUE'); else dbms_output.put_line (  'v_is_estero FALSE');end if;
--           end if;
            
        -- 4. Se la GARA è di un tipo idoneo a incentivi, conta i cavalli MASAF partecipanti
        -- controlla anche se ci sono premi FISE altrimenti non contano
        if l_tipo_incentivo_gara > 0
        then
            begin
                select count (*)
                  into l_num_cav_masaf_incentivabili
                  from tc_dati_classifica_esterna cl
                 where     cl.fk_sequ_id_dati_gara_esterna =
                           p_id_gara_esterna
                       and cl.fk_sequ_id_cavallo is not null
                       and (vincite_fise > 0 or vincite_masaf > 0 ); -- Cavallo è MASAF e ci sono vincite FISE
            exception
                when no_data_found
                then
                    l_num_cav_masaf_incentivabili := 0;
                when others
                then
                    if c_debug
                    then
                        dbms_output.put_line (
                               'FN_INCENTIVO_MASAF_GARA_FISE: Errore conteggio cavalli per Gara ID '
                            || p_id_gara_esterna
                            || ': '
                            || sqlerrm);
                    end if;

                    l_num_cav_masaf_incentivabili := 0; -- In caso di errore nel conteggio, restituisce 0
            end;
        end if;
        
         
            
--            if c_debug
--                then
--                    dbms_output.put_line (
--                        '--- DEBUG FN_INCENTIVO_MASAF_GARA_FISE ---' ||l_tipo_incentivo_gara);
--                     dbms_output.put_line (
--                        '--- DEBUG FN_INCENTIVO_MASAF_GARA_FISE ---' ||l_num_cav_masaf_incentivabili);
--                  
--                end if;

--        if c_debug
--        then
--            dbms_output.put_line (
--                '--- DEBUG FN_INCENTIVO_MASAF_GARA_FISE ---');
--            dbms_output.put_line ('ID Gara: ' || p_id_gara_esterna);
--            dbms_output.put_line ('Disciplina ID: ' || v_disciplina_id);
--            dbms_output.put_line (
--                'Nome Manifestazione: ' || v_nome_manifest_upper);
--            dbms_output.put_line ('Nome Gara: ' || v_nome_gara_upper);
--            dbms_output.put_line (
--                   'Categoria Gara (da FK): '
--                || fn_desc_tipologica (v_dati_gara.fk_codi_categoria));
--            dbms_output.put_line (
--                'Livello Tecnico Gara (dedotto): ' || v_livello_tecnico_gara);
--            dbms_output.put_line (
--                   'Gara Estero (dedotto): '
--                || case when v_is_estero then 'SI' else 'NO' end);
--            dbms_output.put_line (
--                'Tipo Incentivo Gara (flag): ' || l_tipo_incentivo_gara);
--            dbms_output.put_line (
--                   'Num. Cavalli MASAF Incentivabili: '
--                || l_num_cav_masaf_incentivabili);
--            dbms_output.put_line (
--                '------------------------------------------');
--        end if;

        return l_num_cav_masaf_incentivabili;
    exception
        when others
        then
            if c_debug
            then
                dbms_output.put_line (
                       'ERRORE in FN_INCENTIVO_MASAF_GARA_FISE per Gara ID '
                    || p_id_gara_esterna
                    || ': '
                    || sqlerrm);
            end if;

            return 0;
    end fn_incentivo_masaf_gara_fise;

    function fn_is_cavallo_premiato (p_id_classifica   in number,
                                     p_id_gara         in number,
                                     p_max_posizioni   in number)
        return boolean
    is
        v_posizione   number;
    begin
        select posizione
          into v_posizione
          from (select sequ_id_classifica_esterna,
                       dense_rank ()
                           over (
                               order by
                                   case
                                       when nume_punti is not null then 1
                                       else 2
                                   end,
                                   nume_punti desc,
                                   nume_piazzamento asc)    as posizione
                  from tc_dati_classifica_esterna
                 where     fk_sequ_id_dati_gara_esterna = p_id_gara
                       and fk_sequ_id_cavallo is not null)
         where sequ_id_classifica_esterna = p_id_classifica;

        if c_debug
        then
            dbms_output.put_line (
                   'DEBUG FN_IS_CAVALLO_PREMIATO: id_classifica='
                || p_id_classifica);
            dbms_output.put_line (
                   'DEBUG FN_IS_CAVALLO_PREMIATO: posizione='
                || v_posizione
                || ' max_pos='
                || p_max_posizioni);
        end if;

        return v_posizione <= p_max_posizioni;
    exception
        when no_data_found
        then
            if c_debug
            then
                dbms_output.put_line (
                       'DEBUG FN_IS_CAVALLO_PREMIATO: id_classifica='
                    || p_id_classifica
                    || ' NON TROVATO');
            end if;

            return false;
    end;

    function fn_premio_distribuzione_fise (num_partiti          in number,
                                           posizione            in number,
                                           num_con_parimerito   in number,
                                           montepremi           in number)
        return number
    is
        type t_tabella is table of number
            index by binary_integer;

        v_tabella             t_tabella;
        v_somma_percentuali   number := 0;
        idx                   number;
        i                     number;
    begin
        --   IF c_debug THEN
        --      DBMS_OUTPUT.PUT_LINE('--- FN_PREMIO_DISTRIBUZIONE_FISE ---');
        --      DBMS_OUTPUT.PUT_LINE('Input - num_partiti: ' || num_partiti || ', posizione: ' || posizione || ', num_con_parimerito: ' || num_con_parimerito || ', montepremi: ' || montepremi);
        --   END IF;

        if nvl (posizione, 0) < 1 or nvl (num_con_parimerito, 0) < 1
        then
            if c_debug
            then
                dbms_output.put_line ('Input non valido ritorna 0');
            end if;

            return 0;
        end if;

        idx := least (num_partiti, 40);

        v_tabella (1) := 25;
        v_tabella (2) := 18;
        v_tabella (3) := 15;
        v_tabella (4) := 12;
        v_tabella (5) := 10;
        v_tabella (6) := 4;
        v_tabella (7) := 4;
        v_tabella (8) := 4;
        v_tabella (9) := 4;
        v_tabella (10) := 4;

        if (   (idx <= 9 and posizione > 3)
            or (idx between 10 and 13 and posizione > 4)
            or (idx between 14 and 17 and posizione > 5)
            or (idx between 18 and 21 and posizione > 6)
            or (idx between 22 and 25 and posizione > 7)
            or (idx between 26 and 29 and posizione > 8)
            or (idx between 30 and 33 and posizione > 9)
            or (idx >= 34 and posizione > 10))
        then
            --      IF c_debug THEN
            --         DBMS_OUTPUT.PUT_LINE('Posizione fuori da premiabili ¿ ritorna 0');
            --      END IF;
            return 0;
        end if;

        for i in posizione .. posizione + num_con_parimerito - 1
        loop
            if v_tabella.exists (i)
            then
                v_somma_percentuali := v_somma_percentuali + v_tabella (i);
            --         IF c_debug THEN
            --            DBMS_OUTPUT.PUT_LINE('Aggiunta percentuale posizione ' || i || ': ' || v_tabella(i));
            --         END IF;
            end if;
        end loop;

        if c_debug
        then
            dbms_output.put_line (
                'Totale percentuale sommata: ' || v_somma_percentuali);
            dbms_output.put_line (
                   'Totale montepremi individuale: '
                || round (
                         (montepremi * v_somma_percentuali / 100)
                       / num_con_parimerito,
                       2));
        end if;

        return round (
                     (montepremi * v_somma_percentuali / 100)
                   / num_con_parimerito,
                   2);
    end;
    
    function fn_premio_distribuzione_csio (posizione            in number,
                                           num_con_parimerito   in number,
                                           montepremi           in number)
        return number
    is
        type t_tabella is table of number
            index by binary_integer;

        v_tabella             t_tabella;
        v_somma_percentuali   number := 0;
        idx                   number;
        i                     number;
    begin

        v_tabella (1) := 23;
        v_tabella (2) := 15;
        v_tabella (3) := 12;
        v_tabella (4) := 11;
        v_tabella (5) := 9;
        v_tabella (6) := 8;
        v_tabella (7) := 7;
        v_tabella (8) := 6;
        v_tabella (9) := 5;
        v_tabella (10) := 4;

        for i in posizione .. posizione + num_con_parimerito - 1
        loop
            if v_tabella.exists (i)
            then
                v_somma_percentuali := v_somma_percentuali + v_tabella (i);
            end if;
        end loop;

        return round (
                     (montepremi * v_somma_percentuali / 100)
                   / num_con_parimerito,
                   2);
    end;

    function fn_premio_distr_trofeo_compl (num_partiti          in number,
                                           posizione            in number,
                                           num_con_parimerito   in number,
                                           montepremi           in number)
        return number
    is
        type t_tabella is table of number
            index by binary_integer;

        v_tabella             t_tabella;
        v_somma_percentuali   number := 0;
        i                     number;
        max_posizioni         number;
    begin
        if nvl (posizione, 0) < 1 or nvl (num_con_parimerito, 0) < 1
        then
            if c_debug
            then
                dbms_output.put_line ('Input non valido - ritorna 0');
            end if;

            return 0;
        end if;

        max_posizioni := least (num_partiti, 10); -- massimo 10 premiati o meno se meno partenti

        if posizione > max_posizioni
        then
            return 0;
        end if;

        -- Tabella premi FISE (fino a 10 posizioni)
        v_tabella (1) := 24;
        v_tabella (2) := 21;
        v_tabella (3) := 17;
        v_tabella (4) := 13;
        v_tabella (5) := 10;
        v_tabella (6) := 3;
        v_tabella (7) := 3;
        v_tabella (8) := 3;
        v_tabella (9) := 3;
        v_tabella (10) := 3;

        for i in posizione .. posizione + num_con_parimerito - 1
        loop
            exit when i > max_posizioni;

            if v_tabella.exists (i)
            then
                v_somma_percentuali := v_somma_percentuali + v_tabella (i);
            end if;
        end loop;

        return round (
                     (montepremi * v_somma_percentuali / 100)
                   / num_con_parimerito,
                   2);
    end;    
    
    
    function fn_premio_distr_camp_compl (num_partiti          in number,
                                           posizione            in number,
                                           num_con_parimerito   in number,
                                           montepremi           in number)
        return number
    is
        type t_tabella is table of number
            index by binary_integer;

        v_tabella             t_tabella;
        v_somma_percentuali   number := 0;
        i                     number;
        max_posizioni         number;
    begin
        if nvl (posizione, 0) < 1 or nvl (num_con_parimerito, 0) < 1
        then
            if c_debug
            then
                dbms_output.put_line ('Input non valido - ritorna 0');
            end if;

            return 0;
        end if;

        max_posizioni := least (num_partiti, 6); -- massimo 6 premiati o meno se meno partenti

        if posizione > max_posizioni
        then
            return 0;
        end if;

        -- Tabella premi simil FISE (fino a 6 posizioni)
        v_tabella (1) := 27;
        v_tabella (2) := 22;
        v_tabella (3) := 17;
        v_tabella (4) := 14;
        v_tabella (5) := 11;
        v_tabella (6) := 9;

        for i in posizione .. posizione + num_con_parimerito - 1
        loop
            exit when i > max_posizioni;

            if v_tabella.exists (i)
            then
                v_somma_percentuali := v_somma_percentuali + v_tabella (i);
            end if;
        end loop;

        return round (
                     (montepremi * v_somma_percentuali / 100)
                   / num_con_parimerito,
                   2);
    end;   


function fn_premio_distr_7_allev (num_partiti          in number,
                                           posizione            in number,
                                           num_con_parimerito   in number,
                                           montepremi           in number)
        return number
    is
        type t_tabella is table of number
            index by binary_integer;

        v_tabella             t_tabella;
        v_somma_percentuali   number := 0;
        i                     number;
        max_posizioni         number;
    begin
        if nvl (posizione, 0) < 1 or nvl (num_con_parimerito, 0) < 1
        then
            if c_debug
            then
                dbms_output.put_line ('Input non valido - ritorna 0');
            end if;

            return 0;
        end if;

        max_posizioni := least (num_partiti, 3); -- massimo 10 premiati o meno se meno partenti

        if posizione > max_posizioni
        then
            return 0;
        end if;

        -- Tabella premi FISE (fino a 10 posizioni)
        v_tabella (1) := 50;
        v_tabella (2) := 30;
        v_tabella (3) := 20;

        for i in posizione .. posizione + num_con_parimerito - 1
        loop
            exit when i > max_posizioni;

            if v_tabella.exists (i)
            then
                v_somma_percentuali := v_somma_percentuali + v_tabella (i);
            end if;
        end loop;

        return round (
                     (montepremi * v_somma_percentuali / 100)
                   / num_con_parimerito,
                   2);
    end;   
    
function fn_premio_distr_endurance (num_partiti          in number,
                                           posizione            in number,
                                           num_con_parimerito   in number,
                                           montepremi           in number)
        return number
    is
        type t_tabella is table of number
            index by binary_integer;

        v_tabella             t_tabella;
        v_somma_percentuali   number := 0;
        i                     number;
        max_posizioni         number;
    begin
        if nvl (posizione, 0) < 1 or nvl (num_con_parimerito, 0) < 1
        then
            if c_debug
            then
                dbms_output.put_line ('Input non valido - ritorna 0');
            end if;

            return 0;
        end if;

        max_posizioni := least (num_partiti, 5); -- massimo premiati o meno se meno partenti

        if posizione > max_posizioni
        then
            return 0;
        end if;

        -- Tabella premi FISE (fino a 10 posizioni)
        v_tabella (1) := 29;
        v_tabella (2) := 22;
        v_tabella (3) := 19;
        v_tabella (4) := 16;
        v_tabella (5) := 14;

        for i in posizione .. posizione + num_con_parimerito - 1
        loop
            exit when i > max_posizioni;

            if v_tabella.exists (i)
            then
                v_somma_percentuali := v_somma_percentuali + v_tabella (i);
            end if;
        end loop;

        return round (
                     (montepremi * v_somma_percentuali / 100)
                   / num_con_parimerito,
                   2);
    end;  
     
procedure calcola_fasce_premiabili_masaf (
    p_classifica       in     t_classifica,
    p_montepremi       in     number,
    p_premiabili       in     number,
    p_priorita_fasce_alte in     boolean,
    p_mappa_premi      out    t_mappatura_premi,
    p_desc_fasce       out    varchar2
) is
    -- Quota iniziale per fasce
    v_quota_f1   number := round(p_montepremi * 0.5, 2);
    v_quota_f2   number := round(p_montepremi * 0.3, 2);
    v_quota_f3   number := round(p_montepremi * 0.2, 2);

    -- Tabelle temporanee per ID cavalli e dote
    type t_id_list is table of number index by pls_integer;
    type t_dote_list is table of number index by pls_integer;

    f1_ids      t_id_list;
    f2_ids      t_id_list;
    f3_ids      t_id_list;

    f1_dote     t_dote_list;
    f2_dote     t_dote_list;
    f3_dote     t_dote_list;

    v_f1        pls_integer;
    v_f2        pls_integer;
    v_f3        pls_integer;
    v_idx       pls_integer := 0;

    procedure aggiungi_in_fascia (
    id in number,
    dote in number,
    ids in out t_id_list,
    doti in out t_dote_list
) is
    idx pls_integer;
    j number := 0;
begin
   -- if c_debug then
   --     dbms_output.put_line('>> Aggiungo cavallo ' || id || ' con dote ' || dote || ' alla nuova fascia.');
   -- end if;

    idx := ids.first;
    while idx is not null loop
        if ids(idx) = id then 
          --  if c_debug then
          --      dbms_output.put_line('>> Cavallo ' || id || ' già presente nella fascia, non riaggiunto.');
          --  end if;
            return;
        end if;
        idx := ids.next(idx);
    end loop;

    ids(nvl(ids.last, 0) + 1) := id;
    doti(nvl(doti.last, 0) + 1) := dote;

    j := ids.first;
    while j is not null loop
       -- if c_debug then
       --     dbms_output.put_line('Fx>> ids(' || j || ') ' || ids(j));
       -- end if;
        j := ids.next(j);
    end loop;
end aggiungi_in_fascia;

-- All'interno di PKG_CALCOLI_PREMI_MANIFEST.pkb

procedure rimuovi_da_fascia (
    id in number,
    ids in out t_id_list,
    doti in out t_dote_list
) is
    idx pls_integer;
begin
   -- if c_debug then
    --    dbms_output.put_line('>> Elimino cavallo ' || id );
    --end if;

    idx := ids.first;
    while idx is not null loop
        -- Controlla se l'indice esiste prima di accedere all'elemento
        if ids.exists(idx) and ids(idx) = id then
            ids.delete(idx);
            -- Assicurati che anche la dote esista a quell'indice prima di cancellarla
            if doti.exists(idx) then
                doti.delete(idx);
            end if;
            exit; -- Esci dopo aver trovato e cancellato
        end if;
        idx := ids.next(idx);
    end loop;
end rimuovi_da_fascia;
begin
    if c_debug then
        dbms_output.put_line('--- CALCOLA_FASCE_PREMIABILI_MASAF ---');
        dbms_output.put_line('Premiabili: ' || p_premiabili || ', Montepremi: ' || p_montepremi);
    end if;

    -- Caso limite: troppi primi pari merito
    declare
        v_num_primi integer := 0;
    begin
        for i in 1 .. p_classifica.count loop
            if p_classifica(i).posizione = 1 then
                v_num_primi := v_num_primi + 1;
            end if;
        end loop;

        if v_num_primi > p_premiabili then
            for i in 1 .. v_num_primi loop
                p_mappa_premi(i).id_cavallo := p_classifica(i).id_cavallo;
                p_mappa_premi(i).fascia := 1;
                p_mappa_premi(i).premio := round(p_montepremi / v_num_primi, 2);
            end loop;
            return;
        end if;
    end;

-- Distribuzione iniziale fasce
if p_priorita_fasce_alte  then
    -- ALLEVATORIALE: Logica divisa
    
    if p_premiabili < 3 then
        -- CASO SPECIALE (1 o 2 premiati): Riempi dall'alto (F1, F2)
        -- Questa è la logica originale "Allevatoriale", che per p < 3 
        -- assegna correttamente a F1 e F2.
        -- p=1 -> (F1=1, F2=0, F3=0)
        -- p=2 -> (F1=1, F2=1, F3=0)
        v_f3 := floor(p_premiabili / 3);
        v_f2 := floor((p_premiabili - v_f3) / 2);
        v_f1 := p_premiabili - v_f2 - v_f3;
    else
        -- CASO STANDARD (>= 3 premiati): Usa la logica (1, 2, 2)
        -- come richiesto, identica a Salto Ostacoli.
        v_f1 := floor(p_premiabili / 3);
        v_f2 := floor((p_premiabili - v_f1) / 2);
        v_f3 := p_premiabili - v_f1 - v_f2;
    end if;
    
    -- Loop di assegnazione (comune per entrambi i casi Allevatoriale)
    for i in 1 .. p_premiabili loop
        if i <= v_f1 then
            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f1 / v_f1, 2), f1_ids, f1_dote);
        elsif i <= v_f1 + v_f2 then
            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f2 / v_f2, 2), f2_ids, f2_dote);
        else
            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f3 / v_f3, 2), f3_ids, f3_dote);
        end if;
    end loop;
else
    -- SALTO OSTACOLI: riempi dal basso (F3, F2, F1)
    
    -- Questa logica (1, 2, 2) gestisce GIA' correttamente tutti i casi:
    -- p=1 -> (F1=0, F2=0, F3=1)
    -- p=2 -> (F1=0, F2=1, F3=1)
    -- p=5 -> (F1=1, F2=2, F3=2)
    -- Non serve un if/else interno.
    v_f1 := floor(p_premiabili / 3);
    v_f2 := floor((p_premiabili - v_f1) / 2);
    v_f3 := p_premiabili - v_f1 - v_f2;
     
    for i in 1 .. p_premiabili loop
        if i <= v_f1 then
            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f1 / v_f1, 2), f1_ids, f1_dote);
        elsif i <= v_f1 + v_f2 then
            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f2 / v_f2, 2), f2_ids, f2_dote);
        else
            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f3 / v_f3, 2), f3_ids, f3_dote);
        end if;
    end loop;
end if;
--
--    -- Distribuzione iniziale fasce
--    v_f1 := floor(p_premiabili / 3);
--    v_f2 := floor((p_premiabili - v_f1) / 2);
--    v_f3 := p_premiabili - v_f1 - v_f2;
--
--    for i in 1 .. p_premiabili loop
--        if i <= v_f1 then
--      --   if c_debug then
--       --     dbms_output.put_line('>> Aggiungo cavallo ' || p_classifica(i).id_cavallo || ' in fascia 1.');
--       -- end if;
--            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f1 / v_f1, 2), f1_ids, f1_dote);
--        elsif i <= v_f1 + v_f2 then
--      --  if c_debug then
--      --      dbms_output.put_line('>> Aggiungo cavallo ' || p_classifica(i).id_cavallo || ' in fascia 2.');
--       -- end if;
--            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f2 / v_f2, 2), f2_ids, f2_dote);
--        else
--      --  if c_debug then
--       --     dbms_output.put_line('>> Aggiungo cavallo ' || p_classifica(i).id_cavallo || ' in fascia 3.');
--       -- end if;
--            aggiungi_in_fascia(p_classifica(i).id_cavallo, round(v_quota_f3 / v_f3, 2), f3_ids, f3_dote);
--        end if;
--    end loop;

   -- PROMOZIONI: verifica parimerito e promozione cavalli
 --  if c_debug then
 --           dbms_output.put_line('>> PROMOZIONI ');
 --       end if;
    for i in 2 .. p_premiabili loop
        if p_classifica(i).posizione = p_classifica(i - 1).posizione then
            declare
                id1 number := p_classifica(i - 1).id_cavallo;
                id2 number := p_classifica(i).id_cavallo;
                fascia1 number := null;
                fascia2 number := null;
                dote1 number := 0;
                dote2 number := 0;
                j pls_integer;
            begin
          --  if c_debug then
           --     dbms_output.put_line('>> Analisi parimerito per i='||i||'. Confronto ID:' || id1 || ' e ID:' || id2);
           --  end if;   -- Trova fasce attuali di id1 e id2
                j := f1_ids.first;
                while j is not null loop
             --   if c_debug then
            --   dbms_output.put_line('   F1 check: j='||j||', id='||f1_ids(j));
            --    end if; 
                    if f1_ids(j) = id1 then fascia1 := 1; dote1 := f1_dote(j); end if;
                    if f1_ids(j) = id2 then fascia2 := 1; dote2 := f1_dote(j); end if;
                    j := f1_ids.next(j);
                end loop;
                j := f2_ids.first;
                while j is not null loop
            --    if c_debug then
            --   dbms_output.put_line('   F2 check: j='||j||', id='||f2_ids(j));
           --     end if;
                    if f2_ids(j) = id1 then fascia1 := 2; dote1 := f2_dote(j); end if;
                    if f2_ids(j) = id2 then fascia2 := 2; dote2 := f2_dote(j); end if;
                    j := f2_ids.next(j);
                end loop;
                j := f3_ids.first;
                while j is not null loop
            --     if c_debug then
             --  dbms_output.put_line('   F3 check: j='||j||', id='||f3_ids(j));
             --   end if;
                    if f3_ids(j) = id1 then fascia1 := 3; dote1 := f3_dote(j); end if;
                    if f3_ids(j) = id2 then fascia2 := 3; dote2 := f3_dote(j); end if;
                    j := f3_ids.next(j);
                end loop;

-- >>> AGGIUNGA QUESTA STAMPA DI DEBUG DETTAGLIATA QUI <<<
--        dbms_output.put_line(
--            '>> Dettaglio Parimerito: Cavallo1 ID:' || id1 ||
--            ' Pos:' || p_classifica(i-1).posizione ||
--            ' in Fascia:' || NVL(TO_CHAR(fascia1), 'N/D') ||
--            ' | Cavallo2 ID:' || id2 ||
--            ' Pos:' || p_classifica(i).posizione ||
--            ' in Fascia:' || NVL(TO_CHAR(fascia2), 'N/D')
--        );
        
                if fascia1 is not null and fascia2 is not null and fascia1 != fascia2 then
                    declare
                        nuova_fascia number := least(fascia1, fascia2);
                        somma_doti number := dote1 + dote2;
                    begin
                        -- Rimuovi da fasce
                        if fascia1 = 1 then
                            rimuovi_da_fascia(id1, f1_ids, f1_dote);
                        elsif fascia1 = 2 then
                        
                            rimuovi_da_fascia(id1, f2_ids, f2_dote);
                        else
                            rimuovi_da_fascia(id1, f3_ids, f3_dote);
                        end if;

                        if fascia2 = 1 then
                            rimuovi_da_fascia(id2, f1_ids, f1_dote);
                        elsif fascia2 = 2 then
                            rimuovi_da_fascia(id2, f2_ids, f2_dote);
                        else
                            rimuovi_da_fascia(id2, f3_ids, f3_dote);
                        end if;

                        -- Inserisci entrambi nella nuova fascia con dote cumulata
                        if nuova_fascia = 1 then
                            aggiungi_in_fascia(id1, somma_doti / 2, f1_ids, f1_dote);
                            aggiungi_in_fascia(id2, somma_doti / 2, f1_ids, f1_dote);
                            
                            --stampo i valori della fascia 1 
                             j := f1_ids.first;
                            while j is not null loop
                     --         if c_debug then
                       --     dbms_output.put_line('F1>> f1_ids('||j||') '||f1_ids(j));
                       --     end if;
                            j := f1_ids.next(j);
                            end loop;
                        elsif nuova_fascia = 2 then
                            aggiungi_in_fascia(id1, somma_doti / 2, f2_ids, f2_dote);
                            aggiungi_in_fascia(id2, somma_doti / 2, f2_ids, f2_dote);
                            --stampo i valori della fascia 2 
                             j := f2_ids.first;
                            while j is not null loop
                      --        if c_debug then
                      --      dbms_output.put_line('F2>> f2_ids('||j||') '||f2_ids(j));
                      --      end if;
                            j := f2_ids.next(j);
                            end loop;
                        else
                            aggiungi_in_fascia(id1, somma_doti / 2, f3_ids, f3_dote);
                            aggiungi_in_fascia(id2, somma_doti / 2, f3_ids, f3_dote);
                        end if;
                    end;
                end if;
            end;
        end if;
    end loop;

    -- Ricalcolo premi (somma esplicita delle doti per fascia)
    declare
        tot1 number := 0;
        tot2 number := 0;
        tot3 number := 0;
        idx  pls_integer;
    begin
        idx := f1_dote.first;
        while idx is not null loop
            tot1 := tot1 + f1_dote(idx);
            idx := f1_dote.next(idx);
        end loop;

        idx := f2_dote.first;
        while idx is not null loop
            tot2 := tot2 + f2_dote(idx);
            idx := f2_dote.next(idx);
        end loop;

        idx := f3_dote.first;
        while idx is not null loop
            tot3 := tot3 + f3_dote(idx);
            idx := f3_dote.next(idx);
        end loop;

        v_idx := 0;
        if f1_ids.count > 0 then
        for i in f1_ids.first .. f1_ids.last loop
            v_idx := v_idx + 1;
            p_mappa_premi(v_idx).id_cavallo := f1_ids(i);
            p_mappa_premi(v_idx).fascia := 1;
            p_mappa_premi(v_idx).premio := round(tot1 / f1_ids.count, 2);
        end loop;
        end if;
        if f2_ids.count > 0 then
        for i in f2_ids.first .. f2_ids.last loop
           v_idx := v_idx + 1;
            p_mappa_premi(v_idx).id_cavallo := f2_ids(i);
            p_mappa_premi(v_idx).fascia := 2;
            p_mappa_premi(v_idx).premio := round(tot2 / f2_ids.count, 2);
        end loop;
        end if;
        if f3_ids.count > 0 then
        for i in f3_ids.first .. f3_ids.last loop
            v_idx := v_idx + 1;
            p_mappa_premi(v_idx).id_cavallo := f3_ids(i);
            p_mappa_premi(v_idx).fascia := 3;
            p_mappa_premi(v_idx).premio := round(tot3 / f3_ids.count, 2);
        end loop;
        end if;
    end;
    
    if c_debug then
            dbms_output.put_line (CHR(10) || '>> DISTRIBUZIONE PREMI PER FASCIA');
            dbms_output.put_line (RPAD('-', 80, '-'));
            dbms_output.put_line ('   ' || RPAD('Fascia', 8) || RPAD('Cavalli', 10) || 
                                  RPAD('/Cavallo', 15) || 'Totale Fascia');
            dbms_output.put_line (RPAD('-', 80, '-'));
       end if;     
            -- Conta cavalli per fascia e somma premi
            DECLARE
                v_count_f1 NUMBER := 0;
                v_count_f2 NUMBER := 0;
                v_count_f3 NUMBER := 0;
                v_tot_f1 NUMBER := 0;
                v_tot_f2 NUMBER := 0;
                v_tot_f3 NUMBER := 0;
            BEGIN
                FOR i IN 1 .. p_mappa_premi.count LOOP
                    CASE p_mappa_premi(i).fascia
                        WHEN 1 THEN 
                            v_count_f1 := v_count_f1 + 1;
                            v_tot_f1 := v_tot_f1 + p_mappa_premi(i).premio;
                        WHEN 2 THEN 
                            v_count_f2 := v_count_f2 + 1;
                            v_tot_f2 := v_tot_f2 + p_mappa_premi(i).premio;
                        WHEN 3 THEN 
                            v_count_f3 := v_count_f3 + 1;
                            v_tot_f3 := v_tot_f3 + p_mappa_premi(i).premio;
                        ELSE NULL;
                    END CASE;
                END LOOP;
                
                IF v_count_f1 > 0 THEN
                    dbms_output.put_line ('   ' || RPAD('1', 8) || RPAD(v_count_f1, 10) || 
                                          LPAD(TO_CHAR(v_tot_f1/v_count_f1, '99990.00'), 15) || 
                                          LPAD(TO_CHAR(v_tot_f1, '999990.00'), 15));
                END IF;
                IF v_count_f2 > 0 THEN
                    dbms_output.put_line ('   ' || RPAD('2', 8) || RPAD(v_count_f2, 10) || 
                                          LPAD(TO_CHAR(v_tot_f2/v_count_f2, '99990.00'), 15) || 
                                          LPAD(TO_CHAR(v_tot_f2, '999990.00'), 15));
                END IF;
                IF v_count_f3 > 0 THEN
                    dbms_output.put_line ('   ' || RPAD('3', 8) || RPAD(v_count_f3, 10) || 
                                          LPAD(TO_CHAR(v_tot_f3/v_count_f3, '99990.00'), 15) || 
                                          LPAD(TO_CHAR(v_tot_f3, '999990.00'), 15));
                END IF;
                
                dbms_output.put_line (RPAD('-', 80, '-'));
                dbms_output.put_line ('   ' || RPAD('TOTALE', 18) || 
                                      RPAD(v_count_f1 + v_count_f2 + v_count_f3, 10) || 
                                      LPAD(TO_CHAR(v_tot_f1 + v_tot_f2 + v_tot_f3, '999990.00'), 30));
                                      
                                      
                                      p_desc_fasce:= 'F1='||v_count_f1||',F2='||v_count_f2||',F3='||v_count_f3;
            END;
            
            dbms_output.put_line (RPAD('-', 80, '-'));
            dbms_output.put_line (CHR(10) || '>> ASSEGNAZIONE PREMI AI CAVALLI');
            dbms_output.put_line (RPAD('-', 80, '-'));
            
            for i in 1 .. p_mappa_premi.count loop
                dbms_output.put_line('   ' || 
                                     'Cavallo ID ' || LPAD(p_mappa_premi(i).id_cavallo, 8) ||
                                     ' | Fascia ' || p_mappa_premi(i).fascia ||
                                     ' | Premio Euro' || LPAD(TO_CHAR(p_mappa_premi(i).premio, '99990.00'), 10));
            end loop;
            dbms_output.put_line (RPAD('-', 80, '-'));
        
end;



    PROCEDURE fn_calcola_montepremi_salto (
        p_dati_gara   in tc_dati_gara_esterna%rowtype,
        p_periodo     in number,
        p_num_part    in number,
        p_giornata    in number,
        p_desc_calcolo_premio OUT varchar2,
        p_montepremi OUT number)
    is
        v_categoria       varchar2 (50) := 'SPORT';
        v_eta             number;
        --v_montepremi      number := 0;
        v_perc_giudizio   number := 1;
        v_perc_precis     number := 0;
        v_tipo_gara       varchar2 (20);
         v_nome_manifestazione     varchar2 (255);
         v_is_criterium boolean;
         v_is_finale    boolean;
        --v_desc_calcolo_premio       varchar2 (2000);
    begin
        v_categoria :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_categoria));
        v_eta :=
            to_number (
                substr (fn_desc_tipologica (p_dati_gara.fk_codi_eta), 1, 1));

-- Recupero riga la formula dell'edizione
        select  upper(mf.DESC_DENOM_MANIFESTAZIONE)
          into v_nome_manifestazione
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_dati_gara.SEQU_ID_DATI_GARA_ESTERNA;   
         
        if instr (upper (p_dati_gara.desc_nome_gara_esterna), 'SPORT') > 0
        then
            v_categoria := 'SPORT';
        elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'ELITE') > 0
        then
            v_categoria := 'ELITE';
        elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'SELEZIONE') >
              0
        then
            v_categoria := 'SELEZIONE';
        elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'ALTO') > 0
        then
            v_categoria := 'ALTO';
        elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), ' BR') > 0
        then
            v_categoria := 'BREVETTO';
        end if;
        
        
        --p_desc_calcolo_premio := 'categoria '||v_categoria;
        
        if instr (upper (p_dati_gara.desc_nome_gara_esterna), 'PRECISIONE') >
           0
        then
            v_tipo_gara := 'PRECISIONE';
        elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'GIUDIZIO') >
              0
        then
            v_tipo_gara := 'GIUDIZIO';
        elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), ' BR') >
              0
        then
            v_tipo_gara := 'BREVETTO';
        end if;

        if c_debug
        then
            dbms_output.put_line (CHR(10) || '>> DATI GARA');
            dbms_output.put_line (RPAD('-', 80, '-'));
            dbms_output.put_line ('   Nome gara     : ' || p_dati_gara.desc_nome_gara_esterna);
            dbms_output.put_line ('   Categoria     : ' || v_categoria);
            dbms_output.put_line ('   Età cavallo   : ' || v_eta);
            dbms_output.put_line ('   Tipo gara     : ' || NVL(v_tipo_gara, 'N/A'));
            dbms_output.put_line ('   Partenti      : ' || p_num_part);
            dbms_output.put_line (RPAD('-', 80, '-'));
        end if;
        
        -- CSIO ROMA - MASTER TALENT PIAZZA DI SIENA
        if instr(upper(p_dati_gara.desc_nome_gara_esterna), 'MASTER') > 0 
           and instr(upper(p_dati_gara.desc_nome_gara_esterna), 'GIOVANI') > 0
        then
            if v_eta = 7 then
                if instr(upper(p_dati_gara.desc_nome_gara_esterna), 'FINALE') > 0 then
                    p_montepremi := 5000;
                else -- 1° e 2° prova
                    p_montepremi := 3500;
                end if;
                p_desc_calcolo_premio := p_desc_calcolo_premio ||' montepremi fisso ';
                return;
            elsif v_eta = 6 then
                if instr(upper(p_dati_gara.desc_nome_gara_esterna), 'FINALE') > 0 then
                    p_montepremi := 4000;
                else -- 1° e 2° prova
                    p_montepremi := 2000;
                end if;
                p_desc_calcolo_premio := p_desc_calcolo_premio ||' montepremi fisso ';
                return;
            end if;
        end if;
        
        -- Calcolo base
        -- Percentuali
        if v_categoria = 'SPORT'
        then
            v_perc_giudizio := 1;
            v_perc_precis := 0;
        elsif v_categoria = 'ELITE' and v_eta = 4
        then
            v_perc_giudizio := 0.5;
            v_perc_precis := 0.5;
        elsif v_categoria in ('ELITE', 'ALTO') and v_eta = 5
        then
            v_perc_giudizio := 0.4;
            v_perc_precis := 0.6;
        else
            v_perc_giudizio := 1;
            v_perc_precis := 0;
        end if;
        
        p_desc_calcolo_premio := p_desc_calcolo_premio||' perc. a giudizio '||v_perc_giudizio*100||'%, perc. a precisione '||v_perc_precis*100||'%,';
                

        -- Finali Circuito Classico MASAF - Campionati e Criterium - si ricalcolano le percentuali di split
        if v_nome_manifestazione like 'FINALE%CIRCUITO%CLASSICO%'
        then
            -- Determino tipo gara (CRITERIUM o CAMPIONATO) e se è FINALE
            v_is_criterium := instr(upper(p_dati_gara.desc_nome_gara_esterna), 'CRITERIUM') > 0;
            v_is_finale    := instr(upper(p_dati_gara.desc_nome_gara_esterna), 'FINALE') > 0;
    
    
            if v_eta = 4 --CAMPIONATO 4 anni stessi premi se maschio o femmina
            then
                -- Montepremi
                if v_is_criterium then
                    p_montepremi := case when v_is_finale then 3700 else 1300 end;  -- valori criterium
                else
                    p_montepremi := case when v_is_finale then 20000 else 10000 end; -- campionato
                end if;
    
                -- Descrizione
                p_desc_calcolo_premio := case 
                    when v_is_criterium and v_is_finale     then 'CRITERIUM 4 ANNI - FINALE'
                    when v_is_criterium and not v_is_finale then 'CRITERIUM 4 ANNI - PROVA'
                    when not v_is_criterium and v_is_finale then 'CAMPIONATO 4 ANNI - FINALE'
                    else 'CAMPIONATO 4 ANNI - PROVA'
                end;
                
                -- Percentuali giudizio/precisione per età 4
                if v_is_criterium then
                    v_perc_giudizio := 1;
                    v_perc_precis   := 0;
                else
                    v_perc_giudizio := 0.5;
                    v_perc_precis   := 0.5;
                end if;
            elsif v_eta = 5
            then
                -- Montepremi
                if v_is_criterium then
                    p_montepremi := case when v_is_finale then 3700 else 1300 end;  -- valori criterium
                else
                    p_montepremi := case when v_is_finale then 20000 else 12000 end; -- campionato
                end if;
    
                -- Descrizione
                p_desc_calcolo_premio := case 
                    when v_is_criterium and v_is_finale     then 'CRITERIUM 5 ANNI - FINALE'
                    when v_is_criterium and not v_is_finale then 'CRITERIUM 5 ANNI - PROVA'
                    when not v_is_criterium and v_is_finale then 'CAMPIONATO 5 ANNI - FINALE'
                    else 'CAMPIONATO 5 ANNI - PROVA'
                end;
                
                -- Percentuali giudizio/precisione per età 5
                if v_is_criterium then
                    v_perc_giudizio := 1;
                    v_perc_precis   := 0;
                else
                    v_perc_giudizio := 0.4;
                    v_perc_precis   := 0.6;
                end if;
            elsif v_eta in (6,7) and  upper(p_dati_gara.desc_nome_gara_esterna) not like'%OLTRE%' --se BREVETTO o 1° GR allora si stratta di CRITURIUM con altri montepremi 
            then
                -- Montepremi
                if v_is_criterium then
                    p_montepremi := case when v_is_finale then 3800 else 1300 end;  -- valori criterium
                else
                    p_montepremi := case when v_is_finale then 24000 else 8000 end; -- campionato
                end if;
    
                -- Descrizione
                p_desc_calcolo_premio := case 
                    when v_is_criterium and v_is_finale     then 'CRITERIUM 6/7 ANNI - FINALE'
                    when v_is_criterium and not v_is_finale then 'CRITERIUM 6/7 ANNI - PROVA'
                    when not v_is_criterium and v_is_finale then 'CAMPIONATO 6/7 ANNI - FINALE'
                    else 'CAMPIONATO 6/7 ANNI - PROVA'
                end;
                
                -- Percentuali giudizio/precisione per età 6 non ci sono viene dato il 100% a quella unica gara
                v_perc_giudizio := 1;
                v_perc_precis   := 1;
            elsif v_eta = 7 and upper(p_dati_gara.desc_nome_gara_esterna) like'%OLTRE%' --se BREVETTO o 1° GR allora si stratta di CRITURIUM con altri montepremi 
            then
                -- Montepremi
                p_montepremi := case when v_is_finale then 3700 else 1300 end;  -- valori criterium
                
                -- Descrizione
                p_desc_calcolo_premio :=  'CRITERIUM 7 ANNI E OLTRE BR o 1GR';
                
                -- Percentuali giudizio/precisione per età 6 non ci sono viene dato il 100% a quella unica gara
                v_perc_giudizio := 1;
                v_perc_precis   := 1;
            
            elsif v_eta >= 8
            then
                 -- Montepremi
                if v_is_criterium then
                    p_montepremi := case when v_is_finale then 4000 else 2000 end;  -- valori criterium
                else
                    p_montepremi := case when v_is_finale then 20000 else 8000 end; -- campionato
                    --nel solo caso di terza prova è 10000
                    if instr(upper(p_dati_gara.desc_nome_gara_esterna), '3')>0 then
                        p_montepremi :=10000;
                    end if;
                end if;
    
                -- Descrizione
                p_desc_calcolo_premio := case 
                    when v_is_criterium and v_is_finale     then 'CRITERIUM 8 E OLTRE ANNI - FINALE'
                    when v_is_criterium and not v_is_finale then 'CRITERIUM 8 E OLTRE ANNI - PROVA'
                    when not v_is_criterium and v_is_finale then 'CAMPIONATO 8 E OLTRE ANNI - FINALE'
                    else 'CAMPIONATO 8 E OLTRE ANNI - PROVA'
                end;
                
                -- Percentuali giudizio/precisione per età 6 non ci sono viene dato il 100% a quella unica gara
                v_perc_giudizio := 1;
                v_perc_precis   := 1;
            end if;
        
        --CASI NON FINALI e NON CRITERIUM
        elsif v_categoria = 'SPORT'
        then
            p_montepremi := greatest (p_num_part, 6) * 50;
            p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 50 Euro ';
                
        elsif v_categoria = 'SELEZIONE'
        then
            p_montepremi :=
                case
                    when v_eta = 5 and p_giornata = 1 then 2000
                    when v_eta = 5 and p_giornata = 2 then 2000
                    when v_eta = 5 and p_giornata = 3 then 3500
                    when v_eta = 6 and p_giornata = 1 then 2500
                    when v_eta = 6 and p_giornata = 2 then 2500
                    when v_eta = 6 and p_giornata = 3 then 4000
                    when v_eta = 7 and p_giornata = 1 then 3000
                    when v_eta = 7 and p_giornata = 2 then 3000
                    when v_eta = 7 and p_giornata = 3 then 4500
                    else 0
                end;
             p_desc_calcolo_premio :=
                case
                    when v_eta = 5 and p_giornata = 1 then p_desc_calcolo_premio ||' montepremi fisso 2000 Euro '
                    when v_eta = 5 and p_giornata = 2 then p_desc_calcolo_premio ||' montepremi fisso 2000 Euro '
                    when v_eta = 5 and p_giornata = 3 then p_desc_calcolo_premio ||' montepremi fisso 3500 Euro '
                    when v_eta = 6 and p_giornata = 1 then p_desc_calcolo_premio ||' montepremi fisso 2500 Euro '
                    when v_eta = 6 and p_giornata = 2 then p_desc_calcolo_premio ||' montepremi fisso 2500 Euro '
                    when v_eta = 6 and p_giornata = 3 then p_desc_calcolo_premio ||' montepremi fisso 4000 Euro '
                    when v_eta = 7 and p_giornata = 1 then p_desc_calcolo_premio ||' montepremi fisso 3000 Euro '
                    when v_eta = 7 and p_giornata = 2 then p_desc_calcolo_premio ||' montepremi fisso 3000 Euro '
                    when v_eta = 7 and p_giornata = 3 then p_desc_calcolo_premio ||' montepremi fisso 4500 Euro '
                    else 0
                end;

                    
                    
        elsif v_categoria = 'BREVETTO' and v_eta >= 7
        then
            p_montepremi := greatest (p_num_part, 6) * 50;
            p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 50 Euro ';
           
        elsif v_categoria in ('ELITE', 'ALTO')
        then
            if v_eta = 4
            then
                if p_periodo = 1
                then
                    p_montepremi := greatest (p_num_part, 6) * 135;
                    p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 135 Euro ';
           
                elsif p_periodo = 2
                then
                    p_montepremi := greatest (p_num_part, 6) * 150;
                    p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 150 Euro ';
           
                end if;
            elsif v_eta = 5
            then
                if p_periodo = 1
                then
                    p_montepremi := greatest (p_num_part, 6) * 135;
                    p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 135 Euro ';
           
                elsif p_periodo = 2
                then
                    p_montepremi := greatest (p_num_part, 6) * 150;
                    p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 150 Euro ';
           
                end if;
            elsif v_eta = 6
            then
                if p_periodo = 1
                then
                    case p_giornata
                        when 1
                        then
                            p_montepremi := greatest (p_num_part, 6) * 150;
                            p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota per partente 150 Euro ';
           
                        when 2
                        then
                            p_montepremi := 2400;
                            p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota fisso 2400 Euro ';
           
                        when 3
                        then
                            p_montepremi := 3500;
                            p_desc_calcolo_premio := p_desc_calcolo_premio ||' quota fisso 3500 Euro ';
                
                    end case;
                elsif p_periodo = 2
                then
                    case p_giornata
                        when 2
                        then
                            p_montepremi := 2900;
                            p_desc_calcolo_premio := p_desc_calcolo_premio ||' montepremi fisso 2900 Euro ';
                
                        when 3
                        then
                            p_montepremi := 4400;
                            p_desc_calcolo_premio := p_desc_calcolo_premio ||' montepremi fisso 4400 Euro ';
                
                    end case;
                end if;
            elsif v_eta = 7
            then
                if p_periodo = 1
                then
                    p_montepremi :=
                        case when p_giornata = 3 then 3800 else 2700 end;
                        
                    p_desc_calcolo_premio:=
                        case p_giornata
                        when 1 then p_desc_calcolo_premio ||' montepremi fisso 3800 Euro '
                        else p_desc_calcolo_premio ||' montepremi fisso 2700 Euro '
                    end; 
                    
                else
                    p_montepremi :=
                        case when p_giornata = 3 then 5000 else 3300 end;
                end if;
            end if;
        end if;


       if c_debug
        then
            dbms_output.put_line (CHR(10) || '>> CALCOLO MONTEPREMI');
            dbms_output.put_line (RPAD('-', 80, '-'));
            dbms_output.put_line ('   Montepremi base        : ¿'|| LPAD(TO_CHAR(p_montepremi, '999990.00'), 12));
            dbms_output.put_line ('   Num. partenti          : ' || LPAD(p_num_part, 3));
            dbms_output.put_line ('   Categoria              : ' || v_categoria);
            dbms_output.put_line ('   Periodo                : ' || p_periodo);
            dbms_output.put_line ('   Perc. giudizio         : ' || TO_CHAR(v_perc_giudizio * 100, '990') || '%');
            dbms_output.put_line ('   Perc. precisione       : ' || TO_CHAR(v_perc_precis * 100, '990') || '%');
            dbms_output.put_line (RPAD('-', 80, '-'));
        end if;

        if v_tipo_gara = 'GIUDIZIO'
        then
            p_montepremi:= round (p_montepremi * v_perc_giudizio, 2);
        elsif v_tipo_gara = 'PRECISIONE'
        then
            p_montepremi:= round (p_montepremi * v_perc_precis, 2);
        else
            p_montepremi:= p_montepremi; -- casi come A TEMPO o  FASI CONSECUTIVE
        end if;
    exception
        when others
        then
            if c_debug
            then
                dbms_output.put_line (
                    'ERRORE FN_CALCOLA_MONTEPREMI_SALTO: ' || sqlerrm);
            end if;

            --return 0;
    end;



    function fn_calcola_montepremi_allev (
        p_dati_gara   in tc_dati_gara_esterna%rowtype,
        p_num_part    in number)
        return number
    is
        v_montepremi    number := 0;
        v_nome_gara     varchar2 (1000);
        v_num_part      number := 0;
        v_tipo_evento   varchar2 (500);
        v_eta      varchar2(20);
        v_dati_gara               tc_dati_gara_esterna%rowtype;
        
    begin
        v_dati_gara := fn_info_gara_esterna (p_dati_gara.SEQU_ID_DATI_GARA_ESTERNA);
        v_nome_gara := upper (p_dati_gara.desc_nome_gara_esterna);
        v_tipo_evento := upper(fn_desc_tipologica (p_dati_gara.fk_codi_tipo_evento));
        v_eta := upper(fn_desc_tipologica (p_dati_gara.fk_codi_eta));

        
        if v_tipo_evento is null
        then v_tipo_evento:= upper(fn_desc_tipologica (v_dati_gara.FK_CODI_TIPO_EVENTO));
        end if;
        
        if v_eta is null
        then v_eta:= upper(fn_desc_tipologica (v_dati_gara.FK_CODI_ETA));
        end if;

        if p_num_part < 6
        then
            v_num_part := 6;  -- montepremi minimo sempre per 6 cavalli
        else
            v_num_part := p_num_part;  
        end if;

        -- OBBEDIENZA 
        if v_nome_gara like '%OBBEDIENZA%'
        then
            if v_tipo_evento = 'FINALE'
            then
                v_montepremi := 25000;
            elsif v_tipo_evento LIKE '%REGIONALE%' OR v_tipo_evento LIKE '%INTERREGIONALE%'
            then
                v_montepremi := 350 * v_num_part;
            else
                v_montepremi := 200 * v_num_part;
            end if;
        -- SALTO IN LIBERTÀ
        elsif v_nome_gara like '%SALTO IN%'
        then
            if v_tipo_evento = 'FINALE'
            then
                v_montepremi := 35000;
            elsif v_tipo_evento LIKE '%REGIONALE%' OR v_tipo_evento LIKE '%INTERREGIONALE%'
            then
                v_montepremi := 350 * v_num_part;
            else
                v_montepremi := 200 * v_num_part;
            end if;
        -- ATTITUDINE AL SALTO
        elsif v_nome_gara like '%ATTITUDINE%'
        then
            if v_tipo_evento = 'FINALE' --A FIERACAVALLI
            then
                v_montepremi := 6000;
            else
                v_montepremi := 200 * v_num_part;
            end if;
        -- MORFO-ATTITUDINALE
        elsif v_nome_gara like '%MORFO%'
        then
            if v_tipo_evento = 'FINALE' --A FIERACAVALLI
            then
                if v_eta = '3 ANNI' then
                 v_montepremi := 6000;--6000 euro maschi e 6000 euro femmine 3 anni
                 else 
                 v_montepremi := 4000; --4000 euro maschi e 4000 euro femmine 2 anni
                 end if;
            elsif v_tipo_evento LIKE '%REGIONALE%' OR v_tipo_evento LIKE '%INTERREGIONALE%' then
                v_montepremi := 250 * v_num_part;
            else
                v_montepremi := 150 * v_num_part;
            end if;
        -- FOALS
        elsif v_nome_gara like '%FOAL%'
        then
            v_montepremi := 150 * v_num_part;
        else
            -- Default: assegno un montepremi minimo simbolico
            v_montepremi := 150 * v_num_part;
        end if;
        
        if v_nome_gara like '%COMBINAT%' and v_tipo_evento = 'FINALE'
        then
            v_montepremi := 1000; --A FIERACAVALLI la cominata sono 1000 euro
        elsif v_nome_gara like '%COMBINAT%' then
            v_montepremi := 500;
        end if;

        if c_debug
        then
            dbms_output.put_line (
                   'Montepremi calcolato : '
                || v_montepremi ||
                   ' - Numero partenti :'
                || v_num_part || ' - Tipo evento : ' || v_tipo_evento ||
                ' Età : ' || v_eta);
        end if;
        
        return v_montepremi;
    end;

    function fn_calcola_montepremi_completo (
        p_dati_gara   in tc_dati_gara_esterna%rowtype,
        p_num_part    in number)
        return number
    is
        v_nome_gara        varchar2 (1000);
        v_num_part         number := 0;
        v_tipo_evento      varchar2 (500);
        v_categoria        varchar2 (500);
        v_nome_manifestazione varchar2(500);
        v_eta_cavallo      number;
        v_montepremi_tot   number;
    begin
     if c_debug
        then
            dbms_output.put_line (
                   '[FN_CALCOLA_MONTEPREMI_COMPLETO] INIZIO ');
           
        end if;
        v_nome_gara := upper (p_dati_gara.desc_nome_gara_esterna);
        v_tipo_evento := fn_desc_tipologica (p_dati_gara.fk_codi_tipo_evento);
        v_categoria := fn_desc_tipologica (p_dati_gara.fk_codi_categoria);
        -- Recupero nome manifestazione
        select upper(mf.DESC_DENOM_MANIFESTAZIONE)
          into v_nome_manifestazione
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna;  
        --
        -- Si premiano le 5 tappe , il trofeo e la finale e basta (poi ci sono gli incentivi per le finali del mondo fatte all'estero)
        --
        -- Impone minimo 6 partenti per il calcolo del montepremi
        if p_num_part < 6
        then
            v_num_part := 6;
        else
            v_num_part := p_num_part;
        end if;

        v_eta_cavallo :=
            to_number (
                substr (fn_desc_tipologica (p_dati_gara.fk_codi_eta), 1, 1));
        v_tipo_evento :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_tipo_evento));

        
        
        
        if v_nome_manifestazione like '%TROFEO%' then
                v_tipo_evento := 'TROFEO'; -- Trofeo del Cavallo Italiano 
        end if; 
        
        if c_debug
        then
            dbms_output.put_line (
                   '[FN_CALCOLA_MONTEPREMI_COMPLETO] Età cavallo: '
                || v_eta_cavallo);
            dbms_output.put_line (
                   '[FN_CALCOLA_MONTEPREMI_COMPLETO] Tipo evento: '
                || v_tipo_evento);
            dbms_output.put_line (
                '[FN_CALCOLA_MONTEPREMI_COMPLETO] Categoria: ' || v_categoria);
        end if;

        case v_tipo_evento
            when 'TAPPA'
            then
                if v_eta_cavallo in (4, 5)
                then
                    v_montepremi_tot := 6 * 400 / 2; --metà va alla gara e metà alla progressione tecnica
                end if;
            when 'FINALE'
            then
                case v_eta_cavallo
                    when 4
                    then
                        if v_categoria = 'ELITE'
                        then
                            v_montepremi_tot := 10000;
                        elsif v_categoria = 'SPORT'
                        then
                            v_montepremi_tot := 1500;
                        end if;
                    when 5
                    then
                        if v_categoria = 'ELITE'
                        then
                            v_montepremi_tot := 10000;
                        elsif v_categoria = 'SPORT'
                        then
                            v_montepremi_tot := 3000;
                        end if;
                end case;
            when 'TROFEO'
            then
                v_montepremi_tot := 6000;
            else
                v_montepremi_tot := 0;
        end case;

        if v_nome_gara like 'CAMPIONATO%MASAF%ANNI%' then
                v_montepremi_tot := 10000; -- CAMPIONATO 6 e 7 ANNI
        end if; 
        
        
        if upper(v_nome_manifestazione) like '%CAMPIONATO%MONDO%' then
            if p_num_part >= 2 then
                v_montepremi_tot := 3000;
             else 
                v_montepremi_tot := 1500;
            end if;
        end if;

        if c_debug
        then
            dbms_output.put_line (
                   'fn_calcola_montepremi_completo Montepremi calcolato totale : '
                || v_montepremi_tot);
        end if;


        return v_montepremi_tot;
    end;


function fn_conta_qual_progr_tecnica(
    p_gara_id in number,
    p_eta_cavallo in number
) return number
is
    v_count number := 0;
    v_soglia_dress number;
begin
    -- Soglia dressage in base all'età
    v_soglia_dress := case p_eta_cavallo 
                        when 4 then 65
                        when 5 then 62
                        else 0 
                      end;
    
    select count(*)
    into v_count
    from tc_dati_classifica_esterna
    where fk_sequ_id_dati_gara_esterna = p_gara_id
      and fk_sequ_id_cavallo is not null
      --and flag_terminate_3_prove = 'S'
      and NUME_PIAZZ_X_COUNTRY <= 20  -- o <= 30 se maltempo
      and (NUME_PIAZZ_DRESS >= v_soglia_dress OR 
      NUME_P_SALTO_L <= 4);
    
    return v_count;
end;


procedure fn_calcola_n_premiabili_masaf (
    p_dati_gara   in tc_dati_gara_esterna%rowtype,
    p_num_part    in number,
    p_n_premiabili out number,
    p_desc_premiabili out varchar2
    )
    --return number
is
    v_categoria          varchar2 (50);
    v_eta                number;
    v_percent_premiati   number;
    v_n_premiabili       number;
    v_disciplina         number;

    -- Cursor per ALLEVATORIALE (ordina per punti)
    cursor c_classifica_punti is
          select rank () over (
                     order by
                         case when t.nume_punti is not null then 1 else 2 end,
                         t.nume_punti desc,
                         t.nume_piazzamento asc) as posizione_masaf,
                 t.sequ_id_classifica_esterna,
                 t.nume_piazzamento,
                 t.nume_punti,
                 t.fk_sequ_id_cavallo
            from tc_dati_classifica_esterna t
           where fk_sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna
             and t.fk_sequ_id_cavallo is not null
             and t.nume_piazzamento < 900
        order by case when t.nume_punti is not null then 1 else 2 end,
                 t.nume_punti desc,
                 t.nume_piazzamento asc;

    -- Cursor per SALTO OSTACOLI (ordina per piazzamento)
    cursor c_classifica_piazzamento is
          select dense_rank() over (order by t.nume_piazzamento asc) as posizione_masaf,
                 t.sequ_id_classifica_esterna,
                 t.nume_piazzamento,
                 t.fk_sequ_id_cavallo
            from tc_dati_classifica_esterna t
           where fk_sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna
             and t.fk_sequ_id_cavallo is not null
             and t.nume_piazzamento < 900
        order by t.nume_piazzamento asc;
begin
    v_disciplina := get_disciplina (p_dati_gara.sequ_id_dati_gara_esterna);

    if v_disciplina = 3 then --COMPLETO
        if p_num_part = 1 then
            v_n_premiabili := 1;
--        elsif p_num_part = 3 then
--            v_n_premiabili := 2;
        else
            v_n_premiabili := floor(p_num_part * 0.6);
        end if;
    end if;

    if v_disciplina = 1 then --ALLEVATORIALE
        if p_num_part <= 3 then
            v_n_premiabili := p_num_part;
        elsif p_num_part < 7 then
            v_n_premiabili := 3;
        else
            v_n_premiabili := floor(p_num_part * 0.5);
        end if;
        
        if upper(p_dati_gara.desc_nome_gara_esterna) like '%OBBEDIENZA%' then
            declare
                v_count_idonei number := 0;
            begin
                for r in c_classifica_punti loop
                    exit when r.nume_punti is null;
                    if r.nume_punti >= 65 then
                        v_count_idonei := v_count_idonei + 1;
                    end if;
                end loop;
                v_n_premiabili := v_count_idonei;
            end;
        end if;
        
        if upper(p_dati_gara.desc_nome_gara_esterna) like '%COMBINATA%' then
            v_n_premiabili := 1;
        end if;
        
        -- Gestione parimerito per ALLEVATORIALE (basato su punti)
--        declare
--            v_punti_ultimo_premiabile number;
--            v_pos number := 0;
--        begin
--            for r in c_classifica_punti loop
--                exit when r.nume_punti is null;
--                v_pos := v_pos + 1;
--                
--                if v_pos = v_n_premiabili then
--                    v_punti_ultimo_premiabile := r.nume_punti;
--                end if;
--                
--                if v_pos > v_n_premiabili and r.nume_punti = v_punti_ultimo_premiabile then
--                    v_n_premiabili := v_n_premiabili + 1;
--                end if;
--            end loop;
--        end;
    end if;

    if v_disciplina = 4 then --SALTO AD OSTACOLI
        v_categoria := upper(fn_desc_tipologica(p_dati_gara.fk_codi_categoria));
        v_eta := to_number(substr(fn_desc_tipologica(p_dati_gara.fk_codi_eta), 1, 1));

        if instr(upper(p_dati_gara.desc_nome_gara_esterna), 'SPORT') > 0 then
            v_categoria := 'SPORT';
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'ELITE') > 0 then
            v_categoria := 'ELITE';
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'ALTO') > 0 then
            v_categoria := 'ALTO';
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'SELEZIONE') > 0 then
            v_categoria := 'SELEZIONE';
        end if;

        if instr(upper(p_dati_gara.desc_nome_gara_esterna), 'ELITE') > 0 and v_eta = 6 then
            v_percent_premiati := 0.3;
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'MISTA') > 0 then
            v_percent_premiati := 0.5;
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'SPORT') > 0
          and instr(upper(p_dati_gara.desc_nome_gara_esterna), 'PRECISIONE') > 0 then
            v_percent_premiati := 0.5;
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'PRECISIONE') > 0 then
            v_percent_premiati := 0.4;
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'GIUDIZIO') > 0
          and v_categoria in ('ELITE', 'ALTO') then
            v_percent_premiati := 0.4;
        elsif instr(upper(p_dati_gara.desc_nome_gara_esterna), 'GIUDIZIO') > 0
          and v_categoria = 'SPORT' then
            v_percent_premiati := 0.5;
        else
            v_percent_premiati := 0.5;
        end if;

        if v_percent_premiati = 0.4
           and instr(upper(p_dati_gara.desc_nome_gara_esterna), 'GIUDIZIO') > 0
           and v_categoria in ('ELITE', 'ALTO') then
            v_n_premiabili := round(p_num_part * v_percent_premiati);
        else
            v_n_premiabili := floor(p_num_part * v_percent_premiati);
        end if;
        
        p_desc_premiabili := 'Perc.Premiabili: '||trunc(v_percent_premiati*100)||'%, ';
        -- Gestione parimerito per SALTO OSTACOLI
                
        declare
            v_piazzamento_limite number;
            v_count_totale_pari  number := 0;
            v_count_gia_dentro   number := 0;
            v_pos                number := 0;
        begin
            -- Trova il piazzamento della N-esima riga
            for r in (select nume_piazzamento
                        from tc_dati_classifica_esterna
                       where fk_sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna
                         and fk_sequ_id_cavallo is not null
                         and nume_piazzamento < 900
                    order by nume_piazzamento asc)
            loop
                v_pos := v_pos + 1;
                if v_pos = v_n_premiabili then
                    v_piazzamento_limite := r.nume_piazzamento;
                    exit;
                end if;
            end loop;
            
            -- Conta TUTTI quelli con quel piazzamento
            if v_piazzamento_limite is not null then
                select count(*)
                  into v_count_totale_pari
                  from tc_dati_classifica_esterna
                 where fk_sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna
                   and fk_sequ_id_cavallo is not null
                   and nume_piazzamento = v_piazzamento_limite
                   and nume_piazzamento < 900;
                
                -- Conta quanti con quel piazzamento sono già nei premiabili
                select count(*)
                  into v_count_gia_dentro
                  from (select nume_piazzamento, rownum rn
                          from (select nume_piazzamento
                                  from tc_dati_classifica_esterna
                                 where fk_sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna
                                   and fk_sequ_id_cavallo is not null
                                   and nume_piazzamento < 900
                              order by nume_piazzamento asc)
                         where rownum <= v_n_premiabili)
                 where nume_piazzamento = v_piazzamento_limite;
                
                -- Aggiungi solo i parimerito non ancora inclusi
                if v_count_totale_pari > v_count_gia_dentro then
                    v_n_premiabili := v_n_premiabili + (v_count_totale_pari - v_count_gia_dentro);
                    p_desc_premiabili := p_desc_premiabili||'Parimerito ultima posizione premiabile: '||(v_count_totale_pari - v_count_gia_dentro)||'';
--                    if c_debug then
--                        dbms_output.put_line('>> SO Parimerito piazz ' || v_piazzamento_limite || 
--                                           ': totali=' || v_count_totale_pari ||
--                                           ', gia dentro=' || v_count_gia_dentro ||
--                                           ' -> tot premiabili=' || v_n_premiabili);
--                    end if;
                end if;
            end if;
        end;
    end if;
--    if c_debug then 
--    dbms_output.put_line('FN_CALCOLA_N_PREMIABILI_MASAF: disc=' || v_disciplina || 
--                        ', cat=' || v_categoria || ', premiabili=' || v_n_premiabili);
--    end if;
    
    p_desc_premiabili := p_desc_premiabili||', Premiati: '||v_n_premiabili||' ';

    p_n_premiabili:= v_n_premiabili;
--    return v_n_premiabili;
exception
    when others then
        dbms_output.put_line('ERRORE FN_CALCOLA_N_PREMIABILI_MASAF: ' || sqlerrm);
        --return 0;
end;

--    function fn_calcola_n_premiabili_masaf (
--        p_dati_gara   in tc_dati_gara_esterna%rowtype,
--        p_num_part    in number)
--        return number
--    is
--        v_categoria          varchar2 (50);
--        v_eta                number;
--        v_percent_premiati   number;
--        v_n_premiabili       number;
--        v_disciplina         number;
--
--        cursor c_classifica is
--              select rank ()
--                         over (
--                             order by
--                                 case
--                                     when t.nume_punti is not null then 1
--                                     else 2
--                                 end,
--                                 t.nume_punti desc,
--                                 t.nume_piazzamento asc)    as posizione_masaf,
--                     t.*
--                from tc_dati_classifica_esterna t
--               where     fk_sequ_id_dati_gara_esterna =
--                         p_dati_gara.sequ_id_dati_gara_esterna
--                     and t.fk_sequ_id_cavallo is not null
--                     and t.nume_piazzamento < 900 -- escludo i non arrivati nella classifica
--            order by case when t.nume_punti is not null then 1 else 2 end,
--                     t.nume_punti desc,
--                     t.nume_piazzamento asc;
--    begin
--        --a seconda della disciplina ho delle regole di calcolo del numero dei premiabili.
--        --4 Salto Ostacoli
--        --2 Dressage
--        --3 Concorso Completo
--        --4 Endurance
--        --5 Monta da Lavoro
--        --1 Allevatoriale
--        v_disciplina :=
--            get_disciplina (p_dati_gara.sequ_id_dati_gara_esterna);
--        --dbms_output.put_line (
--        --    'FN_CALCOLA_N_PREMIABILI_MASAF v_disciplina: ' || v_disciplina);
--
--        if v_disciplina = 3   --COMPLETO
--        then
--            if p_num_part = 1 then
--                v_n_premiabili := 1;  -- Assegna tutto il premio
--            elsif p_num_part = 3 then
--                v_n_premiabili := 2;
--            else
--                v_n_premiabili := floor(p_num_part * 0.6);
--            end if;
--        end if;
--
--
--        if v_disciplina = 1 --ALLEVATORIALE
--        then
--            -- Calcolo base dei premiabili
--            if p_num_part <= 3
--            then
--                v_n_premiabili := p_num_part;
--            elsif p_num_part < 7
--            then
--                v_n_premiabili := 3;
--            else
--                v_n_premiabili := floor(p_num_part * 0.5);
--            end if;
--            
--            -- Caso OBBEDIENZA
--            if UPPER(p_dati_gara.desc_nome_gara_esterna) like '%OBBEDIENZA%'
--            then
--                declare
--                    v_count_idonei number := 0;
--                begin
--                    for r in c_classifica
--                    loop
--                        exit when r.nume_punti is null;
--                        if r.nume_punti >= 65
--                        then
--                            v_count_idonei := v_count_idonei + 1;
--                        end if;
--                    end loop;
--                    v_n_premiabili := v_count_idonei;
--                end;
--            end if;
--            
--            -- Caso COMBINATA
--            if UPPER(p_dati_gara.desc_nome_gara_esterna) like '%COMBINATA%'
--            then
--                v_n_premiabili := 1;
--            end if;
--            
--            -- GESTIONE PARI MERITO ultima posizione premiabile
--            declare
--                v_posizione number := 0;
--                v_punti_ultimo_premiabile number;
--            begin
--                for r in c_classifica
--                loop
--                    exit when r.nume_punti is null;
--                    v_posizione := v_posizione + 1;
--                    
--                    -- Memorizza il punteggio dell'ultimo premiabile teorico
--                    if v_posizione = v_n_premiabili
--                    then
--                        v_punti_ultimo_premiabile := r.nume_punti;
--                    end if;
--                    
--                    -- Se siamo oltre i premiabili teorici ma con stesso punteggio, incrementa
--                    if v_posizione > v_n_premiabili 
--                       and r.nume_punti = v_punti_ultimo_premiabile
--                    then
--                        v_n_premiabili := v_n_premiabili + 1;
--                    end if;
--                end loop;
--            end;
--        end if;
--
--        if v_disciplina = 4 --SALTO AD OSTACOLI
--        then
--            v_categoria :=
--                upper (fn_desc_tipologica (p_dati_gara.fk_codi_categoria));
--            v_eta :=
--                to_number (
--                    substr (fn_desc_tipologica (p_dati_gara.fk_codi_eta),
--                            1,
--                            1));
--
--            -- Override se nome gara contiene parole specifiche
--            if instr (upper (p_dati_gara.desc_nome_gara_esterna), 'SPORT') >
--               0
--            then
--                v_categoria := 'SPORT';
--            elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'ELITE') >
--                  0
--            then
--                v_categoria := 'ELITE';
--            elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'ALTO') >
--                  0
--            then
--                v_categoria := 'ALTO';
--            elsif instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                         'SELEZIONE') >
--                  0
--            then
--                v_categoria := 'SELEZIONE';
--            end if;
--
--            -- Calcolo percentuale in base al tipo
--            if     instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                          'ELITE') >
--                   0
--               and v_eta = 6
--            then
--                v_percent_premiati := 0.3;
--            elsif instr (upper (p_dati_gara.desc_nome_gara_esterna), 'MISTA') >
--                  0
--            then
--                v_percent_premiati := 0.5;
--            elsif     instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                             'SPORT') >
--                      0
--                  and instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                             'PRECISIONE') >
--                      0
--            then
--                v_percent_premiati := 0.5;
--            elsif instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                         'PRECISIONE') >
--                  0
--            then
--                v_percent_premiati := 0.4;
--            elsif     instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                             'GIUDIZIO') >
--                      0
--                  and v_categoria in ('ELITE', 'ALTO')
--            then
--                v_percent_premiati := 0.4;
--            elsif     instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                             'GIUDIZIO') >
--                      0
--                  and v_categoria = 'SPORT'
--            then
--                v_percent_premiati := 0.5;
--            else
--                -- Default MASAF: 50%
--                v_percent_premiati := 0.5;
--            end if;
--
--            -- Calcolo effettivo (di default CEIL, tranne in caso specifico .4 su ELITE/ALTO GIUDIZIO)
--            if     v_percent_premiati = 0.4
--               and instr (upper (p_dati_gara.desc_nome_gara_esterna),
--                          'GIUDIZIO') >
--                   0
--               and v_categoria in ('ELITE', 'ALTO')
--            then
--                v_n_premiabili := round (p_num_part * v_percent_premiati);
--            else
--                v_n_premiabili := floor (p_num_part * v_percent_premiati); --ceil ho modifica il 25/11/2025
--            end if;
--        end if;
--        
--        dbms_output.put_line ('FN_CALCOLA_N_PREMIABILI_MASAF v_n_premiabili: ' || v_n_premiabili||' per v_categoria '||v_categoria);
--        
--        -- Estendi premiabili per includere parimerito all'ultima posizione
--        declare
--            v_pos_ultimo   number;
--            v_count_pari   number := 0;
--        begin
--            -- Trova la posizione dell'ultimo premiabile
--            for r in c_classifica loop
--                if r.posizione_masaf = v_n_premiabili then
--                    v_pos_ultimo := r.posizione_masaf;
--                    exit;
--                end if;
--            end loop;
--            
--            -- Conta quanti hanno la stessa posizione
--            for r in c_classifica loop
--                if r.posizione_masaf = v_pos_ultimo then
--                    v_count_pari := v_count_pari + 1;
--                end if;
--            end loop;
--            
--            -- Se più di uno a parimerito, estendi
--            if v_count_pari > 1 then
--                v_n_premiabili := v_n_premiabili + (v_count_pari - 1);
--                if c_debug then
--                    dbms_output.put_line('>> Estesi premiabili per parimerito: +' || (v_count_pari - 1));
--                end if;
--            end if;
--        end;
--
--        return v_n_premiabili;
--    exception
--        when others
--        then
--            dbms_output.put_line (
--                'ERRORE FN_CALCOLA_N_PREMIABILI_MASAF: ' || sqlerrm);
--            return 0;
--    end;

    function fn_conta_parimerito (
        p_dati_gara   in tc_dati_gara_esterna%rowtype,
        p_posizione   in number)
        return number
    is
        v_count   number := 0;
    begin
        select count (*)
          into v_count
          from tc_dati_classifica_esterna c
         where     c.fk_sequ_id_dati_gara_esterna =
                   p_dati_gara.sequ_id_dati_gara_esterna
               and c.nume_piazzamento_masaf = p_posizione;

        return v_count;
    end;

    procedure aggiorna_fk_cavallo_classifica (p_gara_id in number)
    is
    begin
       
        update tc_dati_classifica_esterna cls
           set fk_sequ_id_cavallo =
                   (select cav.sequ_id_cavallo
                      from tc_cavallo cav
                     where     cav.desc_nome_completo = cls.desc_cavallo
                           and cav.anno_nascita = cls.anno_nascita_cavallo
                           and cav.codi_area = 'S')
         where     fk_sequ_id_cavallo is null
               and exists
                       (select 1
                          from tc_cavallo cav
                         where     cav.desc_nome_completo = cls.desc_cavallo
                               and cav.anno_nascita =
                                   cls.anno_nascita_cavallo
                                and cav.codi_area = 'S')
               and fk_sequ_id_dati_gara_esterna = p_gara_id;
               
         
    end aggiorna_fk_cavallo_classifica;

    function get_disciplina (p_gara_id in number)
        return number
    is
        v_disciplina   number := 0;
    begin
        select td.sequ_id_tipo_disciplina
          into v_disciplina
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
               join td_tipologia_disciplina td
                   on td.sequ_id_tipo_disciplina =
                      mf.fk_sequ_id_tipo_disciplina
         where dg.sequ_id_dati_gara_esterna = p_gara_id
         and rownum = 1;



        return v_disciplina;
    end;


    function fn_info_gara_esterna (p_gara_id in number)
        return tc_dati_gara_esterna%rowtype
    is
        v_dati_gara            tc_dati_gara_esterna%rowtype;
        v_disciplina           number;
        v_desc_nome_manifest   varchar2 (250);
        v_anno_cavallo         varchar2 (4);
    begin
        --ATTENZIONE QUI NON CI POSSONO ESSERE DML perchè è chiamata da una funzione che restituisce una table function

        -- Recupero riga dalla tabella gara_esterna
        select *
          into v_dati_gara
          from tc_dati_gara_esterna
         where sequ_id_dati_gara_esterna = p_gara_id;


        -- Recupero riga dalla tabella gara_esterna
        select upper(mf.desc_denom_manifestazione)
          into v_desc_nome_manifest
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_gara_id;

        -- recupero la disciplina della gara
        v_disciplina := get_disciplina (p_gara_id);

        select max (anno_nascita_cavallo)
          into v_anno_cavallo
          from tc_dati_classifica_esterna  ce
               join tc_cavallo ca
                   on ca.sequ_id_cavallo = ce.fk_sequ_id_cavallo
         where fk_sequ_id_dati_gara_esterna = p_gara_id;

        -- Deduzioni intelligenti sui campi principali

        --SALTO AD OSTACOLI
        if (v_disciplina = 4)
        then
            -- se manca un valore FK cerco di desumerlo dal nome della gara o da altri campi

            --CATEGORIA--
            if v_dati_gara.fk_codi_categoria is null
            then
                v_dati_gara.fk_codi_categoria :=
                    case
                        -- Selezione: deve essere esplicitamente nominata
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'SELEZIONE') >
                             0
                        then
                            75
                        -- Alto livello: nel nome c'è "ALTO" oppure altezza elevata (>=125)
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'ALTO') >
                             0
                        then
                            74
                        when v_dati_gara.desc_altezza_ostacoli between 125
                                                                   and 130
                        then
                            74
                        -- Elite: nel nome "ÉLITE" o "GIUDIZIO", oppure codifica specifica
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'ÉLITE') >
                             0
                        then
                            73
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'ELITE') >
                             0
                        then
                            73
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'GIUDIZIO') >
                             0
                        then
                            73
                        when v_dati_gara.desc_codice_categoria like 'CAT.E'
                        then
                            73
                        -- Sport: nel nome o default
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'SPORT') >
                             0
                        then
                            66
                        -- Altezza H110/H120 da sola non implica selezione ¿ default sport
                        when v_dati_gara.desc_altezza_ostacoli between 110
                                                                   and 120
                        then
                            66
                         when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 ' BR') >
                             0 --BREVETTO
                        then
                            114
                        -- Default: sport
                        else
                            66
                    end;
            end if;

            -- Correzione per gare ELITE ma "a tempo" (in realtà sport)
            if    instr (upper (v_dati_gara.desc_nome_gara_esterna), 'TEMPO') >
                  0
               or instr (upper (v_dati_gara.desc_nome_gara_esterna), 'SPORT') >
                  0
            then
                v_dati_gara.fk_codi_categoria := 66;                  -- SPORT
            end if;



            --CLASSIFICA

            if v_dati_gara.fk_codi_tipo_classifica is null
            then
                v_dati_gara.fk_codi_tipo_classifica :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'GIUDIZIO') >
                             0
                        then
                            58                                    --'GIUDIZIO'
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'TEMPO') >
                             0
                        then
                            2                                        --'TEMPO'
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'BARRAGE') >
                             0
                        then
                            76                                     --'BARRAGE'
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'ADDESTRATIVA') >
                             0
                        then
                            77                                --'ADDESTRATIVA'
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'COMBINATA') >
                             0
                        then
                            3                                    --'COMBINATA'
                        else
                            null
                    end;
            --    UPDATE tc_dati_gara_esterna
            --     SET fk_codi_tipo_classifica =
            --             v_dati_gara.fk_codi_tipo_classifica
            --   WHERE sequ_id_dati_gara_esterna = p_gara_id;
            end if;

            v_dati_gara.desc_nome_gara_esterna := upper(v_dati_gara.desc_nome_gara_esterna);
            if v_dati_gara.fk_codi_eta is null
            then
                v_dati_gara.fk_codi_eta :=
                    case
                        when instr (v_dati_gara.desc_nome_gara_esterna,
                                    '4 ANNI') >
                             0
                        then
                            59                                             --4
                        when instr (v_dati_gara.desc_nome_gara_esterna,
                                    '5 ANNI') >
                             0
                        then
                            60
                        when instr (v_dati_gara.desc_nome_gara_esterna,
                                    '6 ANNI') >
                             0
                        then
                            61
                        when instr (v_dati_gara.desc_nome_gara_esterna,
                                    '7 ANNI') >
                             0
                        then
                            62
                        when instr (v_dati_gara.desc_nome_gara_esterna,
                                    '8 ANNI') >
                             0
                        then
                            63
                        else
                            null
                    end;
            --   UPDATE tc_dati_gara_esterna
            --     SET fk_codi_eta = v_dati_gara.fk_codi_eta
            --  WHERE sequ_id_dati_gara_esterna = p_gara_id;
            end if;


            if v_dati_gara.fk_codi_tipo_evento is null
            then
                v_dati_gara.fk_codi_tipo_evento :=
                    case
                        when    instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'FINALE') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'CAMPIONATO') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'CRITERIUM') >
                                0
                        then
                            106                                    -- 'FINALE'
                        when    instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'TAPPA') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'QUALIFICA') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'CIRCUITO') >
                                0
                        then
                            65                                      -- 'TAPPA'
                        else
                            null
                    end;
            --  UPDATE tc_dati_gara_esterna
            --     SET fk_codi_tipo_evento = v_dati_gara.fk_codi_tipo_evento
            --   WHERE sequ_id_dati_gara_esterna = p_gara_id;
            end if;
        end if;


        --ENDURANCE
        if (v_disciplina = 2)
        then
            if v_dati_gara.fk_codi_categoria is null
            then
                v_dati_gara.fk_codi_categoria :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEI1*') >
                             0
                        then
                            23
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEIYJ1*') >
                             0
                        then
                            24
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEI2*') >
                             0
                        then
                            25
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEIYJ2*') >
                             0
                        then
                            26
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEI3*') >
                             0
                        then
                            27
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEN B') >
                             0
                        then
                            28
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEN A') >
                             0
                        then
                            29
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'DEBUTTANTI') >
                             0
                        then
                            30
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'PROMOZIONALI') >
                             0
                        then
                            31
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CEN B/R') >
                             0
                        then
                            102
                        else
                            null
                    end;

            end if;

            if v_dati_gara.fk_codi_tipo_evento is null
            then
                   v_dati_gara.fk_codi_tipo_evento :=
                    case
                        when upper(v_dati_gara.desc_nome_gara_esterna) like '%FINALE%'
                        then
                            103
                        when   upper (v_desc_nome_manifest) like     'FINALE%'
                        then
                            103
                        when   upper (v_desc_nome_manifest) like     'CAMPIONATO%'
                        then
                            103
                        else
                            102                                        --TAPPA
                    end;
            end if;
        end if;

        --DRESSAGE
        if (v_disciplina = 6)
        then
            if v_dati_gara.fk_codi_tipo_evento is null
            then
                v_dati_gara.fk_codi_tipo_evento :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'FINALE') >
                             0
                        then
                            5
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CAMPIONATO') >
                             0
                        then
                            6
                        else
                            4
                    end;
            --   UPDATE tc_dati_gara_esterna
            --      SET fk_codi_tipo_evento = v_dati_gara.fk_codi_tipo_evento
            --    WHERE sequ_id_dati_gara_esterna = p_gara_id;
            end if;

            if v_dati_gara.fk_codi_livello_cavallo is null
            then
                v_dati_gara.fk_codi_livello_cavallo :=
                    case
                        when v_dati_gara.codi_prontuario like 'E%' then 64
                        when v_dati_gara.codi_prontuario like 'F%' then 67
                        when v_dati_gara.codi_prontuario like 'M%' then 68
                        when v_dati_gara.codi_prontuario like 'D%' then 69
                        when v_dati_gara.codi_prontuario like 'C%' then 70
                        when v_dati_gara.codi_prontuario like 'B%' then 71
                        when v_dati_gara.codi_prontuario like 'A%' then 72
                        else 64                               -- fallback base
                    end;
            -- UPDATE tc_dati_gara_esterna
            --   SET fk_codi_livello_cavallo =
            --          v_dati_gara.fk_codi_livello_cavallo
            -- WHERE sequ_id_dati_gara_esterna = p_gara_id;
            end if;
        end if;


        --ALLEVATORIALE
        if (v_disciplina = 1)
        then
            --      DBMS_OUTPUT.PUT_LINE('GARA: ' || v_dati_gara.desc_nome_gara_esterna);
            --DBMS_OUTPUT.PUT_LINE('MANIFESTAZIONE: ' || v_desc_nome_manifest);
            if v_dati_gara.fk_codi_tipo_prova is null
            then
                v_dati_gara.fk_codi_tipo_prova :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'SALTO IN LIBERTA') >
                             0
                        then
                            10                             -- salto in libertà
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'MORFO') >
                             0
                        then
                            9                            -- morfo-attitudinale
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'OBBEDIENZA') >
                             0
                        then
                            11                       -- obbedienza ed andature
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'ATTITUDINE AL SALTO') >
                             0
                        then
                            12                          -- attitudine al salto
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'RASSEGNA') >
                             0
                        then
                            13                               -- rassegna foals
                        when    instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'CLASSIFICA COMBINATA') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'COMBINATA S.I.') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'COMBINATA A.A.') >
                                0
                             or (    instr (
                                         upper (
                                             v_dati_gara.desc_nome_gara_esterna),
                                         'COMBINATA') >
                                     0
                                 and instr (upper (v_desc_nome_manifest),
                                            'FINALI NAZIONALI') >
                                     0)
                        then
                            14                         -- classifica combinata
                        else
                            null                           -- tipo sconosciuto
                    end;
            end if;

           
            
            
            if v_dati_gara.fk_codi_tipo_evento is null
            then
                v_dati_gara.fk_codi_tipo_evento :=
                    case
                        when    instr (
                                         upper (
                                             v_desc_nome_manifest),
                                         'FINAL') >
                                     0
                        then
                            22                                       -- FINALE
                        when    instr (
                                         upper (
                                             v_desc_nome_manifest),
                                         'TAPPA') >
                                     0
                        then
                            19                                        -- TAPPA
                        when    instr (
                                         upper (
                                             v_desc_nome_manifest),
                                         'INTERREGIONAL') >
                                     0
                        then
                            21                               -- INTERREGIONALE
                        when    instr (
                                         upper (
                                             v_desc_nome_manifest),
                                         'REGIONAL') >
                                     0
                        then
                            20                                    -- REGIONALE
                    end;

                -- Fallback finale se ancora NULL e manifestazione contiene "TAPPE"
                if     v_dati_gara.fk_codi_tipo_evento is null
                   and instr (upper (v_desc_nome_manifest), 'TAPPE') > 0
                then
                    v_dati_gara.fk_codi_tipo_evento := 19;
                end if;
                
                
--                 if c_debug
--            then
--                dbms_output.put_line (
--                       'DEBUG TIPO EVENTO fk_codi_tipo_evento: '
--                    || v_dati_gara.fk_codi_tipo_evento);
--                         dbms_output.put_line (
--                       'DEBUG TIPO EVENTO v_desc_nome_manifest: '
--                    || v_desc_nome_manifest);
--         
--
--         
--            end if;
            
            end if;


            if v_dati_gara.fk_codi_categoria is null
            then
                v_dati_gara.fk_codi_categoria :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '1 ANNO') >
                             0
                        then
                            89
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '2 ANNI') >
                             0
                        then
                            90
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '3 ANNI') >
                             0
                        then
                            91
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'FOAL') >
                             0
                        then
                            88
                        else
                            null
                    end;
            --  UPDATE tc_dati_gara_esterna
            --     SET fk_codi_categoria = v_dati_gara.fk_codi_categoria
            --   WHERE sequ_id_dati_gara_esterna = p_gara_id;
            end if;
            
            
                    IF v_dati_gara.fk_codi_eta IS NULL
                THEN
                    v_dati_gara.fk_codi_eta :=
                        CASE
                            WHEN INSTR (UPPER (v_dati_gara.desc_nome_gara_esterna),
                                        '1 ANNO') >
                                 0
                            THEN
                                111
                            WHEN INSTR (UPPER (v_dati_gara.desc_nome_gara_esterna),
                                        '2 ANNI') >
                                 0
                            THEN
                                112
                            WHEN INSTR (UPPER (v_dati_gara.desc_nome_gara_esterna),
                                        '3 ANNI') >
                                 0
                            THEN
                                113
                            ELSE
                                CASE
                                    WHEN   TO_NUMBER (
                                               SUBSTR (v_dati_gara.data_gara_esterna,
                                                       0,
                                                       4))
                                         - TO_NUMBER (v_anno_cavallo) =
                                         1
                                    THEN
                                        111
                                    WHEN   TO_NUMBER (
                                               SUBSTR (v_dati_gara.data_gara_esterna,
                                                       0,
                                                       4))
                                         - TO_NUMBER (v_anno_cavallo) =
                                         2
                                    THEN
                                        112
                                    WHEN   TO_NUMBER (
                                               SUBSTR (v_dati_gara.data_gara_esterna,
                                                       0,
                                                       4))
                                         - TO_NUMBER (v_anno_cavallo) =
                                         3
                                    THEN
                                        113
                                    ELSE
                                        NULL
                                END
                        END;
                --  UPDATE tc_dati_gara_esterna
                --     SET fk_codi_categoria = v_dati_gara.fk_codi_categoria
                --   WHERE sequ_id_dati_gara_esterna = p_gara_id;
                END IF;
        
        
        end if;

        

        -- COMPLETO
        if (v_disciplina = 3)
        then
            -- 1. DEDUZIONE FK_CODI_LIVELLO_CAVALLO (Livello tecnico: CN1*, CN2*, CCI2*-S, etc.)
            if v_dati_gara.fk_codi_livello_cavallo is null
            then
                v_dati_gara.fk_codi_livello_cavallo :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CCN**') >
                             0
                        then
                            50
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CCI2*-S') >
                             0
                        then
                            51
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CCIYH1*') >
                             0
                        then
                            52
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CCI3*') >
                             0
                        then
                            53
                        when    instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'CN1*') >
                                0
                             or instr (
                                    upper (
                                        v_dati_gara.desc_nome_gara_esterna),
                                    'CN105') >
                                0
                        then
                            48
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'CN2*') >
                             0
                        then
                            49
                        else
                            null
                    end;
            end if;

            -- 2. DEDUZIONE FK_CODI_CATEGORIA (Età del cavallo)
            if v_dati_gara.fk_codi_categoria is null
            then
                v_dati_gara.fk_codi_categoria :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'SPORT') >
                             0
                        then
                            97
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 'ELITE') >
                             0
                        then
                            98
                        else
                            null
                    end;
            end if;

            -- 2.b DEDUZIONE fk_codi_eta (Età cavallo, usata nel calcolo premi)
            if v_dati_gara.fk_codi_eta is null
            then
                v_dati_gara.fk_codi_eta :=
                    case
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '4 ANNI') >
                             0
                        then
                            107
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '5 ANNI') >
                             0
                        then
                            108
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '6 ANNI') >
                             0
                        then
                            109
                        when instr (
                                 upper (v_dati_gara.desc_nome_gara_esterna),
                                 '7 ANNI') >
                             0
                        then
                            110
                        else
                            null
                    end;
            end if;

            -- 3. DEDUZIONE FK_CODI_TIPO_EVENTO (Tappa, Finale, Campionato)
        if v_dati_gara.fk_codi_tipo_evento is null or v_dati_gara.fk_codi_tipo_evento=''
            then    
                IF --(v_dati_gara.fk_codi_eta IN (107,108) OR upper (v_dati_gara.desc_nome_gara_esterna) LIKE '%MASAF%') AND
                   v_desc_nome_manifest LIKE '%CIRCUITO%COMPLETO%' THEN
                    v_dati_gara.fk_codi_tipo_evento := 54; --'TAPPA'
                end if;
                -- Se il nome manifestazione/gara contiene "FINALE"
                IF upper (v_dati_gara.desc_nome_gara_esterna) LIKE '%FINALE%' OR v_desc_nome_manifest LIKE '%FINALE%' THEN
                  v_dati_gara.fk_codi_tipo_evento := 56;--'FINALE'
                  end if;
                -- Se è un campionato di 6 o 7 anni
                IF upper (v_dati_gara.desc_nome_gara_esterna) LIKE '%CAMPIONATO%ANNI%' THEN
                  v_dati_gara.fk_codi_tipo_evento := 100;--'CAMPIONATO'
                  end if;
        end if;
        
end if;

        if c_debug_info
        then
            dbms_output.put_line ('----------------------------------');
            dbms_output.put_line (
                'FN_INFO_GARA_ESTERNA v_disciplina ' || v_disciplina);
            dbms_output.put_line (
                ' - Nome gara :' || v_dati_gara.desc_nome_gara_esterna || ' Manifestazione : '||v_desc_nome_manifest);
            dbms_output.put_line (
                   ' - sequ_id_dati_gara_esterna='
                || v_dati_gara.sequ_id_dati_gara_esterna);
            dbms_output.put_line (
                   ' - tipo classifica    '
                || v_dati_gara.fk_codi_tipo_classifica
                || ' '
                || upper (
                       fn_desc_tipologica (
                           v_dati_gara.fk_codi_tipo_classifica)));
            dbms_output.put_line (
                   ' - categoria ['
                || v_dati_gara.fk_codi_categoria
                || '] '
                || upper (fn_desc_tipologica (v_dati_gara.fk_codi_categoria)));
            dbms_output.put_line (
                   ' - tipo prova ['
                || v_dati_gara.fk_codi_tipo_prova
                || '] '
                || upper (
                       fn_desc_tipologica (v_dati_gara.fk_codi_tipo_prova)));
            dbms_output.put_line (
                   ' - tipo evento ['
                || v_dati_gara.fk_codi_tipo_evento
                || '] '
                || upper (
                       fn_desc_tipologica (v_dati_gara.fk_codi_tipo_evento)));
            dbms_output.put_line (
                   ' - eta ['
                || v_dati_gara.fk_codi_eta
                || '] '
                || upper (fn_desc_tipologica (v_dati_gara.fk_codi_eta)));
            dbms_output.put_line (
                   '  - livello cavallo ['
                || v_dati_gara.fk_codi_livello_cavallo
                || '] '
                || upper (
                       fn_desc_tipologica (
                           v_dati_gara.fk_codi_livello_cavallo)));
            dbms_output.put_line ('----------------------------------');
        end if;

        return v_dati_gara;
    end fn_info_gara_esterna;



    FUNCTION fn_periodo_salto_ostacoli (p_data_gara VARCHAR2) -- formato: 'YYYYMMDD'
    RETURN NUMBER
IS
    v_data             DATE;
    v_anno             NUMBER;
    v_inizio_primo     DATE;
    v_fine_primo       DATE;
    v_inizio_secondo   DATE;
    v_fine_secondo     DATE;
    v_terza_domenica   DATE;

    -- Funzione locale compatibile con DOMENICA/SUNDAY
    FUNCTION fn_next_day_compatibile (p_data DATE)
        RETURN DATE
    IS
        v_result   DATE;
    BEGIN
        BEGIN
            v_result := NEXT_DAY (p_data, 'DOMENICA');
        EXCEPTION
            WHEN OTHERS THEN
                v_result := NEXT_DAY (p_data, 'SUNDAY');
        END;

        RETURN v_result;
    END;
BEGIN
    v_data := TO_DATE (p_data_gara, 'YYYYMMDD');
    v_anno := TO_NUMBER (TO_CHAR (v_data, 'YYYY'));

    -- Calcolo terza domenica di marzo
    v_terza_domenica := fn_next_day_compatibile (TO_DATE ('01-03-' || v_anno, 'DD-MM-YYYY') - 1) + 14;
    
    -- MODIFICA: Inizio primo periodo = VENERDÌ prima della terza domenica (non la domenica stessa)
    -- Così includiamo le manifestazioni che iniziano venerdì/sabato
    v_inizio_primo := v_terza_domenica - 2;  -- Venerdì prima della terza domenica
    
    -- Fine primo periodo = ultima domenica di maggio
    v_fine_primo := fn_next_day_compatibile (LAST_DAY (TO_DATE ('01-05-' || v_anno, 'DD-MM-YYYY')) - 7);

    -- Calcolo secondo periodo (invariato)
    -- Prima domenica di giugno
    v_inizio_secondo := fn_next_day_compatibile (TO_DATE ('01-06-' || v_anno, 'DD-MM-YYYY') - 1);
    
    -- Seconda domenica di settembre  
    v_fine_secondo := fn_next_day_compatibile (fn_next_day_compatibile (TO_DATE ('01-09-' || v_anno, 'DD-MM-YYYY') - 1));

    IF v_data BETWEEN v_inizio_primo AND v_fine_primo THEN
        RETURN 1;
    ELSIF v_data BETWEEN v_inizio_secondo AND v_fine_secondo THEN
        RETURN 2;
    ELSE
        RETURN 0;
    END IF;
END fn_periodo_salto_ostacoli;



    function fn_calcolo_salto_ostacoli_sim (p_gara_id        in number,
                                            p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        l_risultati              t_tabella_premi;
        v_rec                    unire_rel2.pkg_calcoli_premi_manifest.t_premio_rec;
        -- v_disciplina             VARCHAR2 (50);
        v_categoria              varchar2 (50);
        v_eta                    number;
        v_anno_nascita_cavallo   number;
        v_periodo                number;
        --v_data_gara              VARCHAR2 (8);
        --v_vincite_comitato       NUMBER;
        v_premio                 number;
        v_dati_gara              tc_dati_gara_esterna%rowtype;
    begin
        l_risultati := t_tabella_premi ();

        -- Recupero dati gara
        v_dati_gara := fn_info_gara_esterna (p_gara_id);

        -- Calcolo periodo campo dedotto dalla data della gara
        v_periodo :=
            fn_periodo_salto_ostacoli (v_dati_gara.data_gara_esterna);


        -- Categoria
        select min (anno_nascita_cavallo)
          into v_anno_nascita_cavallo
          from tc_dati_classifica_esterna
         where fk_sequ_id_dati_gara_esterna = p_gara_id;

        for i in 1 .. p_num_partenti
        loop
            v_rec.cavallo_id := 1000 + i;
            v_rec.nome_cavallo := 'Cavallo ' || chr (64 + i);
            v_rec.posizione := i;



            --            CALCOLA_PREMIO_SALTO_OST_2025 (
            --                v_dati_gara,
            --                p_periodo                      => v_periodo,
            --                p_num_partenti                 => p_num_partenti,
            --                p_posizione                    => i,
            --                p_montepremi_tot               => NULL,
            --                p_num_con_parimerito           => 1,
            --                p_SEQU_ID_CLASSIFICA_ESTERNA   => NULL,
            --                p_premio_cavallo               => v_premio);
            --            v_rec.premio := v_premio;
            --            v_rec.note :=
            --                   'v_disciplina: Salto ad Ostacoli ,v_num_partenti:'
            --                || p_num_partenti
            --                || ',v_categoria:'
            --                || v_categoria
            --                || ',v_eta:'
            --                || v_eta;


            l_risultati.extend;
            l_risultati (l_risultati.count) := v_rec;
        end loop;

        for i in 1 .. l_risultati.count
        loop
            pipe row (l_risultati (i));
        end loop;

        return;
    end fn_calcolo_salto_ostacoli_sim;

    function fn_calcolo_dressage_sim (p_gara_id        in number,
                                      p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        l_riga                   t_premio_rec;
        -- v_posizione              NUMBER;
        v_punteggio              number;
        v_premio                 number;
        v_parimerito             number;
        v_montepremi             number;
        v_eta                    number;
        v_data_gara              varchar2 (8);
        v_anno_nascita_cavallo   number;
        v_periodo                number;
        v_dati_gara              tc_dati_gara_esterna%rowtype;
    begin
        -- Recupero dati gara
        v_dati_gara := fn_info_gara_esterna (p_gara_id);

        -- Calcolo periodo
        v_periodo :=
            fn_periodo_salto_ostacoli (v_dati_gara.data_gara_esterna);

        -- Calcolo montepremi reale
        v_montepremi := 10000;


        select min (anno_nascita_cavallo)
          into v_anno_nascita_cavallo
          from tc_dati_classifica_esterna
         where fk_sequ_id_dati_gara_esterna = p_gara_id;

        v_eta :=
              to_number (substr (v_data_gara, 1, 4))
            - nvl (v_anno_nascita_cavallo,
                   to_number (substr (v_data_gara, 1, 4)));


        for v_posizione in 1 .. p_num_partenti
        loop
            v_punteggio := 65 + (5 - v_posizione);

            if mod (v_posizione, 2) = 0
            then
                v_parimerito := 2;
            else
                v_parimerito := 1;
            end if;

--            calcola_premio_dressage_2025 (
--                p_dati_gara                    => v_dati_gara,
--                p_tipo_evento                  =>
--                    fn_desc_tipologica (v_dati_gara.fk_codi_tipo_evento),
--                p_flag_fise                    => 0,
--                p_livello_cavallo              =>
--                    fn_desc_tipologica (v_dati_gara.fk_codi_livello_cavallo),
--                p_posizione                    => v_posizione,
--                p_punteggio                    => v_punteggio,
--                p_montepremi_tot               => null,
--                p_num_con_parimerito           => v_parimerito,
--                p_sequ_id_classifica_esterna   => null,
--                p_numero_giornata              => v_periodo,
--                p_premio_cavallo               => v_premio);


            l_riga.cavallo_id := v_posizione;
            l_riga.nome_cavallo := 'Cavallo ' || chr (64 + v_posizione);
            l_riga.premio := v_premio;
            l_riga.posizione := v_posizione;
            l_riga.note := 'Simulazione posizione ' || v_posizione;

            pipe row (l_riga);
        end loop;

        return;
    end fn_calcolo_dressage_sim;


    function fn_calcolo_endurance_sim (p_gara_id        in number,
                                       p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        l_risultati    t_tabella_premi;
        v_rec          unire_rel2.pkg_calcoli_premi_manifest.t_premio_rec;
        -- v_categoria      VARCHAR2 (50);
        v_montepremi   number := 0;
        --v_num_partenti   NUMBER;
        v_premio       number;
        --v_tipo_evento    VARCHAR2 (50);
        --v_tipo_prova     VARCHAR2 (50);
        v_dati_gara    tc_dati_gara_esterna%rowtype;
    begin
        l_risultati := t_tabella_premi ();

        -- Recupero dati gara
        v_dati_gara := fn_info_gara_esterna (p_gara_id);

        -- Determina il montepremi in base a categoria e tipo evento
        v_montepremi :=
            case upper (fn_desc_tipologica (v_dati_gara.fk_codi_categoria))
                when 'DEBUTTANTI' then 2700
                when 'CEN A' then 3600
                when 'CEN B/R' then 4200
                else -1
            end;

        if c_debug
        then
            dbms_output.put_line (
                   'FN_CALCOLO_ENDURANCE_SIM v_montepremi cat.'
                || fn_desc_tipologica (v_dati_gara.fk_codi_categoria)
                || ' '
                || v_montepremi);
        end if;

        -- Simulazione premi: distribuiamo ai primi 6, se ci sono abbastanza partenti
        for i in 1 .. p_num_partenti
        loop
            v_rec.cavallo_id := 1000 + i;
            v_rec.nome_cavallo := 'Cavallo ' || chr (64 + i);
            v_rec.posizione := i;

            calcola_premio_endurance_2025 (
                p_dati_gara                    => v_dati_gara,
               -- p_categoria                    =>
                --    FN_DESC_TIPOLOGICA (v_dati_gara.FK_CODI_CATEGORIA),
               -- p_tipo_evento                  =>
               --     FN_DESC_TIPOLOGICA (v_dati_gara.FK_CODI_TIPO_EVENTO),
                --p_flag_fise                    => 0,
                p_posizione                    => i,
                p_montepremi_tot               => v_montepremi,
                p_num_con_parimerito           => 1,
                p_premio_cavallo               => v_premio,
                p_sequ_id_classifica_esterna   => null);



            v_rec.premio := v_premio;
            v_rec.note :=
                   'v_disciplina: Endurance ,v_num_partenti:'
                || p_num_partenti
                || ',v_categoria:'
                || fn_desc_tipologica (v_dati_gara.fk_codi_categoria)
                || ',v_tipo_evento:'
                || fn_desc_tipologica (v_dati_gara.fk_codi_tipo_evento)
                || ',v_tipo_prova:'
                || fn_desc_tipologica (v_dati_gara.fk_codi_tipo_prova);


            l_risultati.extend;
            l_risultati (l_risultati.count) := v_rec;
        end loop;

        for i in 1 .. l_risultati.count
        loop
            pipe row (l_risultati (i));
        end loop;

        return;
    end;


    function fn_calcolo_allevatoriale_sim (p_gara_id        in number,
                                           p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        v_dati_gara   tc_dati_gara_esterna%rowtype;
        l_risultati   t_tabella_premi;
        v_rec         unire_rel2.pkg_calcoli_premi_manifest.t_premio_rec;
        v_premio      number;
    begin
        l_risultati := t_tabella_premi ();

        v_dati_gara := fn_info_gara_esterna (p_gara_id);



        for i in 1 .. p_num_partenti
        loop
            v_rec.cavallo_id := 1000 + i;
            v_rec.nome_cavallo := 'Cavallo ' || chr (64 + i);
            v_rec.posizione := i;

            --            CALCOLA_PREMIO_ALLEV_2025 (p_dati_gara                    => v_dati_gara,
            --                                       p_posizione                    => i,
            --                                       p_premiabili                    => p_num_partenti,
            --                                       p_num_con_parimerito           => 1,
            --                                       p_SEQU_ID_CLASSIFICA_ESTERNA   => NULL);

            v_rec.premio := v_premio;
            v_rec.note :=
                   'v_disciplina: Allevatoriale ,v_num_partenti:'
                || p_num_partenti;

            l_risultati.extend;
            l_risultati (l_risultati.count) := v_rec;
        end loop;

        for i in 1 .. l_risultati.count
        loop
            pipe row (l_risultati (i));
        end loop;

        return;
    end fn_calcolo_allevatoriale_sim;

    function fn_calcolo_completo_sim (p_gara_id        in number,
                                      p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        v_dati_gara   tc_dati_gara_esterna%rowtype;
        l_risultati   t_tabella_premi;
        v_rec         unire_rel2.pkg_calcoli_premi_manifest.t_premio_rec;
        v_premio      number;
    begin
        l_risultati := t_tabella_premi ();

        v_dati_gara := fn_info_gara_esterna (p_gara_id);



        for i in 1 .. p_num_partenti
        loop
            v_rec.cavallo_id := 1000 + i;
            v_rec.nome_cavallo := 'Cavallo ' || chr (64 + i);
            v_rec.posizione := i;


            --            CALCOLA_PREMIO_COMPLETO_2025 (
            --                p_dati_gara                    => v_dati_gara,
            --                p_posizione                    => i,
            --                p_tot_partenti                 => p_num_partenti,
            --                p_num_con_parimerito           => 1,
            --                p_premio_cavallo               => v_premio,
            --                p_SEQU_ID_CLASSIFICA_ESTERNA   => NULL);

            v_rec.premio := v_premio;
            v_rec.note :=
                   'v_disciplina:Allevatoriale ,v_num_partenti:'
                || p_num_partenti;

            l_risultati.extend;
            l_risultati (l_risultati.count) := v_rec;
        end loop;

        for i in 1 .. l_risultati.count
        loop
            pipe row (l_risultati (i));
        end loop;

        return;
    end fn_calcolo_completo_sim;

    function fn_calcolo_monta_da_lavoro_sim (p_gara_id        in number,
                                             p_num_partenti   in number)
        return t_tabella_premi
        pipelined
    is
        v_dati_gara   tc_dati_gara_esterna%rowtype;
        l_risultati   t_tabella_premi;
        v_rec         unire_rel2.pkg_calcoli_premi_manifest.t_premio_rec;
        v_premio      number;
    begin
        l_risultati := t_tabella_premi ();

        v_dati_gara := fn_info_gara_esterna (p_gara_id);


        for i in 1 .. p_num_partenti
        loop
            v_rec.cavallo_id := 1000 + i;
            v_rec.nome_cavallo := 'Cavallo ' || chr (64 + i);
            v_rec.posizione := i;


            calcola_premio_monta_2025 (p_dati_gara                    => v_dati_gara,
                                       p_posizione                    => i,
                                       p_tot_partenti                 => p_num_partenti,
                                       p_num_con_parimerito           => 1,
                                       p_premio_cavallo               => v_premio,
                                       p_sequ_id_classifica_esterna   => null);

            v_rec.premio := v_premio;
            v_rec.note :=
                   'v_disciplina: Allevatoriale ,v_num_partenti:'
                || p_num_partenti;

            l_risultati.extend;
            l_risultati (l_risultati.count) := v_rec;
        end loop;

        for i in 1 .. l_risultati.count
        loop
            pipe row (l_risultati (i));
        end loop;

        return;
    end fn_calcolo_monta_da_lavoro_sim;

procedure calcola_premio_dressage_2025(
    p_dati_gara                    in     tc_dati_gara_esterna%rowtype,
    p_posizione                    in     number,
    p_sequ_id_classifica_esterna   in     number,
    p_mappa_premi                  in     pkg_calcoli_premi_manifest.t_mappatura_premi,
    p_premio_cavallo                  out number)
is
    v_id_cavallo          number;
    v_premio_base         number := 0;
    v_num_parimerito      number := 0;
begin
    if c_debug then
        dbms_output.put_line('--- CALCOLA_PREMIO_DRESSAGE_2025 ---');
        dbms_output.put_line('Posizione MASAF: ' || p_posizione);
    end if;
    
    p_premio_cavallo := 0;
    
    -- Check gara premiata
    if fn_gara_premiata_masaf(p_dati_gara.sequ_id_dati_gara_esterna) = 0 and FN_INCENTIVO_MASAF_GARA_FISE(p_dati_gara.sequ_id_dati_gara_esterna) = 0 then
        return;
    end if;
    
    -- ID cavallo dalla classifica
    select fk_sequ_id_cavallo
    into v_id_cavallo
    from tc_dati_classifica_esterna
    where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna;
    
    -- Cerca nella mappa premi
    -- Cerca nella mappa premi e assegna direttamente (premio già diviso per parimerito)
    for i in 1 .. p_mappa_premi.count loop
        if p_mappa_premi(i).id_cavallo = v_id_cavallo then
            p_premio_cavallo := p_mappa_premi(i).premio;
            if c_debug then
                dbms_output.put_line('   Trovato in mappa: fascia=' || p_mappa_premi(i).fascia || 
                                   ', premio=Euro' || p_premio_cavallo);
            end if;
            exit;
        end if;
    end loop;

    
    -- Gestione parimerito: conta quanti hanno stesso punteggio
    if v_premio_base > 0 then
        select count(*)
        into v_num_parimerito
        from tc_dati_classifica_esterna c1
        where c1.fk_sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna
          and c1.nume_punti = (select nume_punti 
                               from tc_dati_classifica_esterna 
                               where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna);
        
        if v_num_parimerito > 1 then
            p_premio_cavallo := round(v_premio_base / v_num_parimerito, 2);
            
            if c_debug then
                dbms_output.put_line('   Parimerito: ' || v_num_parimerito || 
                                   ' cavalli -> premio diviso: Euro' || p_premio_cavallo);
            end if;
        else
            p_premio_cavallo := v_premio_base;
        end if;
    end if;
    
    -- Update DB
    if p_sequ_id_classifica_esterna is not null then
        update tc_dati_classifica_esterna
        set importo_masaf_calcolato = p_premio_cavallo,
            nume_piazzamento_masaf = p_posizione
        where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna
          and nume_piazzamento < 900;
    end if;
    
    if c_debug then
        dbms_output.put_line('Premio finale: Euro' || p_premio_cavallo);
        dbms_output.put_line('--- FINE CALCOLA_PREMIO_DRESSAGE_2025 ---');
    end if;
end calcola_premio_dressage_2025;

function handler_salto_ostacoli (p_gara_id in number)
        return t_tabella_premi
    is
        l_risultati             t_tabella_premi := t_tabella_premi ();
        i                       pls_integer := 0;

        v_dati_gara             tc_dati_gara_esterna%rowtype;
        v_categoria             varchar2 (50);
        v_tipo_distrib          varchar2 (50);
        v_formula               varchar2 (50);
        v_nome_manifestazione   varchar2 (250);
        v_eta                   number;
        v_periodo               number;
        v_num_partenti          number;
        v_montepremi_tot        number := null;
        v_giornata              number;
        v_premio                number;
        v_num_partenti_valido   number := 0; --i partenti che non hanno nume_piazzamento 920 ovvero FUORI GARA
        v_desc_calcolo_premio   varchar2(5000);
        v_desc_calcolo          varchar2(1000);
        v_classifica            pkg_calcoli_premi_manifest.t_classifica;
        v_mappa_premi           pkg_calcoli_premi_manifest.t_mappatura_premi;
               
        cursor c_classifica is
              select rank ()
                         over (
                             order by
                                 case
                                     when t.nume_punti is not null then 1
                                     else 2
                                 end,
                                 t.nume_punti desc,
                                 t.nume_piazzamento asc)    as posizione_masaf,
                     t.*
                from tc_dati_classifica_esterna t
               where     fk_sequ_id_dati_gara_esterna = p_gara_id
                     and t.fk_sequ_id_cavallo is not null
                     and t.nume_piazzamento <> 920 -- 04/12/2025 escludo i FUORI CLASSIFICA o FUORI GARA 
            order by case when t.nume_punti is not null then 1 else 2 end,
                     t.nume_punti desc,
                     t.nume_piazzamento asc;
    begin
         if c_debug
        then
            dbms_output.put_line (CHR(10) || RPAD('=', 80, '='));
            dbms_output.put_line ('   HANDLER SALTO OSTACOLI');
            dbms_output.put_line ('   Gara ID: ' || p_gara_id);
            dbms_output.put_line (RPAD('=', 80, '='));
        end if;

        -- 0. aggiorno le fk sequ id cavallo a null
        --aggiorna_fk_cavallo_classifica (p_gara_id);


        
        
        -- 1. Info gara
        v_dati_gara := fn_info_gara_esterna (p_gara_id);
        v_categoria :=
            upper (fn_desc_tipologica (v_dati_gara.fk_codi_categoria));
        
        v_eta :=
            to_number (
                substr (fn_desc_tipologica (v_dati_gara.fk_codi_eta), 1, 1));
                
                

        -- 2. Numero partenti MASAF compresi i non partiti ma non i ritirati o eliminati
        select count (*)
          into v_num_partenti
          from tc_dati_classifica_esterna
         where     fk_sequ_id_dati_gara_esterna = p_gara_id
               and fk_sequ_id_cavallo is not null
               and nume_piazzamento <> 920; --escludo i FUORI CLASSIFICA o FUORI GARA 04/12/2025

        v_desc_calcolo_premio := 'Calcolo effettuato considerando:'||u'\000A'||' - '||v_num_partenti||' cavalli partenti'||u'\000A';
        if v_num_partenti = 0
        then
            return l_risultati;
        end if;

        -- 3. Periodo e giornata
        v_periodo :=
            fn_periodo_salto_ostacoli (v_dati_gara.data_gara_esterna);
            
        v_desc_calcolo_premio := v_desc_calcolo_premio ||' - Periodo '||v_periodo;
        
        select 1 + trunc(to_date(dg.data_gara_esterna, 'YYYYMMDD'))
             - trunc(to_date(ed.data_inizio_edizione, 'YYYYMMDD'))
        into v_giornata
        from tc_dati_gara_esterna dg
        join tc_dati_edizione_esterna ee 
             on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
        JOIN TC_EDIZIONE ed ON ed.sequ_id_edizione = ee.fk_sequ_id_edizione
        where dg.sequ_id_dati_gara_esterna = p_gara_id;

        v_desc_calcolo_premio := v_desc_calcolo_premio||', Giornata '||v_giornata||u'\000A';
        
        -- 4. Calcolo montepremi
        --v_montepremi_tot :=
         fn_calcola_montepremi_salto (p_dati_gara   => v_dati_gara,
                                         p_periodo     => v_periodo,
                                         p_num_part    => v_num_partenti,
                                         p_giornata    => v_giornata,
                                         p_desc_calcolo_premio => v_desc_calcolo,
                                         p_montepremi  =>v_montepremi_tot);

        v_desc_calcolo_premio := v_desc_calcolo_premio||' - Montepremi '||nvl(v_montepremi_tot,0)||' Euro ('||v_desc_calcolo||')'||u'\000A';
        

 -- Recupero riga la formula dell'edizione
        select upper (mf.desc_formula), upper(mf.DESC_DENOM_MANIFESTAZIONE)
          into v_formula,v_nome_manifestazione
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_gara_id;    
        
      
        DBMS_OUTPUT.PUT_LINE('   >> Tipo v_tipo_distrib: ' || v_nome_manifestazione || ' - '|| v_eta || ' - '|| v_categoria || ' - '|| v_dati_gara.desc_nome_gara_esterna || ' << ');
        -- Tipo distribuzione: MASAF o FISE
       v_tipo_distrib :=
    case
        when v_nome_manifestazione like '%CSIO%ROMA%MASTER%'
        then 'FISE'
        when v_nome_manifestazione like '%FINALE%CIRCUITO%CLASSICO%'
             and upper(v_dati_gara.desc_nome_gara_esterna) like '%CRITERIUM%'
             and v_eta >= 6
        then 'FISE'
        when v_nome_manifestazione like '%CAMPIONATO%MONDO%' -- LANAKEN
        then 'MASAF'
        when v_categoria = 'ELITE' and v_eta = 6
        then 'FISE'
        when v_categoria = 'ALTO' and v_eta between 5 and 7
        then 'FISE'
        when v_categoria = 'SPORT' and v_eta in (6, 7)
        then 'FISE'
        when v_categoria = 'ELITE' and v_eta = 7 
             and instr(v_dati_gara.desc_nome_gara_esterna, 'MISTA') > 0
        then 'FISE'
        when v_categoria = 'ELITE' and v_eta = 7 
             and instr(v_dati_gara.desc_nome_gara_esterna, 'FASI CONS') > 0
        then 'FISE'
        else 'MASAF'
    end;

        
        v_desc_calcolo_premio := v_desc_calcolo_premio||' - Distribuzione: '||v_tipo_distrib|| 
                                 CASE v_tipo_distrib 
                                     WHEN 'MASAF' THEN ' (a Fasce)'||u'\000A' 
                                     ELSE ' (Tabella FISE)' ||u'\000A'
                                 END ||' - Età: '||v_eta||' anni'||u'\000A'||' - Categoria:'|| v_categoria||u'\000A';
            
        IF c_debug THEN
            DBMS_OUTPUT.PUT_LINE('   >> Tipo Distribuzione: ' || v_tipo_distrib || 
                                 CASE v_tipo_distrib 
                                     WHEN 'MASAF' THEN ' (Fasce)' 
                                     ELSE ' (Tabella FISE)' 
                                 END ||' - per v_eta '||v_eta||' v_categoria '|| v_categoria || ' da fk_codi_categoria '||v_dati_gara.fk_codi_categoria);
                                 
        END IF;
        
        -- 6. Costruzione classifica
        declare
            idx   pls_integer := 0;
        begin
            for rec in c_classifica
            loop
                idx := idx + 1;
                v_classifica (idx).id_cavallo := rec.fk_sequ_id_cavallo;
                v_classifica (idx).posizione := rec.posizione_masaf;
                v_classifica (idx).punteggio := rec.nume_punti;
                v_classifica (idx).vincite_fise := rec.vincite_fise;
                v_classifica (idx).posizione_fise := rec.nume_piazzamento;
                v_num_partenti_valido := v_num_partenti_valido + 1;
                --DBMS_OUTPUT.PUT_LINE('   >> v_classifica (idx).posizione: ' ||v_classifica (idx).posizione);
            
            end loop;


       
         -- Calcolo premiabili e fasce MASAF
        if v_tipo_distrib = 'MASAF' and v_formula <> 'FISE' then

            -- CAMPIONATO DEL MONDO GIOVANI CAVALLI   LANAKEN 
            if v_nome_manifestazione like 'CAMPIONATO%MONDO%GIOVANI%' then
                declare
                    v_premio number;
                    v_desc   varchar2(100) := upper(v_dati_gara.desc_nome_gara_esterna);
                begin
                    for i in 1 .. v_classifica.count loop
                        -- Escludi eliminati/ritirati
                        if nvl(v_classifica(i).posizione_fise, 0) >= 900 then
                            v_premio := 0;
                        -- Gare contributo: 2.000 per partecipazione
                        elsif v_desc like '%CONTRIBUTO%' then
                            v_premio := 2000;
                        -- Finale
                        elsif v_desc like '%FINALE%' and v_desc not like '%CONSOLAZIONE%' then
                            v_premio := case
                                when v_classifica(i).posizione_fise = 1 then 6000
                                when v_classifica(i).posizione_fise between 2 and 5 then 3600
                                when v_classifica(i).posizione_fise between 6 and 10 then 2400
                                else 2000
                            end;
                        -- Qualifiche e finale consolazione
                        else
                            v_premio := case
                                when v_classifica(i).posizione_fise = 1 then 1000
                                when v_classifica(i).posizione_fise between 2 and 5 then 600
                                when v_classifica(i).posizione_fise between 6 and 10 then 400
                                else 0
                            end;
                        end if;
                        
                        v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
                        v_mappa_premi(i).premio := v_premio;
                        v_mappa_premi(i).fascia := v_classifica(i).posizione_fise;
                    end loop;
                end;
            
            -- INCENTIVO 10% SALTO AD OSTACOLI (gara FISE in concorso MASAF)
            elsif fn_incentivo_masaf_gara_fise(p_gara_id) > 0 then
                for i in 1 .. v_classifica.count loop
                    v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
                    v_mappa_premi(i).premio := round(v_classifica(i).vincite_fise * 0.1, 2);
                    v_mappa_premi(i).fascia := v_classifica(i).posizione;
                end loop;
                v_desc_calcolo_premio := v_desc_calcolo_premio ||'\tIncentivo\n';
            --elsif v_nome_manifestazione like 'FINALE%CIRCUITO%CLASSICO%' then --Finale Circuito Classico    
              
            
            -- Calcolo standard PREMIABILI MASAF
            else
                declare
                    v_premiabili number;
                    v_desc_fasce varchar2(10000);
                    v_desc_premiabili varchar2(500);
                begin
                
                    fn_calcola_n_premiabili_masaf(
                        p_dati_gara => v_dati_gara,
                        p_num_part  => v_num_partenti_valido,
                        p_n_premiabili => v_premiabili,
                        p_desc_premiabili => v_desc_premiabili);
                        
                    pkg_calcoli_premi_manifest.calcola_fasce_premiabili_masaf(
                        p_classifica          => v_classifica,
                        p_montepremi          => v_montepremi_tot,
                        p_premiabili          => v_premiabili,
                        p_priorita_fasce_alte => false,
                        p_mappa_premi         => v_mappa_premi,
                        p_desc_fasce          => v_desc_fasce);
                        
                     v_desc_calcolo_premio := v_desc_calcolo_premio ||' '||v_desc_premiabili||'. ';
                     v_desc_calcolo_premio := v_desc_calcolo_premio ||' Dettaglio fasce:'||v_desc_fasce||'.';
                end;
            end if;

        elsif v_formula = 'FISE' then
            -- INCENTIVO 10% SALTO AD OSTACOLI
            for i in 1 .. v_classifica.count loop
                v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
                v_mappa_premi(i).premio := round(v_classifica(i).vincite_fise * 0.1, 2);
                v_mappa_premi(i).fascia := v_classifica(i).posizione;
            end loop;
            v_desc_calcolo_premio := v_desc_calcolo_premio ||' Incentivo ';

        else
            -- Costruzione mappa premi FISE standard
            -- forzo la distribuzione a 10 premiati per il CSIO ROMA - MASTER TALENT  e per la FINALE CIRCUITO CLASSICO come da disciplinare
             if v_nome_manifestazione like '%CSIO%ROMA%MASTER%' or v_nome_manifestazione like '%FINALE%CIRCUITO%CLASSICO%' then
                 
                for i in 1 .. v_classifica.count loop
                    
                    v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
                    -- Se è un ritirato 910 non lo premio o anche un eliminato
                    if fn_conta_parimerito(v_dati_gara, v_classifica(i).posizione) <> 0 then
                        v_mappa_premi(i).premio := fn_premio_distribuzione_csio(
                            posizione          => v_classifica(i).posizione,
                            num_con_parimerito => fn_conta_parimerito(v_dati_gara, v_classifica(i).posizione),
                            montepremi         => v_montepremi_tot);
                        else
                        v_mappa_premi(i).premio := 0;
                    end if;
                    v_mappa_premi(i).fascia := v_classifica(i).posizione;
                end loop;
            
            else 
                for i in 1 .. v_classifica.count loop
                    v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
                    v_mappa_premi(i).premio := fn_premio_distribuzione_fise(
                        num_partiti        => v_num_partenti,
                        posizione          => v_classifica(i).posizione,
                        num_con_parimerito => fn_conta_parimerito(v_dati_gara, v_classifica(i).posizione),
                        montepremi         => v_montepremi_tot);
                    v_mappa_premi(i).fascia := v_classifica(i).posizione;
                end loop;
            
            end if; 
        end if;
        end;

        -- 7. Ciclo sui cavalli per assegnare premi
        i := 0;

        for rec in c_classifica
        loop
            calcola_premio_salto_ost_2025 (
                p_dati_gara                    => v_dati_gara,
                p_posizione                    => rec.posizione_masaf,
                p_sequ_id_classifica_esterna   =>
                    rec.sequ_id_classifica_esterna, 
                p_mappa_premi                  => v_mappa_premi,
                p_premio_cavallo               => v_premio);

            i := i + 1;
            l_risultati.extend;
            l_risultati (i).cavallo_id := rec.fk_sequ_id_cavallo;
            l_risultati (i).nome_cavallo := rec.desc_cavallo;
            l_risultati (i).premio := v_premio;
            l_risultati (i).posizione := rec.nume_piazzamento;
        end loop;
        
        update tc_dati_gara_esterna set DESC_CALCOLO_PREMI = v_desc_calcolo_premio where SEQU_ID_DATI_GARA_ESTERNA = p_gara_id ;
        commit;
        
        if c_debug
        then
            dbms_output.put_line (CHR(10) || RPAD('=', 80, '='));
            dbms_output.put_line ('   FINE HANDLER SALTO OSTACOLI - Gara ID: ' || p_gara_id);
            dbms_output.put_line (v_desc_calcolo_premio);
            dbms_output.put_line (RPAD('=', 80, '=') || CHR(10));
        end if;
        
        
        return l_risultati;
    exception
        when others
        then
            dbms_output.put_line (
                'ERRORE HANDLER_SALTO_OSTACOLI: ' || sqlerrm);
            raise;
end;



    -- HANDLER DRESSAGE
function handler_dressage(p_gara_id in number)
    return t_tabella_premi
is
    l_risultati            t_tabella_premi := t_tabella_premi();
    i                      pls_integer := 0;
    
    v_dati_gara            tc_dati_gara_esterna%rowtype;
    v_premio               number;
    v_num_partenti         number := 0;
    v_num_partenti_valido  number := 0;
    v_giornata             number;
    v_nome_manifestazione  varchar2(500);
    v_formula              varchar2(50);
    v_eta_cavalli          number;
    v_montepremi_tot       number := 0;
    v_soglia_punteggio     number;
    idx                    pls_integer := 0;
    
    v_classifica           pkg_calcoli_premi_manifest.t_classifica;
    v_mappa_premi          pkg_calcoli_premi_manifest.t_mappatura_premi;
    
    -- Variabili per gestione parimerito
    v_percentuali          sys.odcinumberlist;
    v_max_premiati         pls_integer;
    v_pos_corrente         pls_integer;
    v_num_parimerito       pls_integer;
    v_premio_diviso        number;
    v_idx_mappa            pls_integer;
    
    cursor c_classifica is
        select rank() over (
                   order by nvl(t.nume_punti, 0) desc,
                            t.nume_piazzamento asc
               ) as posizione_masaf,
               t.*
        from tc_dati_classifica_esterna t
        where fk_sequ_id_dati_gara_esterna = p_gara_id
          and t.fk_sequ_id_cavallo is not null
          and t.nume_piazzamento < 900
        order by nvl(t.nume_punti, 0) desc,
                 t.nume_piazzamento asc;
begin
    if c_debug then
        dbms_output.put_line(chr(10) || rpad('=', 80, '='));
        dbms_output.put_line('   HANDLER DRESSAGE');
        dbms_output.put_line('   Gara ID: ' || p_gara_id);
        dbms_output.put_line(rpad('=', 80, '='));
    end if;
    
    -- 1. Info gara
    v_dati_gara := fn_info_gara_esterna(p_gara_id);
    
    -- 2. Numero partenti totali
    select count(*)
      into v_num_partenti
      from tc_dati_classifica_esterna
     where fk_sequ_id_dati_gara_esterna = p_gara_id
       and fk_sequ_id_cavallo is not null
       and nume_piazzamento < 900;
    
    if v_num_partenti = 0 then
        return l_risultati;
    end if;
    
    -- 3. Calcolo giornata
    select 1 + trunc(to_date(dg.data_gara_esterna, 'YYYYMMDD'))
             - trunc(to_date(ed.data_inizio_edizione, 'YYYYMMDD'))
      into v_giornata
      from tc_dati_gara_esterna dg
      join tc_dati_edizione_esterna ee on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
      join tc_edizione ed on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
     where dg.sequ_id_dati_gara_esterna = p_gara_id;
    
    if c_debug then
        dbms_output.put_line('>> 4. Nome manifestazione ed età');
    end if;
    
    -- 4. Nome manifestazione ed età
    select upper(mf.desc_denom_manifestazione)
      into v_nome_manifestazione
      from tc_dati_gara_esterna dg
      join tc_dati_edizione_esterna ee on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
      join tc_edizione ed on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
      join tc_manifestazione mf on mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
     where dg.sequ_id_dati_gara_esterna = p_gara_id;
    
    if v_dati_gara.fk_codi_eta is not null then
        v_eta_cavalli := to_number(substr(fn_desc_tipologica(v_dati_gara.fk_codi_eta), 1, 1));
    else
        v_eta_cavalli := case
            when upper(v_dati_gara.desc_nome_gara_esterna) like '%4%ANNI%' then 4
            when upper(v_dati_gara.desc_nome_gara_esterna) like '%5%ANNI%' then 5
            when upper(v_dati_gara.desc_nome_gara_esterna) like '%6%ANNI%' then 6
            when upper(v_dati_gara.desc_nome_gara_esterna) like '%7%ANNI%' then 7
            when upper(v_dati_gara.desc_nome_gara_esterna) like '%8%ANNI%' then 8
            else null
        end;
    end if;

    -- 5. Determina soglia e montepremi
    if v_nome_manifestazione = 'CIRCUITO MASAF DI DRESSAGE' then
        if v_giornata != 2 then
            if c_debug then
                dbms_output.put_line('>> Tappa giornata ' || v_giornata || ': non premiata (solo giornata 2)');
            end if;
            return l_risultati;
        end if;
    
        if v_eta_cavalli in (5, 6, 7, 8) then
            if instr(upper(v_dati_gara.desc_nome_gara_esterna), 'PRELIMINARY') > 0 
               or instr(upper(v_dati_gara.desc_nome_gara_esterna), 'PRELIMINARE') > 0 then
                if c_debug then
                    dbms_output.put_line('>> Gara PRELIMINARY: non premiata (solo FINALE è premiata)');
                end if;
                return l_risultati;
            end if;
        end if;
        
        v_soglia_punteggio := 60;
        v_montepremi_tot := case v_eta_cavalli
            when 4 then 2500
            when 5 then 2800
            when 6 then 3200
            when 7 then 1500
            when 8 then 1500
            else 0
        end;
    elsif v_nome_manifestazione like 'FINALE%DRESSAGE%' then
        v_soglia_punteggio := 62;
        v_montepremi_tot := case v_eta_cavalli
            when 4 then 8000
            when 5 then 8000
            when 6 then 8000
            when 7 then 3000
            when 8 then 3000
            else 0
        end;
    elsif pkg_calcoli_premi_manifest.fn_incentivo_masaf_gara_fise(p_gara_id) = 0 then
        if c_debug then
            dbms_output.put_line('>> Manifestazione non premiata: ' || v_nome_manifestazione);
        end if;
        return l_risultati;
    else 
        v_soglia_punteggio := 0;
    end if;
    
    if c_debug then
        dbms_output.put_line('>> Manifestazione: ' || v_nome_manifestazione);
        dbms_output.put_line('>> Gara: ' || v_dati_gara.desc_nome_gara_esterna);        
        dbms_output.put_line('>> Età: ' || v_eta_cavalli || ' anni');
        dbms_output.put_line('>> Giornata: ' || v_giornata);
        dbms_output.put_line('>> Soglia punteggio: ' || v_soglia_punteggio || '%');
        dbms_output.put_line('>> Montepremi totale: ' || v_montepremi_tot);
    end if;
    
    -- 6. Costruzione classifica con posizione RANK (per parimerito)
    for rec in c_classifica loop
        if nvl(rec.nume_punti, 0) >= v_soglia_punteggio then
            idx := idx + 1;
            v_classifica(idx).id_cavallo := rec.fk_sequ_id_cavallo;
            v_classifica(idx).posizione := rec.posizione_masaf;  -- USA IL RANK, NON L'INDICE
            v_classifica(idx).punteggio := rec.nume_punti;
            v_classifica(idx).vincite_fise := rec.vincite_fise;
            v_num_partenti_valido := v_num_partenti_valido + 1;
        end if;
    end loop;
    
    if c_debug then
        dbms_output.put_line('>> Partenti con soglia >= ' || v_soglia_punteggio || '%: ' || v_num_partenti_valido);
    end if;
    
    if v_num_partenti_valido = 0 then
        if c_debug then
            dbms_output.put_line('>> Nessun cavallo supera la soglia minima');
        end if;
        return l_risultati;
    end if;
    
    -- Recupero formula
    select upper(mf.desc_formula)
      into v_formula
      from tc_dati_gara_esterna dg
      join tc_dati_edizione_esterna ee on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
      join tc_edizione ed on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
      join tc_manifestazione mf on mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
     where dg.sequ_id_dati_gara_esterna = p_gara_id; 
    
    -- 7. Costruzione mappa premi con gestione parimerito
    v_idx_mappa := 0;
    
    if v_formula = 'FISE' then
        v_soglia_punteggio := 0;
        -- INCENTIVO 10%: nessun parimerito da gestire, premio individuale
        for i in 1 .. v_classifica.count loop
            v_idx_mappa := v_idx_mappa + 1;
            v_mappa_premi(v_idx_mappa).id_cavallo := v_classifica(i).id_cavallo;
            v_mappa_premi(v_idx_mappa).premio := round(v_classifica(i).vincite_fise * 0.1, 2);
            v_mappa_premi(v_idx_mappa).fascia := v_classifica(i).posizione;
        end loop;
    else
        -- Determina percentuali e max premiati in base all'età
        if v_eta_cavalli in (7, 8) then
            v_percentuali := sys.odcinumberlist(0.50, 0.30, 0.20);
            v_max_premiati := 3;
        else
            v_percentuali := sys.odcinumberlist(0.35, 0.22, 0.17, 0.14, 0.12);
            v_max_premiati := 5;
        end if;
        
        -- Costruisci mappa con gestione parimerito
        v_pos_corrente := 1;
        while v_pos_corrente <= v_max_premiati loop
            -- Conta parimerito per questa posizione
            v_num_parimerito := 0;
            for j in 1 .. v_classifica.count loop
                if v_classifica(j).posizione = v_pos_corrente then
                    v_num_parimerito := v_num_parimerito + 1;
                end if;
            end loop;
            
            exit when v_num_parimerito = 0;  -- Nessun cavallo in questa posizione
            
            -- Calcola premio diviso per i parimerito
            if v_pos_corrente <= v_percentuali.count then
                v_premio_diviso := round(v_montepremi_tot * v_percentuali(v_pos_corrente) / v_num_parimerito, 2);
            else
                v_premio_diviso := 0;
            end if;
            
            -- Assegna a tutti i cavalli in questa posizione
            for j in 1 .. v_classifica.count loop
                if v_classifica(j).posizione = v_pos_corrente then
                    v_idx_mappa := v_idx_mappa + 1;
                    v_mappa_premi(v_idx_mappa).id_cavallo := v_classifica(j).id_cavallo;
                    v_mappa_premi(v_idx_mappa).fascia := v_pos_corrente;
                    v_mappa_premi(v_idx_mappa).premio := v_premio_diviso;
                    
                    if c_debug then
                        dbms_output.put_line('   Pos ' || v_pos_corrente || 
                                           ' (pari=' || v_num_parimerito || '): ID=' || 
                                           v_classifica(j).id_cavallo || ', Premio=' || v_premio_diviso);
                    end if;
                end if;
            end loop;
            
            -- Prossima posizione (salta le posizioni "consumate" dai parimerito)
            v_pos_corrente := v_pos_corrente + v_num_parimerito;
        end loop;
    end if;
    
    -- 8. Assegnazione premi
    i := 0;
    for rec in c_classifica loop
        if nvl(rec.nume_punti, 0) < v_soglia_punteggio then
            continue;
        end if;
        
        calcola_premio_dressage_2025(
            p_dati_gara                  => v_dati_gara,
            p_posizione                  => rec.posizione_masaf,
            p_sequ_id_classifica_esterna => rec.sequ_id_classifica_esterna,
            p_mappa_premi                => v_mappa_premi,
            p_premio_cavallo             => v_premio);
        
        i := i + 1;
        l_risultati.extend;
        l_risultati(i).cavallo_id := rec.fk_sequ_id_cavallo;
        l_risultati(i).nome_cavallo := rec.desc_cavallo;
        l_risultati(i).premio := v_premio;
        l_risultati(i).posizione := rec.nume_piazzamento;
        l_risultati(i).note := 'v_disciplina:Dressage,punteggio:' || rec.nume_punti || '%';
    end loop;
    
    if c_debug then
        dbms_output.put_line(chr(10) || rpad('=', 80, '='));
        dbms_output.put_line('   FINE HANDLER DRESSAGE - Gara ID: ' || p_gara_id);
        dbms_output.put_line(rpad('=', 80, '=') || chr(10));
    end if;
    
    commit;
    return l_risultati;
    
exception
    when others then
        dbms_output.put_line('ERRORE HANDLER_DRESSAGE: ' || sqlerrm);
        raise;
end handler_dressage;
--function handler_dressage (p_gara_id in number)
--    return t_tabella_premi
--is
--    l_risultati            t_tabella_premi := t_tabella_premi ();
--    i                      pls_integer := 0;
--    
--    v_dati_gara            tc_dati_gara_esterna%rowtype;
--    v_premio               number;
--    v_num_partenti         number := 0;
--    v_num_partenti_valido  number := 0;
--    v_giornata             number;
--    v_nome_manifestazione  varchar2(500);
--    v_formula              varchar2(50);
--    v_eta_cavalli          number;
--    v_montepremi_tot       number := 0;
--    v_soglia_punteggio     number;
--    idx                    pls_integer := 0;
--    
--    v_classifica           pkg_calcoli_premi_manifest.t_classifica;
--    v_mappa_premi          pkg_calcoli_premi_manifest.t_mappatura_premi;
--    
--    cursor c_classifica is
--        select rank() over (
--                   order by nvl(t.nume_punti, 0) desc,
--                            t.nume_piazzamento asc
--               ) as posizione_masaf,
--               t.*
--        from tc_dati_classifica_esterna t
--        where fk_sequ_id_dati_gara_esterna = p_gara_id
--          and t.fk_sequ_id_cavallo is not null
--          and t.nume_piazzamento < 900
--        order by nvl(t.nume_punti, 0) desc,
--                 t.nume_piazzamento asc;
--begin
--    if c_debug then
--        dbms_output.put_line(chr(10) || rpad('=', 80, '='));
--        dbms_output.put_line('   HANDLER DRESSAGE');
--        dbms_output.put_line('   Gara ID: ' || p_gara_id);
--        dbms_output.put_line(rpad('=', 80, '='));
--    end if;
--    
--    -- 0. Aggiorna FK cavallo ormai si fa da gareipppiche in automatico
--    --aggiorna_fk_cavallo_classifica(p_gara_id);
--    
--    -- 1. Info gara
--    v_dati_gara := fn_info_gara_esterna(p_gara_id);
--    
--    -- 2. Numero partenti totali
--    select count(*)
--    into v_num_partenti
--    from tc_dati_classifica_esterna
--    where fk_sequ_id_dati_gara_esterna = p_gara_id
--      and fk_sequ_id_cavallo is not null
--      and nume_piazzamento < 900;
--    
--    if v_num_partenti = 0 then
--        return l_risultati;
--    end if;
--    
--    -- 3. Calcolo giornata
--    select 1 + trunc(to_date(dg.data_gara_esterna, 'YYYYMMDD'))
--             - trunc(to_date(ed.data_inizio_edizione, 'YYYYMMDD'))
--    into v_giornata
--    from tc_dati_gara_esterna dg
--    join tc_dati_edizione_esterna ee 
--         on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
--    JOIN TC_EDIZIONE ed ON ed.sequ_id_edizione = ee.fk_sequ_id_edizione
--    where dg.sequ_id_dati_gara_esterna = p_gara_id;
--     if c_debug then
--            dbms_output.put_line('>> 4. Nome manifestazione ed età');
--        end if;
--    -- 4. Nome manifestazione ed età
--    select upper(mf.desc_denom_manifestazione)
--    into v_nome_manifestazione
--    from tc_dati_gara_esterna dg
--    join tc_dati_edizione_esterna ee on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
--    join tc_edizione ed on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
--    join tc_manifestazione mf on mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
--    where dg.sequ_id_dati_gara_esterna = p_gara_id;
--    
--    if v_dati_gara.fk_codi_eta is not null then
--        v_eta_cavalli := to_number(substr(fn_desc_tipologica(v_dati_gara.fk_codi_eta), 1, 1));
--    else
--        v_eta_cavalli := case
--            when upper(v_dati_gara.desc_nome_gara_esterna) like '%4%ANNI%' then 4
--            when upper(v_dati_gara.desc_nome_gara_esterna) like '%5%ANNI%' then 5
--            when upper(v_dati_gara.desc_nome_gara_esterna) like '%6%ANNI%' then 6
--            when upper(v_dati_gara.desc_nome_gara_esterna) like '%7%ANNI%' then 7
--            when upper(v_dati_gara.desc_nome_gara_esterna) like '%8%ANNI%' then 8
--            else null
--        end;
--    end if;
--
--    -- 5. Determina soglia e montepremi
--    if v_nome_manifestazione = 'CIRCUITO MASAF DI DRESSAGE' then
--    -- TAPPE: solo 2° giornata, soglia 60%
--        if v_giornata != 2 then
--            if c_debug then
--                dbms_output.put_line('>> Tappa giornata ' || v_giornata || ': non premiata (solo giornata 2)');
--            end if;
--            return l_risultati;
--        end if;
--    
--        -- NUOVO CONTROLLO: Escludi gare PRELIMINARY (solo FINALE è premiata)
--        -- Per cavalli 4 anni non c'è distinzione PRELIMINARY/FINALE
--        if v_eta_cavalli in (5, 6, 7, 8) then
--            if instr(upper(v_dati_gara.desc_nome_gara_esterna), 'PRELIMINARY') > 0 
--               or instr(upper(v_dati_gara.desc_nome_gara_esterna), 'PRELIMINARE') > 0 then
--                if c_debug then
--                    dbms_output.put_line('>> Gara PRELIMINARY: non premiata (solo FINALE è premiata)');
--                end if;
--                return l_risultati;
--            end if;
--        end if;
--        
--        v_soglia_punteggio := 60;
--        v_montepremi_tot := case v_eta_cavalli
--            when 4 then 2500
--            when 5 then 2800
--            when 6 then 3200
--            when 7 then 1500
--            when 8 then 1500
--            else 0
--        end;
--    
--elsif v_nome_manifestazione like 'FINALE%DRESSAGE%' then
--    -- FINALI: soglia 124% (somma 2 prove, 62% media)
--    v_soglia_punteggio := 62;  -- Controllo media per prova
--    v_montepremi_tot := case v_eta_cavalli
--        when 4 then 8000
--        when 5 then 8000
--        when 6 then 8000
--        when 7 then 3000
--        when 8 then 3000
--        else 0
--    end;
--elsif pkg_calcoli_premi_manifest.FN_INCENTIVO_MASAF_GARA_FISE(p_gara_id) = 0 then
--    if c_debug then
--        dbms_output.put_line('>> Manifestazione non premiata: ' || v_nome_manifestazione);
--    end if;
--    return l_risultati;
--else 
--    v_soglia_punteggio := 0;
--end if;
--    
--    if c_debug then
--        dbms_output.put_line('>> Manifestazione: ' || v_nome_manifestazione);
--        dbms_output.put_line('>> Gara: ' || v_dati_gara.desc_nome_gara_esterna);        
--        dbms_output.put_line('>> Età: ' || v_eta_cavalli || ' anni');
--        dbms_output.put_line('>> Giornata: ' || v_giornata);
--        dbms_output.put_line('>> Soglia punteggio: ' || v_soglia_punteggio || '%');
--        dbms_output.put_line('>> Montepremi totale: ' || v_montepremi_tot);
--    end if;
--    
--     -- 6. Costruzione classifica 
--    for rec in c_classifica loop
--        -- Applica filtro soglia punteggio
--        if nvl(rec.nume_punti, 0) >= v_soglia_punteggio then
--            idx := idx + 1;
--            v_classifica(idx).id_cavallo := rec.fk_sequ_id_cavallo;
--            v_classifica(idx).posizione := idx;  -- Posizione MASAF ricaccolata
--            v_classifica(idx).punteggio := rec.nume_punti;
--            v_classifica(idx).vincite_fise := rec.vincite_fise;
--            v_num_partenti_valido := v_num_partenti_valido + 1;
--        end if;
--    end loop;
--    
--    if c_debug then
--        dbms_output.put_line('>> Partenti con soglia >= ' || v_soglia_punteggio || '%: ' || v_num_partenti_valido);
--    end if;
--    
--    if v_num_partenti_valido = 0 then
--        if c_debug then
--            dbms_output.put_line('>> Nessun cavallo supera la soglia minima');
--        end if;
--        return l_risultati;
--    end if;
--    
--    -- Se per incentivi Masaaf in gare FISE 
--    -- Recupero riga la formula dell'edizione
--        select upper (mf.desc_formula)
--          into v_formula
--          from tc_dati_gara_esterna  dg
--               join tc_dati_edizione_esterna ee
--                   on ee.sequ_id_dati_edizione_esterna =
--                      dg.fk_sequ_id_dati_ediz_esterna
--               join tc_edizione ed
--                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
--               join tc_manifestazione mf
--                   on mf.sequ_id_manifestazione =
--                      ed.fk_sequ_id_manifestazione
--         where dg.sequ_id_dati_gara_esterna = p_gara_id; 
--    
----            if c_debug then
----                dbms_output.put_line('>>v_formula :'||v_formula);
----            end if;
--
--    if v_formula = 'FISE' then
--                        v_soglia_punteggio:= 0;
--                --INCENTIVO 10% 
--                        for i in 1 .. v_classifica.count
--                        loop
--                            v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;
--                            v_mappa_premi (i).premio :=ROUND(v_classifica (i).vincite_fise * 0.1,2); --INCENTIVO del 10%
--                            v_mappa_premi (i).fascia := v_classifica (i).posizione;
--                        end loop;
--    else
--    
--   
--        if v_eta_cavalli in (7,8) then
--        -- 7. Costruzione mappa premi: per 7 e 8 anni si premiano i primi 3
--        -- 1°=50%, 2°=30%, 3°=20%
--            if c_debug then
--                dbms_output.put_line('>> v_classifica.count :'||v_classifica.count);
--            end if;
--                for i in 1 ..  v_classifica.count loop
--                if c_debug then
--                dbms_output.put_line('>> i.count :'||i);
--            end if;
--                    v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
--                    v_mappa_premi(i).fascia := i;
--                    -- Percentuali fisse dressage 7 e 8 anni 
--                    v_mappa_premi(i).premio := case i
--                        when 1 then round(v_montepremi_tot * 0.50, 2)
--                        when 2 then round(v_montepremi_tot * 0.30, 2)
--                        when 3 then round(v_montepremi_tot * 0.20, 2)
--                        else 0
--                    end;
--                    if c_debug then
--                dbms_output.put_line('>> i.premio :'||v_mappa_premi(i).premio );
--            end if;if c_debug then
--                    dbms_output.put_line('   Pos ' || i || ': ID=' || v_mappa_premi(i).id_cavallo || 
--                                       ', Premio= ' || v_mappa_premi(i).premio);
--                end if;
--                end loop;
--        
--                
--        else
--        -- 7. Costruzione mappa premi: solo primi 5 con distribuzione fissa
--        -- 1°=35%, 2°=22%, 3°=17%, 4°=14%, 5°=12%
--        
--            for i in 1 .. least(5, v_classifica.count) loop
--                v_mappa_premi(i).id_cavallo := v_classifica(i).id_cavallo;
--                v_mappa_premi(i).fascia := i;
--                
--                -- Percentuali fisse dressage
--                v_mappa_premi(i).premio := case i
--                    when 1 then round(v_montepremi_tot * 0.35, 2)
--                    when 2 then round(v_montepremi_tot * 0.22, 2)
--                    when 3 then round(v_montepremi_tot * 0.17, 2)
--                    when 4 then round(v_montepremi_tot * 0.14, 2)
--                    when 5 then round(v_montepremi_tot * 0.12, 2)
--                    else 0
--                end;
--               
--                if c_debug then
--                    dbms_output.put_line('   Pos ' || i || ': ID=' || v_mappa_premi(i).id_cavallo || 
--                                       ', Premio= ' || v_mappa_premi(i).premio);
--                end if;
--                end loop;
--         end if;
--    end if;
--    
--    
--  
--    -- 8. Assegnazione premi con gestione parimerito
--    i := 0;
--    for rec in c_classifica loop
--        -- Salta chi non supera soglia
--        if nvl(rec.nume_punti, 0) < v_soglia_punteggio then
--            continue;
--        end if;
--        
--        CALCOLA_PREMIO_DRESSAGE_2025(
--            p_dati_gara                    => v_dati_gara,
--            p_posizione                    => rec.posizione_masaf,
--            p_sequ_id_classifica_esterna   => rec.sequ_id_classifica_esterna,
--            p_mappa_premi                  => v_mappa_premi,
--            p_premio_cavallo               => v_premio);
--        
--        i := i + 1;
--        l_risultati.extend;
--        l_risultati(i).cavallo_id := rec.fk_sequ_id_cavallo;
--        l_risultati(i).nome_cavallo := rec.desc_cavallo;
--        l_risultati(i).premio := v_premio;
--        l_risultati(i).posizione := rec.nume_piazzamento;
--        l_risultati(i).note := 'v_disciplina:Dressage,punteggio:' || rec.nume_punti || '%';
--    end loop;
--    
--    if c_debug then
--        dbms_output.put_line(chr(10) || rpad('=', 80, '='));
--        dbms_output.put_line('   FINE HANDLER DRESSAGE - Gara ID: ' || p_gara_id);
--        dbms_output.put_line(rpad('=', 80, '=') || chr(10));
--    end if;
--    
--    commit;
--
--    return l_risultati;
--exception
--    when others then
--        dbms_output.put_line('ERRORE HANDLER_DRESSAGE: ' || sqlerrm);
--        raise;
--end handler_dressage;


    -- HANDLER ENDURANCE
function handler_endurance (p_gara_id in number)
        return t_tabella_premi
    is
        l_risultati      t_tabella_premi := t_tabella_premi ();
        i                pls_integer := 0;

        v_num_partenti   number;
        v_premio         number;
        v_montepremi     number := 0;

        type t_mappa_parimerito is table of pls_integer
            index by pls_integer;

        v_parimerito     t_mappa_parimerito;
        v_dati_gara      tc_dati_gara_esterna%rowtype;
        v_tipo_evento varchar2(50);
        cursor c_classifica is
            select rank ()
                         over (
                             order by
                                 case
                                     when t.nume_punti is not null then 1
                                     else 2
                                 end,
                                 t.nume_punti desc,
                                 t.nume_piazzamento asc)    as posizione_masaf,
                     t.*
                from tc_dati_classifica_esterna t
               where     fk_sequ_id_dati_gara_esterna = p_gara_id
                     and t.fk_sequ_id_cavallo is not null
                     and t.nume_piazzamento < 900 -- escludo i non arrivati nella classifica
            order by case when t.nume_punti is not null then 1 else 2 end,
                     t.nume_punti desc,
                     t.nume_piazzamento asc;
    begin
        -- Recupero dati gara
        v_dati_gara := fn_info_gara_esterna (p_gara_id);
        v_tipo_evento := upper(fn_desc_tipologica (v_dati_gara.fk_codi_tipo_evento));
         
        if c_debug
        then
        dbms_output.put_line (
                   '--- HANDLER_ENDURANCE --- ( gara_id '
                || p_gara_id
                || ')');
            dbms_output.put_line (
                   'Nome gara= '
                || v_dati_gara.desc_nome_gara_esterna
               );
                 dbms_output.put_line (
                   'Tipo Evento = '
                || v_tipo_evento || ' ('||v_dati_gara.fk_codi_tipo_evento||')'
               );
        end if;
    
        -- Determina il montepremi in base a categoria e tipo evento
            
        if v_tipo_evento = 'FINALE' then
         v_montepremi :=
            case upper(v_dati_gara.desc_nome_gara_esterna)
                when 'CEI1*' then 35000
                when 'CEN A' then 25000
                when 'DEBUTTANTI' then 20000
                when 'CEI2*' then 10000 -- CAMPIONATO 
                else 0
            end;
        end if;
            
            
            
        if c_debug
        then
            dbms_output.put_line (
                   'v_montepremi '
                || v_montepremi);
        end if;
        
        -- Mappa parimerito
        -- Mappa parimerito (LOGICA CORRETTA)
        for rec in (
            select
                posizione_masaf, count(*) as conta
            from (
                -- Uso la stessa query del cursore c_classifica per calcolare la posizione
                select rank () over (
                         order by
                             case when t.nume_punti is not null then 1 else 2 end,
                             t.nume_punti desc,
                             t.nume_piazzamento asc
                        ) as posizione_masaf
                from tc_dati_classifica_esterna t
                where fk_sequ_id_dati_gara_esterna = p_gara_id
                  and t.fk_sequ_id_cavallo is not null
                  and t.nume_piazzamento < 900
            )
            group by posizione_masaf
        )
        loop
            v_parimerito (rec.posizione_masaf) := rec.conta;
        end loop;


        if v_num_partenti = 0
        then
            return l_risultati;
        end if;

        -- Ciclo premi Endurance
        for rec in c_classifica
        loop
            
            calcola_premio_endurance_2025 (
                p_dati_gara        => v_dati_gara,
                p_posizione        => rec.posizione_masaf,
                p_montepremi_tot   => v_montepremi,
                p_num_con_parimerito   =>
                    nvl (v_parimerito (rec.posizione_masaf), 1),
                p_premio_cavallo   => v_premio,
                p_sequ_id_classifica_esterna   =>
                    rec.sequ_id_classifica_esterna);
            
            i := i + 1;
            l_risultati.extend;
            l_risultati (i).cavallo_id := rec.fk_sequ_id_cavallo;
            l_risultati (i).nome_cavallo := rec.desc_cavallo;
            l_risultati (i).premio := v_premio;
            l_risultati (i).posizione := rec.posizione_masaf;
            l_risultati (i).note := 'nessuna';

            commit;
        end loop;

        return l_risultati;
    exception
        when others
        then
            dbms_output.put_line ('ERRORE HANDLER_ENDURANCE: ' || sqlerrm);
            raise;
    end;

    function handler_allevatoriale (p_gara_id in number)
        return t_tabella_premi
    is
        l_risultati             t_tabella_premi := t_tabella_premi ();
        i                       pls_integer := 0;

        v_dati_gara             tc_dati_gara_esterna%rowtype;
        v_premio                number;
        v_num_partenti          number := 0;
        v_num_partenti_valido   number := 0;
        v_id_gara_altra         number;
        v_premiabili            number;
        v_montepremi_tot        number;
        v_desc_premiabili               varchar2(500);
        v_desc_fasce  varchar2(500);
        idx                     pls_integer := 0;

        v_classifica            pkg_calcoli_premi_manifest.t_classifica;
        v_mappa_premi           pkg_calcoli_premi_manifest.t_mappatura_premi;

        cursor c_classifica is
              select rank ()
                         over (
                             order by
                                 case
                                     when t.nume_punti is not null then 1
                                     else 2
                                 end,
                                 t.nume_punti desc,
                                 t.nume_piazzamento asc)    as posizione_masaf,
                     t.*
                from tc_dati_classifica_esterna t
               where     fk_sequ_id_dati_gara_esterna = p_gara_id
                     and t.fk_sequ_id_cavallo is not null
                     and t.nume_piazzamento < 930 -- escludo i non partiti nella classifica
            order by case when t.nume_punti is not null then 1 else 2 end,
                     t.nume_punti desc,
                     t.nume_piazzamento asc;
    begin
        if c_debug
        then
            dbms_output.put_line ('HANDLER_ALLEVATORIALE ');
        end if;

        ----------------------------------------------------------------------------
        -- 1) Recupero della riga di gara (tc_dati_gara_esterna) in base a p_gara_id
        ----------------------------------------------------------------------------

        v_dati_gara := fn_info_gara_esterna (p_gara_id);
        l_risultati := t_tabella_premi ();
        
         -- 2. Numero partenti MASAF
        select count (*)
          into v_num_partenti
          from tc_dati_classifica_esterna
         where     fk_sequ_id_dati_gara_esterna = p_gara_id
               and fk_sequ_id_cavallo is not null
               and nume_piazzamento < 930; --910 ritirato , 930 non partito, 900 eliminato ma considerato partente

        if v_num_partenti = 0
        then
            return l_risultati;
        end if;

        ----------------------------------------------------------------------------
        -- Nel caso sia una gara foal devo richiamare ELABORA_PREMI_FOAL_ANNO
        ----------------------------------------------------------------------------

        if upper (v_dati_gara.desc_nome_gara_esterna) like '%FOAL%'
        then
            if c_debug
            then
                dbms_output.put_line ('ELABORO UNA GARA FOAL ');
            end if;

            -- Se almeno 4 partecipanti: elaborazione singola
            if v_num_partenti >= 4
            then
                if c_debug
                then
                    dbms_output.put_line ('Gara con più di 4 partecipanti ');
                end if;

                pkg_calcoli_premi_manifest.calcola_premio_foals_2025 (
                    p_id_gara_1   => p_gara_id,
                    p_id_gara_2   => null);
            else
                -- Cerca un'altra gara FOAL nella stessa edizione con < 4 partecipanti
                begin
                    if c_debug
                    then
                        dbms_output.put_line (
                            'Gara con meno di 4 partecipanti , cerco con chi accorpare');
                    end if;

                    select dg2.sequ_id_dati_gara_esterna
                      into v_id_gara_altra
                      from tc_dati_gara_esterna dg2
                     where     dg2.fk_sequ_id_dati_ediz_esterna =
                               v_dati_gara.fk_sequ_id_dati_ediz_esterna
                           and dg2.sequ_id_dati_gara_esterna != p_gara_id
                           and upper (dg2.desc_nome_gara_esterna) like
                                   '%FOAL%'
                           and exists
                                   (  select 1
                                        from tc_dati_classifica_esterna ce
                                       where ce.fk_sequ_id_dati_gara_esterna =
                                             dg2.sequ_id_dati_gara_esterna
                                    group by ce.fk_sequ_id_dati_gara_esterna
                                      having count (*) < 4)
                           and rownum = 1;


                    -- Accorpamento con l¿altra gara
                    pkg_calcoli_premi_manifest.calcola_premio_foals_2025 (
                        p_id_gara_1   => p_gara_id,
                        p_id_gara_2   => v_id_gara_altra);
                exception
                    when no_data_found
                    then
                        null; -- Nessuna seconda gara disponibile  non si fa nulla
                end;
            end if;

            return l_risultati;
        end if;


        ----------------------------------------------------------------------------
        -- TUTTI GLI ALTRI CASI ECCETTO I FOAL
        ----------------------------------------------------------------------------



        for rec in c_classifica
        loop
            idx := idx + 1;
            v_classifica (idx).id_cavallo := rec.fk_sequ_id_cavallo;
            v_classifica (idx).posizione := rec.posizione_masaf;
            v_classifica (idx).punteggio := rec.nume_punti;
            v_classifica (idx).vincite_fise := rec.vincite_fise;
            v_num_partenti_valido := v_num_partenti_valido + 1;
        end loop;

        v_montepremi_tot :=
            fn_calcola_montepremi_allev (
                p_dati_gara   => v_dati_gara,
                p_num_part    => v_num_partenti_valido);

        --v_premiabili :=
            fn_calcola_n_premiabili_masaf (
                p_dati_gara   => v_dati_gara,
                p_num_part    => v_num_partenti_valido,
                p_n_premiabili => v_premiabili,
                p_desc_premiabili => v_desc_premiabili);
            
        
        
          dbms_output.put_line ('=== v_dati_gara.desc_nome_gara_esterna === '||v_dati_gara.desc_nome_gara_esterna);
         --Se v_num_partenti_valido < 7 allora vige una sitribuzione limite         
        if v_num_partenti_valido < 7 AND upper(v_dati_gara.desc_nome_gara_esterna) LIKE '%OBBEDIENZA%' then

        -- Costruzione mappa premi 
            for i in 1 .. v_classifica.count
            loop
                v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;


                v_mappa_premi (i).premio :=
                    fn_premio_distr_7_allev (
                        num_partiti          => v_num_partenti,
                        posizione            => v_classifica (i).posizione,
                        num_con_parimerito   =>
                            fn_conta_parimerito (v_dati_gara,
                                                 v_classifica (i).posizione),
                        montepremi           => v_montepremi_tot);
                v_mappa_premi (i).fascia := v_classifica (i).posizione;
            end loop;
        elsif   upper(v_dati_gara.desc_nome_gara_esterna) LIKE '%COMBINAT%' then  
        --PREMIO SOLO IL PRIMO
            for i in 1 .. 1
            loop
                v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;
                v_mappa_premi (i).premio :=v_montepremi_tot;
                v_mappa_premi (i).fascia := v_classifica (i).posizione; 
            end loop;
        else
        --altrimenti uso la classica distribuzione a fasce
        pkg_calcoli_premi_manifest.calcola_fasce_premiabili_masaf (
            p_classifica            => v_classifica,
            p_montepremi            => v_montepremi_tot,
            p_premiabili            => v_premiabili,
            p_priorita_fasce_alte   => TRUE,
            p_mappa_premi           => v_mappa_premi,
            p_desc_fasce            => v_desc_fasce);
end if;

        for rec in c_classifica
        loop
            calcola_premio_allev_2025 (
                p_dati_gara                    => v_dati_gara,
                p_posizione                    => rec.posizione_masaf,
                p_sequ_id_classifica_esterna   =>
                    rec.sequ_id_classifica_esterna,
                p_mappa_premi                  => v_mappa_premi,
                p_premio_cavallo               => v_premio);



            i := i + 1;
            l_risultati.extend;
            l_risultati (i).cavallo_id := rec.fk_sequ_id_cavallo;
            l_risultati (i).nome_cavallo := rec.desc_cavallo;
            l_risultati (i).premio := v_premio;
            l_risultati (i).posizione := rec.nume_piazzamento;
            l_risultati (i).note :=
                'v_disciplina:Allevatoriale' || ',v_premio:' || v_premio;

            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = v_premio
             where sequ_id_classifica_esterna =
                   rec.sequ_id_classifica_esterna;

            commit;
        end loop;

        return l_risultati;
    end handler_allevatoriale;

    function handler_completo (p_gara_id in number)
        return t_tabella_premi
    is
        l_risultati             t_tabella_premi := t_tabella_premi ();
        i                       pls_integer := 0;

        v_dati_gara             tc_dati_gara_esterna%rowtype;
        v_premio                number;
        v_num_partenti          number := 0;
        v_num_partenti_valido   number := 0;
        v_premiabili            number;
        v_montepremi_tot        number;
        v_formula               varchar2 (50);
        v_nome_manifestazione       varchar2 (500);
        v_desc_premiabili  varchar2 (500);
        v_desc_fasce               varchar2 (500);
        idx                     pls_integer := 0;
        v_tipo_evento           varchar2 (50);
        v_classifica            pkg_calcoli_premi_manifest.t_classifica;
        v_mappa_premi           pkg_calcoli_premi_manifest.t_mappatura_premi;

        cursor c_classifica is
              select t.*,  ROW_NUMBER() OVER (ORDER BY t.nume_piazzamento) as posizione_masaf
                from tc_dati_classifica_esterna t
               where     fk_sequ_id_dati_gara_esterna = p_gara_id
                     and t.fk_sequ_id_cavallo is not null
                     and t.nume_piazzamento < 900 -- escludo i non arrivati nella classifica
            order by t.nume_piazzamento asc;
    begin
        ----------------------------------------------------------------------------
        -- 1) Recupero della riga di gara (tc_dati_gara_esterna) in base a p_gara_id
        ----------------------------------------------------------------------------
        if c_debug
        then
            dbms_output.put_line ('=== HANDLER_COMPLETO ===');
        end if;
            
        v_dati_gara := fn_info_gara_esterna (p_gara_id);
        l_risultati := t_tabella_premi ();
        v_tipo_evento := fn_desc_tipologica (v_dati_gara.fk_codi_tipo_evento);
        
        -- Recupero riga la formula dell'edizione
        select upper (mf.desc_formula), upper(mf.DESC_DENOM_MANIFESTAZIONE)
          into v_formula,v_nome_manifestazione
          from tc_dati_gara_esterna  dg
               join tc_dati_edizione_esterna ee
                   on ee.sequ_id_dati_edizione_esterna =
                      dg.fk_sequ_id_dati_ediz_esterna
               join tc_edizione ed
                   on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
               join tc_manifestazione mf
                   on mf.sequ_id_manifestazione =
                      ed.fk_sequ_id_manifestazione
         where dg.sequ_id_dati_gara_esterna = p_gara_id; 

   if v_nome_manifestazione like '%TROFEO%'  
   then
   v_tipo_evento:= 'TROFEO';
   end if;
        -- 2. Numero partenti MASAF
        select count (*)
          into v_num_partenti
          from tc_dati_classifica_esterna
         where     fk_sequ_id_dati_gara_esterna = p_gara_id
               and fk_sequ_id_cavallo is not null
               and nume_piazzamento < 900;  -- Solo posizioni normali
            
        if v_num_partenti = 0
        then
            return l_risultati;
        end if;

        if c_debug
        then
            dbms_output.put_line ('=== v_num_partenti ===' || v_num_partenti);
            dbms_output.put_line ('Gara ID: ' || p_gara_id);
            dbms_output.put_line (
                'Nome gara: ' || v_dati_gara.desc_nome_gara_esterna);
            dbms_output.put_line ('Età: ' || v_dati_gara.fk_codi_eta);
            dbms_output.put_line (
                'Categoria: ' || v_dati_gara.fk_codi_categoria);
            dbms_output.put_line (
                'Tipo evento: ' || v_dati_gara.fk_codi_tipo_evento);
            dbms_output.put_line (
                'Livello cavallo: ' || v_dati_gara.fk_codi_livello_cavallo);
        end if;

        ----------------------------------------------------------------------------
        -- 4) Ciclo su classifica
        ----------------------------------------------------------------------------

        for rec in c_classifica
        loop
            idx := idx + 1;
            v_classifica (idx).id_cavallo := rec.fk_sequ_id_cavallo;
            v_classifica (idx).posizione := rec.posizione_masaf;
            v_classifica (idx).punteggio := rec.nume_punti;
            v_classifica (idx).vincite_fise := rec.vincite_fise;
            v_num_partenti_valido := v_num_partenti_valido + 1;
        end loop;


        v_montepremi_tot :=
            fn_calcola_montepremi_completo (
                p_dati_gara   => v_dati_gara,
                p_num_part    => v_num_partenti_valido);

        if c_debug
        then
            dbms_output.put_line ('v_montepremi_tot: ' || v_montepremi_tot);
        end if;

        --caso di TAPPA si premia il 60% con formula MASAF a fasce

        -- nel caso di TROFEO si usa la distribuzione simil FISE del premio
        if v_tipo_evento = 'TROFEO' and v_formula <> 'FISE'
        then
            -- Costruzione mappa premi simil FISE
            for i in 1 .. v_classifica.count
            loop
                v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;


                v_mappa_premi (i).premio :=
                    fn_premio_distr_trofeo_compl (
                        num_partiti          => v_num_partenti,
                        posizione            => v_classifica (i).posizione,
                        num_con_parimerito   =>
                            fn_conta_parimerito (v_dati_gara,
                                                 v_classifica (i).posizione),
                        montepremi           => v_montepremi_tot);
                v_mappa_premi (i).fascia := v_classifica (i).posizione; -- opzionale, utile per tracciamento
            end loop;
        elsif v_tipo_evento = 'CAMPIONATO' and v_formula <> 'FISE'
        then
            -- Costruzione mappa premi simil FISE - VALE SOLO PER IL CAMPIONATO
            for i in 1 .. v_classifica.count
            loop
                v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;


                v_mappa_premi (i).premio :=
                    fn_premio_distr_camp_compl (
                        num_partiti          => v_num_partenti,
                        posizione            => v_classifica (i).posizione,
                        num_con_parimerito   =>
                            fn_conta_parimerito (v_dati_gara,
                                                 v_classifica (i).posizione),
                        montepremi           => v_montepremi_tot);
                v_mappa_premi (i).fascia := v_classifica (i).posizione; -- opzionale, utile per tracciamento
            end loop;
        elsif INSTR(upper(v_dati_gara.desc_nome_gara_esterna),'PROG') > 0 and INSTR(upper(v_dati_gara.desc_nome_gara_esterna),'TECN') > 0then 
        --divido il premio per tutti quelli che hanno piazzamento 1 ovvero quelli che hanno superato la progressione tecnica
            for i in 1 .. v_classifica.count
            loop
                v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;
                v_mappa_premi (i).premio := v_montepremi_tot / v_num_partenti;
                v_mappa_premi (i).fascia := v_classifica (i).posizione; 
            end loop;
        elsif v_nome_manifestazione like '%CAMPIONATO%MONDO%' then
            --premio fino ai primi due come da disciplinare
            if v_classifica.count = 1 then
                v_mappa_premi (1).id_cavallo := v_classifica (1).id_cavallo;
                v_mappa_premi (1).premio := v_montepremi_tot;
                v_mappa_premi (1).fascia := v_classifica (1).posizione; 
            elsif v_classifica.count > 1 then
                for i in 1 .. v_classifica.count
            loop
                v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;
                if i > 2 then
                    v_mappa_premi (i).premio :=0;
                else
                    v_mappa_premi (i).premio := v_montepremi_tot / 2;
                end if;
                v_mappa_premi (i).fascia := v_classifica (i).posizione; 
            end loop;
            end if;

            
        else
           -- v_premiabili :=
             fn_calcola_n_premiabili_masaf (
                    p_dati_gara   => v_dati_gara,
                    p_num_part    => v_num_partenti_valido,
                    p_n_premiabili =>v_premiabili,
                    p_desc_premiabili => v_desc_premiabili);

            pkg_calcoli_premi_manifest.calcola_fasce_premiabili_masaf (
                p_classifica            => v_classifica,
                p_montepremi            => v_montepremi_tot,
                p_premiabili            => v_premiabili,
                p_priorita_fasce_alte   => FALSE,--SE HO UNA SOLA FASCIA E' FASCIA 3 come salto ad ostacoli
                p_mappa_premi           => v_mappa_premi,
                p_desc_fasce            => v_desc_fasce);
        end if;

        -- solo nel caso sia una edizione FISE 
         
        if v_formula like '%FISE%' then 
                --INCENTIVO 10% COMPLETO
                    for i in 1 .. v_classifica.count
                    loop
                        v_mappa_premi (i).id_cavallo := v_classifica (i).id_cavallo;
                        v_mappa_premi (i).premio :=ROUND(v_classifica (i).vincite_fise * 0.1,2); --INCENTIVO del 10%
                        --dbms_output.put_line ('v_mappa_premi (i).premio: '||v_mappa_premi (i).premio);
                        v_mappa_premi (i).fascia := v_classifica (i).posizione;
                    end loop;
         end if;
        -- assegno i premi


        for rec in c_classifica
        loop
            if c_debug
            then
                dbms_output.put_line (
                       'Elaborazione cavallo: '
                    || rec.desc_cavallo
                    || ' - Posizione: '
                    || rec.posizione_masaf || ' premiabili : '||v_premiabili);
            end if;

            calcola_premio_completo_2025 (
                p_dati_gara                    => v_dati_gara,
                p_posizione                    => rec.posizione_masaf,
                p_sequ_id_classifica_esterna   =>
                    rec.sequ_id_classifica_esterna,
                p_mappa_premi                  => v_mappa_premi,
                p_premio_cavallo               => v_premio);

            if c_debug
            then
                dbms_output.put_line ('Premio assegnato : ' || v_premio);
            end if;

            i := i + 1;
            l_risultati.extend;
            l_risultati (i).cavallo_id := rec.fk_sequ_id_cavallo;
            l_risultati (i).nome_cavallo := rec.desc_cavallo;
            l_risultati (i).premio := v_premio;
            l_risultati (i).posizione := rec.nume_piazzamento;
            l_risultati (i).note :=
                'v_disciplina:Completo' || ',v_premio:' || v_premio;

            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = v_premio
             where sequ_id_classifica_esterna =
                   rec.sequ_id_classifica_esterna;

            commit;
        end loop;

        if c_debug
        then
            dbms_output.put_line ('=== FINE HANDLER_COMPLETO ===');
        end if;

        return l_risultati;
    end handler_completo;


  function handler_monta_da_lavoro (p_gara_id in number)
    return t_tabella_premi
is
    l_risultati           t_tabella_premi := t_tabella_premi ();
    i                     pls_integer := 0;
    v_dati_gara           tc_dati_gara_esterna%rowtype;
    v_premio              number;
    v_count               number := 0;
    v_posizione_reale     pls_integer := 1;
    v_piazzamento_prec    number := null;
    type t_mappa_parimerito is table of pls_integer index by pls_integer;
    v_parimerito          t_mappa_parimerito;
    cursor c_classifica is
        select *
          from tc_dati_classifica_esterna
         where fk_sequ_id_dati_gara_esterna = p_gara_id
      order by nume_piazzamento asc;
begin
    v_dati_gara := fn_info_gara_esterna (p_gara_id);
    l_risultati := t_tabella_premi ();
    
    select count (*)
      into v_count
      from tc_dati_classifica_esterna
     where fk_sequ_id_dati_gara_esterna = p_gara_id;
    
    if v_count = 0 then
        return l_risultati;
    end if;
    
    -- Mappa parimerito
    for rec in (select nume_piazzamento, count (*) conta
                  from tc_dati_classifica_esterna
                 where fk_sequ_id_dati_gara_esterna = p_gara_id
                       and fk_sequ_id_cavallo is not null
              group by nume_piazzamento)
    loop
        v_parimerito (rec.nume_piazzamento) := rec.conta;
    end loop;
    
    -- Loop classifica con calcolo posizione reale
    for rec in c_classifica
    loop
        -- Calcola posizione reale considerando i parimerito precedenti
        if v_piazzamento_prec is not null and rec.nume_piazzamento > v_piazzamento_prec then
            v_posizione_reale := v_posizione_reale + v_parimerito(v_piazzamento_prec);
        end if;
        
        calcola_premio_monta_2025 (
            p_dati_gara                  => v_dati_gara,
            p_posizione                  => v_posizione_reale,
            p_tot_partenti               => v_count,
            p_num_con_parimerito         => nvl(v_parimerito(rec.nume_piazzamento), 1),
            p_premio_cavallo             => v_premio,
            p_sequ_id_classifica_esterna => rec.sequ_id_classifica_esterna);
        
        i := i + 1;
        l_risultati.extend;
        l_risultati (i).cavallo_id := rec.fk_sequ_id_cavallo;
        l_risultati (i).nome_cavallo := rec.desc_cavallo;
        l_risultati (i).premio := v_premio;
        l_risultati (i).posizione := rec.nume_piazzamento;
        l_risultati (i).note := 'v_disciplina:Monta da lavoro' || ',v_premio:' || v_premio;
        
        v_piazzamento_prec := rec.nume_piazzamento;
    end loop;
    
    return l_risultati;
end handler_monta_da_lavoro;

    procedure elabora_premi_gara (p_gara_id         in     number,
                                  p_forza_elabora   in     number,
                                  p_risultato          out varchar2)
    --p_risultati          OUT t_tabella_premi)
    is
        v_disciplina            varchar2 (50);
        v_premi_gia_calcolati   number (1);
        p_risultati             t_tabella_premi;
    begin
        --se TRUE forzo il calcolo del montepremi

       

        if c_debug
        then
            dbms_output.put_line ('INIZIO ELABORA_PREMI_GARA ');
        end if;

        v_disciplina := get_disciplina (p_gara_id);
 
        -- Inizializzazione collection
        p_risultati := t_tabella_premi ();


        -- Verifica se la gara ha già premi calcolati
        select case when count (1) > 0 then 1 else 0 end
          into v_premi_gia_calcolati
          from tc_dati_classifica_esterna
         where     fk_sequ_id_dati_gara_esterna = p_gara_id
               and importo_masaf_calcolato is not null;


        if     (fn_gara_premiata_masaf (p_gara_id) = 1 
                or FN_INCENTIVO_MASAF_GARA_FISE(p_gara_id) > 0)
           and (v_premi_gia_calcolati = 0 or p_forza_elabora = 1)
        then
            -- Dispatch in base alla disciplina
            case v_disciplina
                when 1
                then
                    p_risultati := handler_allevatoriale (p_gara_id);
                when 2
                then
                    p_risultati := handler_endurance (p_gara_id);
                when 3
                then
                    p_risultati := handler_completo (p_gara_id);
                when 4
                then
                    p_risultati := handler_salto_ostacoli (p_gara_id);
                when 6
                then
                    p_risultati := handler_dressage (p_gara_id);
                when 7
                then
                    p_risultati := handler_monta_da_lavoro (p_gara_id);
                else
                    raise_application_error (
                        -20001,
                        'Disciplina non gestita: ' || v_disciplina);
            end case;

            p_risultato := 'Elaborazione terminata correttamente.';
        else
            if v_premi_gia_calcolati = 1
            then
                p_risultato :=
                    'Attenzione la Gara ha già i premi elaborati.';
            end if;

            if p_forza_elabora = 1
            then
                p_risultato :=
                    'Attenzione la Gara è definita come senza premi Masaf.';

                update tc_dati_classifica_esterna
                   set importo_masaf_calcolato = null
                 where fk_sequ_id_dati_gara_esterna = p_gara_id;

                commit;
            end if;
        end if;
    end;


    procedure elabora_premi_foals_per_anno (v_anno in varchar2)
    is
        cursor c_foals is
            select dg.sequ_id_dati_gara_esterna,
                   dg.data_gara_esterna,
                   ee.desc_localita_estera
              from tc_dati_gara_esterna  dg
                   join tc_dati_edizione_esterna ee
                       on ee.sequ_id_dati_edizione_esterna =
                          dg.fk_sequ_id_dati_ediz_esterna
             where     upper (dg.desc_nome_gara_esterna) like '%FOAL%'
                   and substr (dg.data_gara_esterna, 1, 4) = v_anno
                   and dg.fk_sequ_id_gara_manifestazioni is not null;

        type t_numlist is table of number
            index by pls_integer;

        gare_gia_elaborate   t_numlist;

        v_count_part         number;
    begin
        dbms_output.put_line ('--- Inizio elaborazione gare FOALS ---');

        for rec in c_foals
        loop
            dbms_output.put_line (
                'Verifico gara ID: ' || rec.sequ_id_dati_gara_esterna);

            if gare_gia_elaborate.exists (rec.sequ_id_dati_gara_esterna)
            then
                dbms_output.put_line ('  -> Già elaborata, salto.');
                continue;
            end if;

            select count (*)
              into v_count_part
              from tc_dati_classifica_esterna
             where     fk_sequ_id_dati_gara_esterna =
                       rec.sequ_id_dati_gara_esterna
                   and nume_piazzamento is not null;

            dbms_output.put_line ('  Partecipanti: ' || v_count_part);

            if v_count_part > 4
            then
                dbms_output.put_line ('  -> Sufficiente, elaboro da sola.');
                pkg_calcoli_premi_manifest.calcola_premio_foals_2025 (
                    rec.sequ_id_dati_gara_esterna);
                gare_gia_elaborate (rec.sequ_id_dati_gara_esterna) := 1;
            else
                declare
                    v_id_gara_altro   number := null;
                begin
                    dbms_output.put_line (
                        '  -> Troppo pochi, cerco gara da accorpare...');

                    for alt
                        in (select dg.sequ_id_dati_gara_esterna
                              from tc_dati_gara_esterna  dg
                                   join tc_dati_edizione_esterna ee
                                       on ee.sequ_id_dati_edizione_esterna =
                                          dg.fk_sequ_id_dati_ediz_esterna
                             where     dg.sequ_id_dati_gara_esterna !=
                                       rec.sequ_id_dati_gara_esterna
                                   and upper (dg.desc_nome_gara_esterna) like
                                           '%FOAL%'
                                   and dg.data_gara_esterna =
                                       rec.data_gara_esterna
                                   and ee.desc_localita_estera =
                                       rec.desc_localita_estera
                                   and dg.fk_sequ_id_gara_manifestazioni
                                           is not null)
                    loop
                        if not gare_gia_elaborate.exists (
                                   alt.sequ_id_dati_gara_esterna)
                        then
                            v_id_gara_altro := alt.sequ_id_dati_gara_esterna;
                            exit;
                        end if;
                    end loop;

                    if v_id_gara_altro is not null
                    then
                        dbms_output.put_line (
                            '  -> Accorpata con gara ID: ' || v_id_gara_altro);
                        gare_gia_elaborate (rec.sequ_id_dati_gara_esterna) :=
                            1;
                        gare_gia_elaborate (v_id_gara_altro) := 1;
                        pkg_calcoli_premi_manifest.calcola_premio_foals_2025 (
                            p_id_gara_1   => rec.sequ_id_dati_gara_esterna,
                            p_id_gara_2   => v_id_gara_altro);
                    else
                        dbms_output.put_line (
                            '  -> Nessuna gara compatibile trovata. Procedo da sola.');
                        pkg_calcoli_premi_manifest.calcola_premio_foals_2025 (
                            rec.sequ_id_dati_gara_esterna);
                        gare_gia_elaborate (rec.sequ_id_dati_gara_esterna) :=
                            1;
                    end if;
                end;
            end if;
        end loop;

        dbms_output.put_line ('--- Fine elaborazione gare FOALS ---');
    end elabora_premi_foals_per_anno;



    procedure calcola_premio_salto_ost_2025 (
        p_dati_gara                    in     tc_dati_gara_esterna%rowtype,
        p_posizione                    in     number,
        p_sequ_id_classifica_esterna   in     number,
        p_mappa_premi                  in     pkg_calcoli_premi_manifest.t_mappatura_premi,
        p_premio_cavallo                  out number)
    is
        v_categoria      varchar2 (50);
        v_eta            number;
        v_tipo_distrib   varchar2 (10);
        v_id_cavallo     number;
        v_fascia         number;
    begin
        if c_debug
        then
            dbms_output.put_line (CHR(10) || '   >> CALCOLO PREMIO SINGOLO');
            dbms_output.put_line ('      ID Classifica: ' || p_sequ_id_classifica_esterna);
            dbms_output.put_line ('      Cavallo ID   : ' || v_id_cavallo);
            dbms_output.put_line ('      Posizione    : ' || p_posizione);
        end if;
        -- Categoria e età
        v_categoria :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_categoria));
        v_eta :=
            to_number (
                substr (fn_desc_tipologica (p_dati_gara.fk_codi_eta), 1, 1));

        -- ID cavallo
        select fk_sequ_id_cavallo
          into v_id_cavallo
          from tc_dati_classifica_esterna
         where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna;


        declare
            trovato   boolean := false;
        begin
            for i in p_mappa_premi.first .. p_mappa_premi.last
            loop
                if p_mappa_premi (i).id_cavallo = v_id_cavallo
                then
                    p_premio_cavallo := p_mappa_premi (i).premio;
                    v_fascia := p_mappa_premi (i).fascia;
                    trovato := true;

                    if c_debug
                    then
                         dbms_output.put_line ('      - Fascia ' || p_mappa_premi(i).fascia || 
                                  ' | Premio ¿' || LPAD(TO_CHAR(p_mappa_premi(i).premio, '99990.00'), 10));

                    end if;

                    exit;
                end if;
            end loop;

            if not trovato
            then
                p_premio_cavallo := 0;

                if c_debug
                then
                    dbms_output.put_line (
                           'Cavallo '
                        || v_id_cavallo
                        || ' non premiato - premio = 0');
                end if;
            end if;
        end;

        -- Update risultato in classifica esterna
        update tc_dati_classifica_esterna
           set importo_masaf_calcolato = p_premio_cavallo,
               nume_piazzamento_masaf = p_posizione
         where     sequ_id_classifica_esterna = p_sequ_id_classifica_esterna
               and nume_piazzamento < 900;

        if c_debug
        then
            dbms_output.put_line ('      - Aggiornato DB con premio ¿' || 
                                  LPAD(TO_CHAR(p_premio_cavallo, '99990.00'), 10));

        end if;
    exception
        when others
        then
            p_premio_cavallo := 0;
            dbms_output.put_line (
                'ERRORE CALCOLA_PREMIO_SALTO_OST_2025: ' || sqlerrm);
            raise;
    end;



    procedure calcola_premio_endurance_2025 (
        p_dati_gara                    in     tc_dati_gara_esterna%rowtype,
        p_posizione                    in     number,
        p_montepremi_tot               in     number,
        p_num_con_parimerito           in     number,
        p_sequ_id_classifica_esterna   in     number,
        p_premio_cavallo               out    number)
    as
        v_perc   sys.odcinumberlist;
        v_base   number := 0;
        v_nome_gara varchar2(500);
        v_tipo_evento varchar2(50);
        v_categoria varchar2(50);
        v_distribuzione varchar2(200);
    begin
    
      v_categoria:= fn_desc_tipologica (p_dati_gara.fk_codi_categoria);
      v_tipo_evento := fn_desc_tipologica (p_dati_gara.fk_codi_tipo_evento);
      v_nome_gara:= upper(p_dati_gara.desc_nome_gara_esterna);
      
      case upper (v_tipo_evento)
            when 'FINALE' 
            then
            v_distribuzione:='FINALE';
                v_perc :=
                    sys.odcinumberlist (25,
                                        18,
                                        15,
                                        12,
                                        10,
                                        4,
                                        4,
                                        4,
                                        4,
                                        4);
                                        when 'TAPPA' 
            then
             v_distribuzione:='TAPPA';
                v_perc :=
                    sys.odcinumberlist (25,
                                        18,
                                        15,
                                        12,
                                        10,
                                        4,
                                        4,
                                        4,
                                        4,
                                        4);
            when 'CAMPIONATO'
            then
                v_distribuzione:='CAMPIONATO';            
                v_perc :=
                    sys.odcinumberlist (29,
                                        22,
                                        19,
                                        16,
                                        14);
            else
             v_distribuzione:='NESSUN PREMIO';  
                v_perc := sys.odcinumberlist ();              -- nessun premio
        end case;

        -- NEL CASO NON SIA UN PREMIO MA UN INCENTIVO DEVO DARE IL 100% al primo classificato e basta
        if v_nome_gara like '%ANGLO ARABO' or v_nome_gara like '%ORIENTALE%' then
         v_distribuzione:='INCENTIVO AA OR';  
        v_perc :=
                    sys.odcinumberlist (100,0,0,0,0,0,0,0,0);
                                        end if;
               -- altro caso specifico CAMPIONATO MASAF 7 E 8 ANNI (TAPPA UNICA) con un'unica gara da premiare CEI2*                         
        if v_nome_gara like 'CEI2%' then
                v_distribuzione := 'CAMPIONATO 7 8 anni TAPPA UNICA';  
                v_perc :=
                    sys.odcinumberlist (29,22,19,16,14);
        end if;
        
        if p_posizione between 1 and v_perc.count
        then
            v_base := p_montepremi_tot * v_perc (p_posizione) / 100;
            p_premio_cavallo :=
                round (v_base / greatest (p_num_con_parimerito, 1), 2);
        else
            p_premio_cavallo := 0;
        end if;

        if c_debug = true then
            dbms_output.put_line (
                           '[CALCOLA_PREMIO_ENDURANCE_2025] p_premio_cavallo = '
                        || p_premio_cavallo||' - posizione MASAF : '||p_posizione|| ' - distribuzione : '||v_distribuzione);
        end if;

        if p_sequ_id_classifica_esterna is not null
        then
            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = p_premio_cavallo
             where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna;

            commit;
        end if;
    exception
        when others
        then
            p_premio_cavallo := 0;
            dbms_output.put_line ('DEBUG ERRORE: ' || sqlerrm);
            raise_application_error (-20001,
                                     'Errore calcolo premio: ' || sqlerrm);
    end calcola_premio_endurance_2025;






    procedure calcola_premio_allev_2025 (
        p_dati_gara                    in     tc_dati_gara_esterna%rowtype,
        p_posizione                    in     number,
        p_sequ_id_classifica_esterna   in     number,
        p_mappa_premi                  in     pkg_calcoli_premi_manifest.t_mappatura_premi,
        p_premio_cavallo                  out number)
    is
        v_montepremi_tot      number := 0;
        v_tipo_prova_descr    varchar2 (100);
        v_tipo_evento_descr   varchar2 (100);
        v_eta_cavallo_id      number;
        v_eta_cavallo_num     number;         -- Età numerica (1, 2, o 3 anni)
        v_id_cavallo          number;
        v_fascia              number;
    begin
        if c_debug
        then
            dbms_output.put_line (
                   '------------ Inizio CALCOLA_PREMIO_ALLEV_2025 (ID Gara Esterna: '
                || p_dati_gara.sequ_id_dati_gara_esterna
                || ') per Pos: '
                || p_posizione
                || ' ---');
        end if;

        p_premio_cavallo := 0;                                      -- Default

        if fn_gara_premiata_masaf (p_dati_gara.sequ_id_dati_gara_esterna) = 0
        then
            if c_debug
            then
                dbms_output.put_line ('Gara non premiata MASAF.');
            end if;

            return;
        end if;

        v_tipo_prova_descr :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_tipo_prova));
        v_tipo_evento_descr :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_tipo_evento));
        v_eta_cavallo_id := p_dati_gara.fk_codi_eta; -- Assumiamo sia già popolato o dedotto correttamente



        -- Mappatura ID età a numero (semplificata, da adattare se gli ID sono diversi)
        case v_eta_cavallo_id
            when 111
            then
                v_eta_cavallo_num := 1;                              -- 1 anno
            when 112
            then
                v_eta_cavallo_num := 2;                              -- 2 anni
            when 113
            then
                v_eta_cavallo_num := 3;                              -- 3 anni
            else
                v_eta_cavallo_num := 0; -- Sconosciuta o non rilevante per alcune prove
        end case;

        if c_debug
        then
            dbms_output.put_line (
                   'Tipo Prova: '
                || v_tipo_prova_descr
                || ', Tipo Evento: '
                || v_tipo_evento_descr
                || ', Età ID: '
                || v_eta_cavallo_id
                || ', Età Num: '
                || v_eta_cavallo_num);
        end if;



        -- ID cavallo
        select fk_sequ_id_cavallo
          into v_id_cavallo
          from tc_dati_classifica_esterna
         where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna;


        -- Log
--        if c_debug
--        then
--            dbms_output.put_line (
--                   'DEBUG: ID CLASSIFICA ESTERNA: '
--                || p_sequ_id_classifica_esterna);
--            dbms_output.put_line (' | Cavallo ID: ' || v_id_cavallo);
--        end if;

        declare
            trovato   boolean := false;
        begin
            for i in p_mappa_premi.first .. p_mappa_premi.last
            loop
                if p_mappa_premi (i).id_cavallo = v_id_cavallo
                then
                    p_premio_cavallo := p_mappa_premi (i).premio;
                    v_fascia := p_mappa_premi (i).fascia;
                    trovato := true;

                    if c_debug
                    then
                        dbms_output.put_line (
                               'Premio MASAF assegnato da mappa: Cavallo '
                            || v_id_cavallo
                            || ' - Fascia '
                            || v_fascia
                            || ' - Premio ¿'
                            || p_premio_cavallo);
                    end if;

                    exit;
                end if;
            end loop;

            if not trovato
            then
                p_premio_cavallo := 0;

                if c_debug
                then
                    dbms_output.put_line (
                           'Cavallo '
                        || v_id_cavallo
                        || ' non premiato - premio = 0');
                end if;
            end if;
        end;

        -- Update risultato in classifica esterna
        update tc_dati_classifica_esterna
           set importo_masaf_calcolato = p_premio_cavallo,
               nume_piazzamento_masaf = p_posizione
         where     sequ_id_classifica_esterna = p_sequ_id_classifica_esterna
               and nume_piazzamento < 900;

        if c_debug
        then
            dbms_output.put_line (
                   'Aggiornato campo IMPORTO_MASAF_CALCOLATO = '
                || p_premio_cavallo);
            dbms_output.put_line ('--- FINE CALCOLA_PREMIO_ALLEV_2025 ---');
        end if;
    -- Considera se rilanciare l'eccezione o gestirla
    end calcola_premio_allev_2025;



  procedure calcola_premio_foals_2025 (
        p_id_gara_1   in number,
        p_id_gara_2   in number default null)
    as
        type t_classifica is record
        (
            rid           rowid,
            posizione     number,
            id_cavallo    number
        );

        type t_classifica_tab is table of t_classifica;

        v_risultati      t_classifica_tab;
        v_tot_partenti   number;
        v_montepremi     number;
        v_metaparte      number;
        premiabili       t_classifica_tab;

        fascia1          t_classifica_tab := t_classifica_tab ();
        fascia2          t_classifica_tab := t_classifica_tab ();
        fascia3          t_classifica_tab := t_classifica_tab ();
        premio1          number := 0;
        premio2          number := 0;
        premio3          number := 0;

        v_id_gare        sys.odcinumberlist := sys.odcinumberlist ();
        v_is_accorpata   boolean := false;
    begin
        if c_debug
        then
            dbms_output.put_line ('--- Inizio CALCOLA_PREMI_FOALS 2025---');
            dbms_output.put_line ('Gara 1: ' || p_id_gara_1);
        end if;

        if p_id_gara_2 is not null
        then
            dbms_output.put_line ('Gara 2 (accorpata): ' || p_id_gara_2);
            v_id_gare.extend (2);
            v_id_gare (1) := p_id_gara_1;
            v_id_gare (2) := p_id_gara_2;
            v_is_accorpata := true;

            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = 0
             where fk_sequ_id_dati_gara_esterna in (p_id_gara_1, p_id_gara_2);
        else
            dbms_output.put_line ('Nessuna gara accorpata.');
            v_id_gare.extend (1);
            v_id_gare (1) := p_id_gara_1;

            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = 0
             where fk_sequ_id_dati_gara_esterna in p_id_gara_1;
        end if;

        if v_is_accorpata
        then
            dbms_output.put_line (
                'Accorpamento attivo: classifica ricalcolata per NUME_PUNTI');

              select rowid,
                     row_number ()
                         over (order by nume_punti desc, fk_sequ_id_cavallo)
                         as posizione,
                     fk_sequ_id_cavallo
                bulk collect into v_risultati
                from tc_dati_classifica_esterna
               where     fk_sequ_id_dati_gara_esterna in
                             (select * from table (v_id_gare))
                     and nume_punti is not null
            order by nume_punti desc;

            dbms_output.put_line ('--- Contenuto di v_risultati ---');

--            for i in 1 .. v_risultati.count
--            loop
--                dbms_output.put_line (
--                       'Cavallo ID: '
--                    || v_risultati (i).id_cavallo
--                    || ', Posizione: '
--                    || v_risultati (i).posizione
--                    || ', ROWID: '
--                    || v_risultati (i).rid);
--            end loop;
        else
              select rowid, nume_piazzamento, fk_sequ_id_cavallo
                bulk collect into v_risultati
                from tc_dati_classifica_esterna
               where     fk_sequ_id_dati_gara_esterna = p_id_gara_1
                     and nume_piazzamento is not null
            order by nume_piazzamento;
        end if;

        dbms_output.put_line (
            'Totale risultati caricati: ' || v_risultati.count);

        v_tot_partenti := v_risultati.count;
        v_montepremi := greatest (v_tot_partenti, 6) * 150;
        v_metaparte := floor (v_tot_partenti / 2);

        dbms_output.put_line (
               'Totale partenti: '
            || v_tot_partenti
            || ', Montepremi: '
            || v_montepremi);

        if v_tot_partenti < 7
        then
            dbms_output.put_line (
                '- Meno di 7 partenti: applico ripartizione 50/30/20');

            for i in 1 .. v_risultati.count
            loop
                if v_risultati (i).posizione = 1
                then
                    update tc_dati_classifica_esterna
                       set importo_masaf_calcolato =
                               round (v_montepremi * 0.50, 2)
                     where rowid = v_risultati (i).rid;
                elsif v_risultati (i).posizione = 2
                then
                    update tc_dati_classifica_esterna
                       set importo_masaf_calcolato =
                               round (v_montepremi * 0.30, 2)
                     where rowid = v_risultati (i).rid;
                elsif v_risultati (i).posizione = 3
                then
                    update tc_dati_classifica_esterna
                       set importo_masaf_calcolato =
                               round (v_montepremi * 0.20, 2)
                     where rowid = v_risultati (i).rid;
                end if;
            end loop;

            commit;
            return;
        end if;


        premiabili := t_classifica_tab ();

        declare
            i             pls_integer := 1;
            gruppo_temp   t_classifica_tab := t_classifica_tab ();
        begin
            while i <= v_risultati.count
            loop
                gruppo_temp.delete;

                declare
                    curr_pos   number := v_risultati (i).posizione;
                begin
                    while     i <= v_risultati.count
                          and v_risultati (i).posizione = curr_pos
                    loop
                        gruppo_temp.extend;
                        gruppo_temp (gruppo_temp.count) := v_risultati (i);
                        i := i + 1;
                    end loop;
                end;


                if premiabili.count >= v_metaparte
                then
                    -- Ho già premiato abbastanza cavalli, esco
                    exit;
                elsif premiabili.count + gruppo_temp.count > v_metaparte
                then
                    -- Sto per superare la soglia: premio solo se è un gruppo di parimerito
                    if gruppo_temp.count > 1
                    then
                        for j in 1 .. gruppo_temp.count
                        loop
                            declare
                                v_is_masaf   number;
                            begin
                                select count (*)
                                  into v_is_masaf
                                  from tc_cavallo
                                 where sequ_id_cavallo =
                                       gruppo_temp (j).id_cavallo;

                                if v_is_masaf > 0
                                then
                                    premiabili.extend;
                                    premiabili (premiabili.count) :=
                                        gruppo_temp (j);
                                end if;
                            end;
                        end loop;
                    else
                        dbms_output.put_line (
                            '- NON aggiungo cavallo fuori soglia, non è parimerito.');
                    end if;

                    exit;
                else
                    -- Aggiungo gruppo normalmente
                    for j in 1 .. gruppo_temp.count
                    loop
                        declare
                            v_is_masaf   number;
                        begin
                            select count (*)
                              into v_is_masaf
                              from tc_cavallo
                             where sequ_id_cavallo =
                                   gruppo_temp (j).id_cavallo;

                            if v_is_masaf > 0
                            then
                                premiabili.extend;
                                premiabili (premiabili.count) :=
                                    gruppo_temp (j);
                            end if;
                        end;
                    end loop;
                end if;
            end loop;
        end;

        -- Raggruppa parimerito
        declare
            type t_gruppi is table of t_classifica_tab
                index by pls_integer;

            gruppi       t_gruppi;
            i            pls_integer := 1;
            gruppo_idx   pls_integer := 0;
        begin
            dbms_output.put_line ('premiabili.COUNT ' || premiabili.count);

            while i <= premiabili.count
            loop
                declare
                    curr_pos      number := premiabili (i).posizione;
                    gruppo_corr   t_classifica_tab := t_classifica_tab ();
                begin
                    while     i <= premiabili.count
                          and premiabili (i).posizione = curr_pos
                    loop
                        gruppo_corr.extend;
                        gruppo_corr (gruppo_corr.count) := premiabili (i);
                        i := i + 1;
                    end loop;

                    gruppo_idx := gruppo_idx + 1;
                    gruppi (gruppo_idx) := gruppo_corr;
                end;
            end loop;

            for i in 1 .. gruppi.count
            loop
                dbms_output.put_line (
                    'F' || i || ' - Count: ' || gruppi (i).count);
            end loop;

            -- Fasce
            if gruppo_idx = 1
            then
                fascia1 := gruppi (1);
                premio1 := round (v_montepremi, 2);
                dbms_output.put_line ('Premi assegnati:');
                dbms_output.put_line (
                    'Fascia 1: ' || fascia1.count || ' cavalli x ' || premio1);
                return;
            elsif gruppo_idx = 2
            then
                fascia1 := gruppi (1);
                fascia2 := gruppi (2);
                premio1 :=
                    round (v_montepremi * 0.6 / greatest (fascia1.count, 1),
                           2);
                premio2 :=
                    round (v_montepremi * 0.4 / greatest (fascia2.count, 1),
                           2);
                dbms_output.put_line ('Premi assegnati:');
                dbms_output.put_line (
                    'Fascia 1: ' || fascia1.count || ' cavalli x ' || premio1);
                dbms_output.put_line (
                    'Fascia 2: ' || fascia2.count || ' cavalli x ' || premio2);
                return;
            end if;

            -- Combinazione ottimizzata per 3 fasce
            declare
                best_dev        number := null;
                found_ok        boolean := false;
                total_cavalli   pls_integer := premiabili.count;
                best_f1         t_classifica_tab;
                best_f2         t_classifica_tab;
                best_f3         t_classifica_tab;
                best_p1         number;
                best_p2         number;
                best_p3         number;
            begin
                for i in 1 .. gruppo_idx - 2
                loop
                    for j in i + 1 .. gruppo_idx - 1
                    loop
                        declare
                            f1     t_classifica_tab := t_classifica_tab ();
                            f2     t_classifica_tab := t_classifica_tab ();
                            f3     t_classifica_tab := t_classifica_tab ();
                            cnt1   pls_integer := 0;
                            cnt2   pls_integer := 0;
                            cnt3   pls_integer := 0;
                        begin
                            for g in 1 .. gruppo_idx
                            loop
                                for c in 1 .. gruppi (g).count
                                loop
                                    if g <= i
                                    then
                                        f1.extend;
                                        f1 (f1.count) := gruppi (g) (c);
                                        cnt1 := cnt1 + 1;
                                    elsif g <= j
                                    then
                                        f2.extend;
                                        f2 (f2.count) := gruppi (g) (c);
                                        cnt2 := cnt2 + 1;
                                    else
                                        f3.extend;
                                        f3 (f3.count) := gruppi (g) (c);
                                        cnt3 := cnt3 + 1;
                                    end if;
                                end loop;
                            end loop;

                            declare
                                p1       number
                                    := round (
                                             (v_montepremi * 0.5)
                                           / greatest (cnt1, 1),
                                           2);
                                p2       number
                                    := round (
                                             (v_montepremi * 0.3)
                                           / greatest (cnt2, 1),
                                           2);
                                p3       number
                                    := round (
                                             (v_montepremi * 0.2)
                                           / greatest (cnt3, 1),
                                           2);
                                target   number := total_cavalli / 3;
                                dev      number
                                    :=   power (cnt1 - target, 2)
                                       + power (cnt2 - target, 2)
                                       + power (cnt3 - target, 2);
                            begin
                                if p1 >= p2 and p2 >= p3
                                then
                                    if best_dev is null or dev < best_dev
                                    then
                                        best_dev := dev;
                                        best_f1 := f1;
                                        best_f2 := f2;
                                        best_f3 := f3;
                                        best_p1 := p1;
                                        best_p2 := p2;
                                        best_p3 := p3;
                                        found_ok := true;
                                    end if;
                                end if;
                            end;
                        end;
                    end loop;
                end loop;

                if not found_ok
                then
                    raise_application_error (
                        -20001,
                        'Nessuna combinazione valida per 3 fasce.');
                end if;

                fascia1 := best_f1;
                fascia2 := best_f2;
                fascia3 := best_f3;
                premio1 := best_p1;
                premio2 := best_p2;
                premio3 := best_p3;

--                dbms_output.put_line ('--- Fascia 1 ---');
--
--                for i in 1 .. fascia1.count
--                loop
--                    dbms_output.put_line (
--                           'F1 - Cavallo ID: '
--                        || fascia1 (i).id_cavallo
--                        || ', ROWID: '
--                        || fascia1 (i).rid);
--                end loop;
--
--                dbms_output.put_line ('--- Fascia 2 ---');
--
--                for i in 1 .. fascia2.count
--                loop
--                    dbms_output.put_line (
--                           'F2 - Cavallo ID: '
--                        || fascia2 (i).id_cavallo
--                        || ', ROWID: '
--                        || fascia2 (i).rid);
--                end loop;
--
--                dbms_output.put_line ('--- Fascia 3 ---');
--
--                for i in 1 .. fascia3.count
--                loop
--                    dbms_output.put_line (
--                           'F3 - Cavallo ID: '
--                        || fascia3 (i).id_cavallo
--                        || ', ROWID: '
--                        || fascia3 (i).rid);
--                end loop;
            end;
        end;


        for i in 1 .. fascia1.count
        loop
            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = premio1
             where rowid = fascia1 (i).rid;

            dbms_output.put_line ('Aggiorno fascia 1 premio:' || premio1);
        end loop;

        for i in 1 .. fascia2.count
        loop
            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = premio2
             where rowid = fascia2 (i).rid;

            dbms_output.put_line ('Aggiorno fascia 2 premio:' || premio2);
        end loop;

        for i in 1 .. fascia3.count
        loop
            update tc_dati_classifica_esterna
               set importo_masaf_calcolato = premio3
             where rowid = fascia3 (i).rid;

            dbms_output.put_line ('Aggiorno fascia 3 premio:' || premio3);
        end loop;

        commit;
        dbms_output.put_line ('--- Fine CALCOLA_PREMI_FOALS ---');
    end calcola_premio_foals_2025;

    procedure calcola_premio_completo_2025 (
        p_dati_gara                    in     tc_dati_gara_esterna%rowtype,
        p_posizione                    in     number,
        p_sequ_id_classifica_esterna   in     number,
        p_mappa_premi                  in     pkg_calcoli_premi_manifest.t_mappatura_premi,
        p_premio_cavallo                  out number)
    is
        v_tipo_prova_descr    varchar2 (100);
        v_tipo_evento_descr   varchar2 (100);
        v_eta_cavallo_id      number;
        v_eta_cavallo_num     number;         -- Età numerica (1, 2, o 3 anni)
        v_id_cavallo          number;
        v_fascia              number;
    begin
        if c_debug
        then
            dbms_output.put_line (
                   '--- Inizio CALCOLA_PREMIO_COMPLETO_2025 (ID Gara Est: '
                || p_dati_gara.sequ_id_dati_gara_esterna
                || ') per Pos: '
                || p_posizione
                || ' --- Premio MASAF:' ||fn_gara_premiata_masaf (p_dati_gara.sequ_id_dati_gara_esterna)
                || ' --- Incentivo MASAF:' ||FN_INCENTIVO_MASAF_GARA_FISE(p_dati_gara.sequ_id_dati_gara_esterna));
        end if;

        p_premio_cavallo := 0;                                      -- Default

        if fn_gara_premiata_masaf (p_dati_gara.sequ_id_dati_gara_esterna) = 0 and FN_INCENTIVO_MASAF_GARA_FISE(p_dati_gara.sequ_id_dati_gara_esterna) = 0
        then
            if c_debug
            then
                dbms_output.put_line ('Gara non premiata MASAF.');
            end if;

            return;
        end if;

        v_tipo_prova_descr :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_tipo_prova));
        v_tipo_evento_descr :=
            upper (fn_desc_tipologica (p_dati_gara.fk_codi_tipo_evento));
        v_eta_cavallo_id := p_dati_gara.fk_codi_eta; 

        -- Mappatura ID età a numero (semplificata, da adattare se gli ID sono diversi)
        case v_eta_cavallo_id
            when 111
            then
                v_eta_cavallo_num := 1;                              -- 1 anno
            when 112
            then
                v_eta_cavallo_num := 2;                              -- 2 anni
            when 113
            then
                v_eta_cavallo_num := 3;                              -- 3 anni
            when 110
            then
                v_eta_cavallo_num := 7;                              -- 7 anni
            else
                v_eta_cavallo_num := 0; -- Sconosciuta o non rilevante per alcune prove
        end case;

        if c_debug
        then
            dbms_output.put_line (
                   'Tipo Prova: '
                || v_tipo_prova_descr
                || ', Tipo Evento: '
                || v_tipo_evento_descr
                || ', Età ID: '
                || v_eta_cavallo_id
                || ', Età Num: '
                || v_eta_cavallo_num);
        end if;



        -- ID cavallo
        select fk_sequ_id_cavallo
          into v_id_cavallo
          from tc_dati_classifica_esterna
         where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna;


        declare
            trovato   boolean := false;
        begin
            for i in p_mappa_premi.first .. p_mappa_premi.last
            loop
                if p_mappa_premi (i).id_cavallo = v_id_cavallo
                then
                    p_premio_cavallo := p_mappa_premi (i).premio;
                    v_fascia := p_mappa_premi (i).fascia;
                    trovato := true;

                    if c_debug
                    then
                        dbms_output.put_line (
                               'Premio MASAF assegnato da mappa: Cavallo '
                            || v_id_cavallo
                            || ' - Fascia '
                            || v_fascia
                            || ' - Premio : '
                            || p_premio_cavallo);
                    end if;

                    exit;
                end if;
            end loop;

            if not trovato
            then
                p_premio_cavallo := 0;

                if c_debug
                then
                    dbms_output.put_line (
                           'Cavallo '
                        || v_id_cavallo
                        || ' non premiato - premio = 0');
                end if;
            end if;
        end;

        -- Update risultato in classifica esterna
        update tc_dati_classifica_esterna
           set importo_masaf_calcolato = p_premio_cavallo,
               nume_piazzamento_masaf = p_posizione
         where     sequ_id_classifica_esterna = p_sequ_id_classifica_esterna
               and nume_piazzamento < 900;

        if c_debug
        then
            dbms_output.put_line (
                   'Aggiornato campo IMPORTO_MASAF_CALCOLATO = '
                || p_premio_cavallo);
            dbms_output.put_line ('--- FINE CALCOLA_PREMIO_ALLEV_2025 ---');
        end if;
    -- Considera se rilanciare l'eccezione o gestirla
    end calcola_premio_completo_2025;



procedure calcola_premio_monta_2025 (
    p_dati_gara                    in     tc_dati_gara_esterna%rowtype,
    p_posizione                    in     number,
    p_tot_partenti                 in     number,
    p_num_con_parimerito           in     number,
    p_sequ_id_classifica_esterna   in     number,
    p_premio_cavallo                  out number)
as
    v_montepremi_tot        number := 0;
    v_montepremi_cat        number := 0;
    v_nome_manifestazione   varchar2(255);
    l_desc_formula          varchar2(50);
    v_somma_percentuali     number := 0;
begin
    if fn_gara_premiata_masaf(p_dati_gara.sequ_id_dati_gara_esterna) = 0 then
        p_premio_cavallo := 0;
        return;
    end if;
    if p_posizione not between 1 and 5 then
        p_premio_cavallo := 0;
        return;
    end if;
    select upper(mf.desc_denom_manifestazione), upper(mf.desc_formula)
      into v_nome_manifestazione, l_desc_formula
      from tc_dati_gara_esterna  dg
           join tc_dati_edizione_esterna ee on ee.sequ_id_dati_edizione_esterna = dg.fk_sequ_id_dati_ediz_esterna
           join tc_edizione ed on ed.sequ_id_edizione = ee.fk_sequ_id_edizione
           join tc_manifestazione mf on mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
     where dg.sequ_id_dati_gara_esterna = p_dati_gara.sequ_id_dati_gara_esterna;
    v_montepremi_tot := case when v_nome_manifestazione like '%FINALE%' then 12000 else 4000 end;
    v_montepremi_cat := v_montepremi_tot * 0.2;
    
    dbms_output.put_line('=== DEBUG CAVALLO ===');
    dbms_output.put_line('Posizione: ' || p_posizione);
    dbms_output.put_line('Num parimerito: ' || p_num_con_parimerito);
    dbms_output.put_line('Montepremi cat: ' || v_montepremi_cat);
    
    -- Somma le percentuali delle posizioni coinvolte nel parimerito
    for i in 0 .. least(p_num_con_parimerito - 1, 5 - p_posizione) loop
        v_somma_percentuali := v_somma_percentuali + 
            case (p_posizione + i)
                when 1 then 0.30
                when 2 then 0.25
                when 3 then 0.20
                when 4 then 0.15
                when 5 then 0.10
                else 0
            end;
        dbms_output.put_line('Loop i=' || i || ', pos=' || (p_posizione + i) || ', somma=' || v_somma_percentuali);
    end loop;
    
    dbms_output.put_line('Somma percentuali finale: ' || v_somma_percentuali);
    
    -- Divide la somma dei premi per il numero di cavalli parimerito
    p_premio_cavallo := round(v_montepremi_cat * v_somma_percentuali / greatest(p_num_con_parimerito, 1), 2);
    
    dbms_output.put_line('Premio calcolato: ' || p_premio_cavallo);
    dbms_output.put_line('===================');
    
    if p_sequ_id_classifica_esterna is not null then
        update tc_dati_classifica_esterna
           set importo_masaf_calcolato = p_premio_cavallo
         where sequ_id_classifica_esterna = p_sequ_id_classifica_esterna;
        commit;
    end if;
exception
    when no_data_found then
        p_premio_cavallo := 0;
        dbms_output.put_line('Manifestazione non trovata per gara: ' || p_dati_gara.sequ_id_dati_gara_esterna);
    when others then
        p_premio_cavallo := 0;
        dbms_output.put_line('Errore in calcola_premio_monta_2025: ' || sqlerrm);
end calcola_premio_monta_2025;
    
    
    
  FUNCTION get_endurance_classifica(p_anno IN NUMBER)
    RETURN t_endurance_tab
    PIPELINED
  IS
    l_riga                   t_endurance_row;
    v_start_date VARCHAR2(8) := TO_CHAR(p_anno) || '0101';
    v_end_date   VARCHAR2(8) := TO_CHAR(p_anno) || '1231';
  BEGIN
    FOR rec IN (
      SELECT
        ce.FK_SEQU_ID_CAVALLO                                   AS cavallo_id,
        ce.ANNO_NASCITA_CAVALLO                                 AS anno_nascita,
        CASE
          WHEN (p_anno - TO_NUMBER(ce.ANNO_NASCITA_CAVALLO)) = 4 THEN '4 DEBUTTANTI'
          WHEN (p_anno - TO_NUMBER(ce.ANNO_NASCITA_CAVALLO)) = 5 THEN '5 CEN A'
          WHEN (p_anno - TO_NUMBER(ce.ANNO_NASCITA_CAVALLO)) = 6 THEN '6 CEN B/R'
          WHEN (p_anno - TO_NUMBER(ce.ANNO_NASCITA_CAVALLO)) = 7 THEN '7 CEN B/R'
          ELSE 'ALTRE'
        END                                                     AS categoria,
        COUNT(*)                                                AS num_partecipazioni,
        SUM(NVL(ce.NUME_PUNTI,0))                               AS totale_punti,
        MIN(CASE WHEN ce.CODI_ESITO_CALCOLATO = '1' THEN 1 ELSE 0 END) AS esito_controlli
      FROM
        UNIRE_REL2.TC_DATI_GARA_ESTERNA dg
        JOIN UNIRE_REL2.TC_DATI_CLASSIFICA_ESTERNA ce
          ON ce.FK_SEQU_ID_DATI_GARA_ESTERNA = dg.SEQU_ID_DATI_GARA_ESTERNA
      WHERE
           get_disciplina(dg.FK_SEQU_ID_GARA_MANIFESTAZIONI) = 2
       AND dg.DATA_GARA_ESTERNA BETWEEN v_start_date AND v_end_date
       AND (
             dg.DESC_NOME_GARA_ESTERNA LIKE '%CIRCUITO MASAF DI ENDURANCE%'
          OR dg.DESC_NOME_GARA_ESTERNA LIKE '%FINALE CIRCUITO DI ENDURANCE%'
           )
       AND REGEXP_LIKE(
             dg.DESC_NOME_GARA_ESTERNA,
             'CEN\s*A|CEN\s*B/R|DEBUTTANTI',
             'i'
           )
       AND (p_anno - TO_NUMBER(ce.ANNO_NASCITA_CAVALLO)) BETWEEN 4 AND 7
       AND ce.FLAG_CAVALLO_MASAF   = 1
       AND ce.CODI_ESITO_CALCOLATO = '1'
      GROUP BY
        ce.FK_SEQU_ID_CAVALLO,
        ce.ANNO_NASCITA_CAVALLO
      ORDER BY
        categoria,
        SUM(NVL(ce.NUME_PUNTI,0)) DESC
    ) LOOP
    
--     cavallo_id            NUMBER,
--  anno_nascita          NUMBER,
--  categoria             VARCHAR2(10),
--  num_partecipazioni    NUMBER,
--  totale_punti          NUMBER,
--  esito_controlli       NUMBER,
--  esito_partecipazione  NUMBER
--  
    l_riga.cavallo_id := rec.cavallo_id;
    l_riga.anno_nascita := rec.anno_nascita;
    l_riga.categoria := rec.categoria;
    l_riga.num_partecipazioni := rec.num_partecipazioni;
    l_riga.totale_punti := rec.totale_punti;
   l_riga.esito_controlli := rec.esito_controlli;
   l_riga.esito_partecipazione := CASE WHEN rec.num_partecipazioni > 0 THEN 1 ELSE 0 END;
    
    
            pipe row (l_riga);
    END LOOP;

    RETURN;  -- necessario per le pipelined
  END get_endurance_classifica;
    
    
    PROCEDURE ELABORA_INCENTIVO_10_FISE (
    p_edizione_id  IN NUMBER DEFAULT NULL,
    p_anno         IN NUMBER,
    p_risultato    OUT VARCHAR2
) AS
    v_count        NUMBER := 0;
    v_data_inizio  varchar2(8);
    v_data_fine    varchar2(8);
    
BEGIN
    -- Validazione anno obbligatorio
    IF p_anno IS NULL THEN
        p_risultato := 'ERRORE: Anno obbligatorio';
        RETURN;
    END IF;
    
    -- Calcola range date per l'anno
    v_data_inizio := p_anno||'0101';
    v_data_fine   := p_anno||'1231';
    
    -- Update massivo con MERGE
    MERGE INTO tc_dati_classifica_esterna tgt
    USING (
        SELECT
            ce.SEQU_ID_CLASSIFICA_ESTERNA,
            ROUND(ce.vincite_fise * 0.10, 2) AS incentivo_10_percento
        FROM tc_dati_classifica_esterna ce
        JOIN tc_dati_gara_esterna ge 
            ON ge.SEQU_ID_DATI_GARA_ESTERNA = ce.FK_SEQU_ID_DATI_GARA_ESTERNA
        JOIN tc_cavallo c 
            ON c.sequ_id_cavallo = ce.fk_sequ_id_cavallo
        JOIN td_tipologia_razza r 
            ON r.SEQU_ID_TIPOLOGIA_RAZZA = c.FK_SEQU_ID_TIPOLOGIA_RAZZA
        WHERE ce.vincite_fise > 0
            AND ge.DESC_ALTEZZA_OSTACOLI >= 145
            AND ce.fk_sequ_id_cavallo IS NOT NULL
            AND ge.DATA_GARA_ESTERNA >= v_data_inizio
            AND ge.DATA_GARA_ESTERNA <= v_data_fine
            AND UPPER(r.DESC_RAZZA) IN ('S.I.', 'AA','P.S.O.','*AC*','*AA*','P.S.I.')
            -- Filtro opzionale per edizione specifica
            --AND (p_edizione_id IS NULL OR ce.FK_SEQU_ID_EDIZIONE = p_edizione_id)
    ) src
    ON (tgt.SEQU_ID_CLASSIFICA_ESTERNA = src.SEQU_ID_CLASSIFICA_ESTERNA)
    WHEN MATCHED THEN
        UPDATE SET 
            tgt.importo_masaf_calcolato = src.incentivo_10_percento;
    
    v_count := SQL%ROWCOUNT;
    
    COMMIT;
    
    p_risultato := 'OK: Elaborati ' || v_count || ' record per anno ' || p_anno;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_risultato := 'ERRORE: ' || SQLERRM;
        RAISE;
END ELABORA_INCENTIVO_10_FISE;
    
PROCEDURE VALIDA_EDIZ_CON_INCENTIVI_10 (
    p_anno         IN NUMBER,
    p_risultato    OUT VARCHAR2
) AS
    v_codice_esito      VARCHAR2(100);
    v_desc_esito        VARCHAR2(4000);
    v_count_tot         NUMBER := 0;
    v_count_ok          NUMBER := 0;
    v_count_err         NUMBER := 0;
    
    -- Cursor per trovare edizioni con incentivi 10%
    CURSOR c_edizioni IS
        SELECT DISTINCT 
            ee.FK_SEQU_ID_EDIZIONE,
            ge.DESC_NOME_GARA_ESTERNA,
            COUNT(ce.SEQU_ID_CLASSIFICA_ESTERNA) as num_premi
        FROM tc_dati_classifica_esterna ce
        JOIN tc_dati_gara_esterna ge 
            ON ge.SEQU_ID_DATI_GARA_ESTERNA = ce.FK_SEQU_ID_DATI_GARA_ESTERNA
        JOIN TC_DATI_EDIZIONE_ESTERNA ee ON ee.sequ_id_dati_edizione_esterna = ge.fk_sequ_id_dati_ediz_esterna
        JOIN TC_EDIZIONE ed ON ed.sequ_id_edizione = ee.fk_sequ_id_edizione
        JOIN TC_MANIFESTAZIONE mf ON mf.sequ_id_manifestazione = ed.fk_sequ_id_manifestazione
        JOIN tc_cavallo c 
            ON c.sequ_id_cavallo = ce.fk_sequ_id_cavallo
        JOIN td_tipologia_razza r 
            ON r.SEQU_ID_TIPOLOGIA_RAZZA = c.FK_SEQU_ID_TIPOLOGIA_RAZZA
        WHERE ce.importo_masaf_calcolato > 0  -- Ha incentivi calcolati
            AND ge.DESC_ALTEZZA_OSTACOLI >= 145
            AND UPPER(r.DESC_RAZZA) IN ('S.I.', 'AA','P.S.O.','*AC*','*AA*','P.S.I.')
            AND substr( ge.DATA_GARA_ESTERNA,0,4) = p_anno
            AND ee.FK_SEQU_ID_EDIZIONE IS NOT NULL
        GROUP BY ee.FK_SEQU_ID_EDIZIONE, ge.DESC_NOME_GARA_ESTERNA
        ORDER BY ee.FK_SEQU_ID_EDIZIONE;
        
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== INIZIO VALIDAZIONE EDIZIONI CON INCENTIVI 10% ===');
    DBMS_OUTPUT.PUT_LINE('Anno: ' || p_anno);
    
    FOR rec IN c_edizioni LOOP
        v_count_tot := v_count_tot + 1;
        
        BEGIN
            -- Reset variabili per ogni edizione
            v_codice_esito := NULL;
            v_desc_esito := 'Validazione edizione ' || rec.FK_SEQU_ID_EDIZIONE;
            
            -- Chiama procedura di validazione
            PKG_MANIFEST_UTIL.validaEdizione(
                idEdizione       => rec.FK_SEQU_ID_EDIZIONE,
                flagValidata     => 1,  -- 1 = valida, 0 = invalida
                codiceEsito      => v_codice_esito,
                descrizioneEsito => v_desc_esito
            );
            
            IF v_codice_esito = 'OK' OR v_codice_esito IS NULL THEN
                v_count_ok := v_count_ok + 1;
                DBMS_OUTPUT.PUT_LINE('- Edizione ' || rec.FK_SEQU_ID_EDIZIONE || 
                                    ' validata OK (' || rec.num_premi || ' premi)');
            ELSE
                v_count_err := v_count_err + 1;
                DBMS_OUTPUT.PUT_LINE('- Edizione ' || rec.FK_SEQU_ID_EDIZIONE || 
                                    ' ERRORE: ' || v_desc_esito);
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_count_err := v_count_err + 1;
                DBMS_OUTPUT.PUT_LINE('- Edizione ' || rec.FK_SEQU_ID_EDIZIONE || 
                                    ' ERRORE GRAVE: ' || SQLERRM);
        END;
        
    END LOOP;
    
    -- Riepilogo finale
    p_risultato := 'Elaborate ' || v_count_tot || ' edizioni. OK: ' || 
                   v_count_ok || ', Errori: ' || v_count_err;
    
    DBMS_OUTPUT.PUT_LINE('=== RIEPILOGO ===');
    DBMS_OUTPUT.PUT_LINE(p_risultato);
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_risultato := 'ERRORE FATALE: ' || SQLERRM;
        RAISE;
END VALIDA_EDIZ_CON_INCENTIVI_10;

end pkg_calcoli_premi_manifest;
/