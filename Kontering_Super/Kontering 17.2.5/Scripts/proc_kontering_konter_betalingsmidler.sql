USE Varesalg
go
SET ANSI_NULLS ON
go 
SET QUOTED_IDENTIFIER ON
go
if exists(SELECT * FROM   sys.procedures WHERE  name = 'Kontering_betalingsmidler') 
	begin 
		drop procedure [Kontering_betalingsmidler]
	end;
go
-- =============================================
-- Author:		Kristoffer Risa
-- Create date: 	04/2013
-- Version:		17.2.5
-- Updated: 		01.02.2019
-- Updated: 		01.07.2020 Andre Meidell
-- Updated: 		02.07.2020 Andre Meidell
-- Updated: 		12.08.2020 Andre Meidell
-- Description:	Prosedyre som henter ut betalingsmidler for konteringsoppgjøret.
-- =============================================
create procedure [dbo].[Kontering_betalingsmidler] (@fradato datetime,  @tildato datetime)
as
begin   
    --declare @fradato as datetime
    --declare @tildato as datetime
    --set @fradato = '2019-01-22' -- (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
    --set @tildato = @fradato + 1

    declare @Bankkontonr int
    , @fritekst1_Kontokreditt varchar(50)
    , @debetkontonr_Kontokreditt int
    , @sjekkVeksel as int
	, @bedriftskortGebyrKRWeb decimal(5,2)
	, @bedriftskortGebyrProsentWeb decimal(5,2)
	, @kreditkontonr INT;
    set @Bankkontonr = (select BANKKONTONR from super..systemoppsett)  --Bankkontonr eller HB (Hovedbok) kontonr, settes i WinSuper.
    set @debetkontonr_Kontokreditt = (select DEBETKONTONR from BETALINGSMIDDEL where BETALINGSMIDDELNR=6);
    set @fritekst1_Kontokreditt = (select fritekst1 from BETALINGSMIDDEL where BETALINGSMIDDELNR=6);
    set @bedriftskortGebyrKRWeb = 0.3;
	set @bedriftskortGebyrProsentWeb = 0.5;

    --Changed by Andre 20200812 from ='' to like '%%'	
    SET @kreditkontonr = ( SELECT   CASE WHEN KJEDE like '%MENY%'
                                                  THEN '554654'
                                             WHEN KJEDE like '%KIWI%'
                                                  THEN '541319'
                                             ELSE '569589'
                                    END AS 'kreditkontonr'
                           FROM     Super..SYSTEMOPPSETT AS kjede);
 

    select --§§§ Betalingsmidler generelt
            b.utsalgsstednr,
            null as avdelingsnr,
            (case 
                when sum(bb.beloep)<0 then null -- negativt beløp skal føres på kredit
                when sum(bb.beloep)>=0 and bm.flgbankkontonrfrasystemoppsett=1 then @Bankkontonr 
                else bm.debetkontonr
            end) as debetkontonr,
            (case
                when sum(bb.beloep)<0 then null
                else sum(bb.beloep)
            end) as debetbeloep,
            (case 
                when sum(beloep)>=0 then null
                when sum(beloep)<0 and bm.flgbankkontonrfrasystemoppsett=1 then @Bankkontonr     
                else bm.debetkontonr
            end) as kreditkontonr,
            (case
                when sum(BELOEP)>=0 then null
                else -1 * sum(bb.beloep) -- ganger med -1 for at beløpet skal bli positivt
            end) as kreditbeloep,   
            null as mvaprosent,
            bm.fritekst1,
            bm.fritekst2,
            bm.fritekst3
    from varesalg..bong b
            inner join varesalg..bongbetmid bb on bb.bongid=b.bongid
            inner join varesalg..betalingsmiddel bm on bm.betalingsmiddelnr=bb.BETALINGSMIDDELNR 
                and bm.flgEgenRegel=0
    where b.datotid>=@fradato 
            and b.datotid<@tildato  
    group by 
            b.utsalgsstednr,
            --bb.BETALINGSMIDDELNR, /*Fjernet grunnet PocketPOS, ref sak Ultra SKI. Butikken har CashGuard i kassene, men vanlig kontant på PocketPOS.*/
            bm.debetkontonr,
            bm.fritekst1,
            bm.fritekst2,
            bm.fritekst3,
            bm.flgbankkontonrfrasystemoppsett
	
	select --§§§ Valuta
		b.utsalgsstednr
		, null as avdelingsnr
		, bm.DEBETKONTONR as debetkontonr
		,Sum(bb.beloep) as debetbeloep
		, null as kreditkontonr
		,null as kreditbeloep
		,null as mvaprosent
		,bm.FRITEKST1 + ' ' + v.NAVN as fritekst1
		,null as fritekst2
		,null as fritekst3
	from varesalg..bong b		
	left join varesalg..bongbetmid bb 
		on (bb.bongid = b.bongid)
	left join varesalg..BONGBETMIDVALUTA bmv 
		on (bmv.BONGID = b.BONGID)
	inner join super..VALUTA v 
		on (v.ID = bmv.ID)
	inner join varesalg..BETALINGSMIDDEL bm
		on (bb.BETALINGSMIDDELNR = bm.BETALINGSMIDDELNR 
		and bm.BETALINGSMIDDELNR = 8 
		and bm.flgEgenRegel = 1)
	where  b.datotid >= @fradato
		and b.datotid < @tildato
	group  by 
		b.utsalgsstednr
		,bm.DEBETKONTONR
		,bm.FRITEKST1			
		,v.NAVN
	
	select --§§§ Bankkort
            b.utsalgsstednr,
            null as avdelingsnr,
            (case bk.flgbankkontonrfrasystemoppsett
            when 1 then @Bankkontonr
            else bk.debetkontonr
            end) as debetkontonr,
            SUM(bg.VERDI1) AS debetbeloep,		
            null as kreditkontonr,
            null as kreditbeloep,
            null as mvaprosent,
            (case  
            when bk.fritekst1 is null then bk.NAVN
            else bk.fritekst1 
            end) as fritekst1,
            bk.fritekst2 as fritekst2,
            cast(bk.prosjektkode as varchar(2)) as fritekst3
    from varesalg..bong b
            inner join bongbetmid bb on b.bongid=bb.bongid 
                and bb.betalingsmiddelnr in (3,5,14) --bank,bankreserve,bankmanuell
            inner join bonggenfelt bg on b.bongid=bg.bongid 
                and bg.feltnr=3200 -- dette er feltnr for bankkort beløp i genfelt
            inner join bankkort bk on bk.typenr=bg.feltdata1 --typenr = issuerid
    where datotid>=@fradato 
            and datotid<@tildato 
			AND bk.flgGebyrRegel = 0
			AND (case bk.flgbankkontonrfrasystemoppsett
			            when 1 then @Bankkontonr
			            else bk.debetkontonr
			            end) IS NOT NULL 
    group by
            b.utsalgsstednr,
            bk.prosjektkode,
            bk.debetkontonr,
            bk.fritekst1,
            bk.fritekst2,
            bk.NAVN,
            bk.flgbankkontonrfrasystemoppsett
			,bk.flgGebyrRegel
			,bk.GebyrKroner
			,bk.GebyrProsent
	
	select --§§§ Webhandel med bankkort 
		b.utsalgsstednr,
        null as avdelingsnr,
        (case 
            when sum(bb.beloep)<0 then null -- negativt belÃ¸p skal fÃ¸res pÃ¥ kredit
            when sum(bb.beloep)>=0 and bm.flgbankkontonrfrasystemoppsett=1 
			then @Bankkontonr 
            else bm.debetkontonr
        end) as debetkontonr,
        (case
            when sum(bb.beloep)-isnull(t.web,0) <0 then null
            else sum(bb.beloep)-isnull(t.web,0)
        end) as debetbeloep,
        (case 
            when sum(beloep)-isnull(t.web,0)>=0 then null
            when sum(beloep)-isnull(t.web,0)<0 and bm.flgbankkontonrfrasystemoppsett=1 
			then @Bankkontonr     
            else bm.debetkontonr
        end) as kreditkontonr,
        (case
            when sum(BELOEP)-isnull(t.web,0)>=0 then null
            else -1 * (sum(bb.beloep)-isnull(t.web,0)) -- ganger med -1 for at belÃ¸pet skal bli positivt
        end) as kreditbeloep, 
        null as mvaprosent,
        bm.fritekst1,
        bm.fritekst2,
        bm.fritekst3
	from varesalg..bong b
		inner join varesalg..bongbetmid bb on bb.bongid=b.bongid
        inner join varesalg..betalingsmiddel bm on bm.betalingsmiddelnr=bb.BETALINGSMIDDELNR 
            and bm.flgEgenRegel=1
			and bm.BETALINGSMIDDELNR = 24
	outer apply (
			select sum(webhandel) as web
			from rapporter..KASSERESUBTENDER ks 
			where ks.DATO = cast(b.DATOTID as date)
				and SubTender = 'NGCORP'
		) as t
    where b.datotid>=@fradato 
            and b.datotid<@tildato  
    group by 
            b.utsalgsstednr,
            --bb.BETALINGSMIDDELNR, /*Fjernet grunnet PocketPOS, ref sak Ultra SKI. Butikken har CashGuard i kassene, men vanlig kontant pÃ¥ PocketPOS.*/
            bm.debetkontonr,
            bm.fritekst1,
            bm.fritekst2,
            bm.fritekst3,
			t.web ,
			cast(b.DATOTID as DATE),
            bm.flgbankkontonrfrasystemoppsett
	having SUM(bb.beloep)-isnull(t.web,0) <> 0

	if exists(select  * from tempdb.dbo.sysobjects o
				where o.xtype in ('U') 
					and o.id = object_id(N'tempdb..#bongermedgebyr') )
	begin
		drop table #bongermedgebyr;
	end

	select -- NY temp bonger med gebyr		
		b.UTSALGSSTEDNR
		,b.BONGNR
		,bg.FELTDATA1
		, ROUND(CAST(CAST(SUM(ISNULL(bg.verdi1,0)) - SUM(ISNULL(bg.verdi1,0) / 100 * ISNULL(bk.GebyrProsent,1)) - ISNULL(bk.GebyrKroner,0) AS DECIMAL(12,4)) AS MONEY),2) AS Netto
		,CASE 
			WHEN 
				ROUND(CAST(CAST(SUM(ISNULL(bg.verdi1,0)) - SUM(ISNULL(bg.verdi1,0) / 100 * ISNULL(bk.GebyrProsent,1)) - ISNULL(bk.GebyrKroner,0) AS DECIMAL(12,4)) AS MONEY),2) 
					+
				ROUND(CAST(CAST(ISNULL(bk.GebyrKroner,0) +  SUM(bg.verdi1/100*ISNULL(bk.GebyrProsent,1)) AS DECIMAL(12,4)) AS MONEY) ,2) 
					!= 
				ROUND(CAST(SUM(bg.VERDI1) AS MONEY) ,2)
			THEN 
				FLOOR(CAST(CAST(ISNULL(bk.GebyrKroner,0) +  SUM(bg.verdi1/100*ISNULL(bk.GebyrProsent,1)) AS DECIMAL(12,4)) AS MONEY)*100)/100
			ELSE 
				ROUND(CAST(CAST(ISNULL(bk.GebyrKroner,0) +  SUM(bg.verdi1/100*ISNULL(bk.GebyrProsent,1)) AS DECIMAL(12,4)) AS MONEY) ,2) 
			END AS Gebyr	
		, ROUND(CAST(SUM(bg.VERDI1) AS MONEY) ,2)AS Brutto
	INTO #bongermedgebyr
	FROM varesalg..bong b 
		inner join bongbetmid bb on b.bongid=bb.bongid 
				and bb.betalingsmiddelnr in (3,5,14)
			inner join bonggenfelt bg on b.bongid=bg.bongid 
				and bg.feltnr=3200 
			inner join bankkort bk on bk.typenr=bg.feltdata1 
			AND bk.flgGebyrRegel = 1
	where datotid>=@fradato and datotid<@tildato 
	GROUP BY  
		b.UTSALGSSTEDNR	,bongnr, bg.FELTDATA1, bk.GebyrKroner,bg.verdi1,bk.GebyrProsent

	insert into #bongermedgebyr --§§§ Bonger med gebyr (webhandel på NGBedriftskort - gebyr 30 øre pr trans + 0.5% av handelen)
	select top 1 
		0 as UTSALGSSTEDNR
		, -1 as BONGNR
		, -1 as FELTDATA1
	  , round(cast(SUM([Webhandel]) - sum([Webhandel] / 100 * @bedriftskortGebyrProsentWeb) -sum([NGCORPANTALL]* @bedriftskortGebyrKRWeb) as money),2)  as Netto
	 , case
		when 
			round(cast(SUM([Webhandel]) - sum([Webhandel] / 100 *  @bedriftskortGebyrProsentWeb) -sum([NGCORPANTALL]* @bedriftskortGebyrKRWeb) as money),2) -- Avrundet netto
			  +
			round(cast(sum([NGCORPANTALL]*GebyrKroner)	+ SUM([Webhandel] / 100 *@bedriftskortGebyrProsentWeb) as money),2) -- Avrundet gebyr
			  !=
			round(cast(sum([Webhandel]) as money),2) 
		then 
			--'ROUNDING NEEDED'
			floor(cast(sum([NGCORPANTALL] * @bedriftskortGebyrKRWeb)	+ SUM([Webhandel] / 100 * @bedriftskortGebyrProsentWeb) as money)*100)/100 
		else
			--'NO ROUNDING'
			round(cast(sum([NGCORPANTALL] * @bedriftskortGebyrKRWeb)	+ SUM([Webhandel] / 100 * @bedriftskortGebyrProsentWeb) as money),2)
		END AS Gebyr
	  , round(cast(sum([Webhandel]) as money),2) as Brutto 
	from [Rapporter].[dbo].KASSERESUBTENDER
	cross APPLY
		(
			select bk.GebyrProsent,bk.GebyrKroner
			from varesalg..bankkort bk 
			where typenr = 57 -- NG Bedriftskort
		) t
	where dato = cast(@fradato as date)
		and Subtender = 'NGCORP'
	group by 
		[DATO]
	  , [SubTender]
	  ,t.GebyrProsent
	  ,t.GebyrKroner
	order by [DATO] desc 

	--select * from #bongermedgebyr

	select --§§§ Bankkort gebyr 1/2
        bg.utsalgsstednr
		,null as avdelingsnr
		,(case bk.flgbankkontonrfrasystemoppsett
            when 1 then @Bankkontonr
            else bk.debetkontonr
            end) as debetkontonr
        , SUM(CAST(netto AS DECIMAL(12,2))) AS debetbeloep
        , NULL as kreditkontonr
        , NULL as kreditbeloep
        , NULL as mvaprosent
        ,(case  
            when bk.fritekst1 is null then bk.NAVN
            else bk.fritekst1 
            end) as fritekst1,
            bk.fritekst2 as fritekst2,
            cast(bk.prosjektkode as varchar(2)) as fritekst3
    from #bongermedgebyr bg
        inner join bankkort bk on bk.typenr=bg.feltdata1 --typenr = issuerid
			or (bk.typenr=57 and bongnr = -1) -- Custom håndtering av NGBedriftskort fra webhandel
    WHERE bk.flgGebyrRegel = 1
    group by
            bg.utsalgsstednr,
            bk.prosjektkode,
            bk.NAVN,
            bk.flgbankkontonrfrasystemoppsett,
			bk.fritekst1,
			bk.fritekst2,
			bk.debetkontonr

	select --§§§ Bankkort gebyr 2/2
        bg.utsalgsstednr
		,null as avdelingsnr
		, bk.GebyrDebetKontoNr AS  debetkontonr
        , SUM(CAST(gebyr AS DECIMAL(12,2))) AS debetbeloep
        , NULL as kreditkontonr
        , NULL as kreditbeloep
        , bk.GebyrMva as mvaprosent
        , bk.GebyrFritekst1 AS fritekst1
		 ,bk.GebyrFritekst2 AS fritekst2
        , CAST(bk.prosjektkode as varchar(2)) as fritekst3
    from #bongermedgebyr bg
        inner join bankkort bk on bk.typenr=bg.feltdata1 --typenr = issuerid
			or (bk.typenr=57 and bongnr = -1) -- Custom håndtering av NGBedriftskort fra webhandel
    group by
            bg.utsalgsstednr,
            bk.prosjektkode,
            bk.GebyrDebetKontoNr,
           bk.GebyrFritekst1,
            bk.GebyrFritekst2,
            bk.NAVN,
            bk.flgbankkontonrfrasystemoppsett  ,
			bk.GebyrKroner,
			bk.GebyrMva

	select --§§§ Kontokunde Salg
            b.utsalgsstednr
            , null as avdelingsnr
            , @debetkontonr_Kontokreditt as debetkontonr
            ,sum(bb.beloep) as debetbeloep
            , null as kreditkontonr
            ,null as kreditbeloep
            , null as mvaprosent
            ,@fritekst1_Kontokreditt as fritekst1
            ,null as fritekst2
            ,null as fritekst3
    from varesalg..bong b
    left join varesalg..bongbetmid bb on bb.bongid = b.bongid
    where  b.datotid >= @fradato
            and b.datotid < @tildato
            and bb.betalingsmiddelnr = 6
    group  by 
            b.utsalgsstednr
			
	--Changed by Andre 20200702 'fritekst1' to 'fritekst2' and 'null as fritekst2'
	select --§§§ Flaxlodd gevinst
            b.utsalgsstednr
            , null as avdelingsnr
            , @kreditkontonr as debetkontonr
            , sum(bb.beloep) as debetbeloep
            , null as kreditkontonr
            ,null as kreditbeloep
            , null as mvaprosent
            ,'Innløst gevinst Flaxlodd ' as fritekst1
            , null as fritekst2
            ,'40' as fritekst3
    from varesalg..bong b
    left join varesalg..bongbetmid bb on bb.bongid = b.bongid
    where  b.datotid >= @fradato
            and b.datotid < @tildato
            and bb.betalingsmiddelnr = 300
    group  by 
            b.utsalgsstednr
			

	select --§§§ Innbetaling
            b.utsalgsstednr
            , null as avdelingsnr
            , null as debetkontonr
            , null as debetbeloep
            , @debetkontonr_Kontokreditt as kreditkontonr
            , sum(b.innbetalt) as kreditbeloep 
            , null as mvaprosent
            ,@fritekst1_Kontokreditt as fritekst1
            ,null as fritekst2
            ,null as fritekst3                                    
    from varesalg..bong b 
    where  b.datotid >= @fradato
            and b.datotid < @tildato
            and (
                -- b.kundenr > 0  and 
                b.innbetalt != 0 
            )
    group  by 
            b.utsalgsstednr

    select --Utlegg (Interimskonto)  (Lagt til 19.06.2013, regel er delvis dynamisk, den er hardkodet linket til konteringskonto på kontonr = 1795)  
            b.utsalgsstednr
            , null as avdelingsnr
            , ko.kontonr as debetkontonr
            , sum(b.utbetalt) as debetbeloep
            , null as kreditkontonr
            , null as kreditbeloep
            , null as mvaprosent
            , ko.fritekst1
            , ko.fritekst2
            , ko.fritekst3
    from bong b
            left join bongvaregenfelt bvg on bvg.bongid=b.bongid 
                and bvg.feltnr=4000 
                and bvg.ean=99966
            inner join super..konteringskonto ko on ko.kontonr = 1795
    where b.datotid>=@fradato 
            and b.datotid<@tildato 
            and b.utbetalt<>0 
            and bvg.bongid is null
    group by
            b.utsalgsstednr
            , ko.kontonr
            , ko.fritekst1
            , ko.fritekst2
            , ko.fritekst3      
       
    select --Regelnr. 5.3.9 Tømming av veksel
            null as utsalgsstednr
            , null as avdelingsnr
            , 1910 as debetkontonr
            , sum(kl.verdi) as debetbeloep
            , 1900 as kreditkontonr
            , sum(kl.verdi) as kreditbeloep
            , null as mvaprosent
            , kl.posenr as fritekst1
            , kl.hendelsesid as fritekst2
            , null as fritekst3
    from super..khsoppgjoer k
            inner join super..khsoppgjoerlinje kl on k.khsoppgjoerid=kl.khsoppgjoerid
    where k.oppgjoerfordato>=@fradato 
            and k.oppgjoerfordato<@tildato 
            and kl.kode='TTB'
    group by kl.posenr, kl.hendelsesid

    set @sjekkVeksel = (select count(*) from super..khsoppgjoer k inner join super..khsoppgjoerlinje kl on k.khsoppgjoerid=kl.khsoppgjoerid 
                                    where k.oppgjoerfordato>=@fradato 
                                            and k.oppgjoerfordato<@tildato 
                                            and kl.kode='PFB');
    if (@sjekkVeksel > 0)
            begin --Kjører SQL dersom det finnes data i khsoppgjoer tabellen.
                -- Regel 5.3.10 Kjøp av veksel
                select 
                        null as utsalgsstednr
                        , null as avdelingsnr
                        , 1900 as debetkontonr
                        , sum(kl.verdi) as debetbeloep
                        , 1920 as kreditkontonr
                        , sum(kl.verdi) as kreditbeloep
                        , null as mvaprosent                    
                        , cast('Kjøp veksel' as varchar(50)) as fritekst1
                        , cast('' as varchar(50)) as fritekst2
                        , null as fritekst3
                from super..khsoppgjoer k
                        inner join super..khsoppgjoerlinje kl on k.khsoppgjoerid=kl.khsoppgjoerid
                where k.oppgjoerfordato>=@fradato 
                        and k.oppgjoerfordato<@tildato 
                        and kl.kode='PFB'
            end --Ferdig med SQL for Kjøp av veksel
end
go