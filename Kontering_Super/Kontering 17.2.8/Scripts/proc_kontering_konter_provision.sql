use Varesalg
go

SET ANSI_nullS ON
GO
SET QUOTED_IDENTIFIER ON
GO
if exists(SELECT * FROM   sys.procedures WHERE  name = 'Kontering_provisjon') 
	begin 
		drop procedure Kontering_provisjon 
	end;
go
-- =============================================
-- Author:		VR Konsulent
-- Create date: 04 2013
-- Version:		17.2.8
-- Changed:		14.04.2021 Andre Meidell NG-2203
-- =============================================
CREATE procedure [dbo].[Kontering_provisjon] (@fradato as datetime, @tildato as datetime)
as
begin
SET NOCOUNT ON;
--declare @fradato as datetime
--declare @tildato as datetime
--set @fradato = '2021-03-29 00:00:00'
--set @tildato = '2021-03-29 23:59:59'

/*
-- Konteringskonto.flgomvendtprovisjon brukes i de tilfeller hvor man har brukt kontonr for provisjon på varen i WinSuper
-- På telekort og spill i kasse er dette gjort (3700 og 3705), men ikke for BlackHawk.
-- Logikken i SQL under må derfor hensynta dette
*/

--New 20210414
DECLARE @kreditkontonr INT;
SET @kreditkontonr = ( SELECT   CASE WHEN KJEDE like '%MENY%'
                                                  THEN '554654'
                                             WHEN KJEDE like '%KIWI%'
                                                  THEN '541319'
                                             ELSE '569589'
                                    END AS 'kreditkontonr'
                           FROM     Super..SYSTEMOPPSETT AS kjede);
						   
IF OBJECT_ID('#SIK') IS NOT NULL 
	DROP TABLE #SIK
IF OBJECT_ID('#PROV') IS NOT NULL 
	DROP TABLE #PROV
IF OBJECT_ID('#SalgFlax') IS NOT NULL 
	DROP TABLE #SalgFlax
IF OBJECT_ID('#sum') IS NOT NULL 
	DROP TABLE #sum


select --gjeld til profilhus
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, case
			when ko.flgomvendtprovisjon=0 
				then bv.KREDITKONTO
			when ko.flgomvendtprovisjon=1 
				then ko.kontonrprovisjon  
			else bv.KREDITKONTO
		  end as kreditkontonr
		, cast(sum(bv.omsetning) as decimal(18,2))
			- cast(sum(bv.omsetning - ((bv.OMSETNING/(1 + bv.MVAPROSENT * 0.01)) 
			* (0.01 * bv.MVAPROSENT)) - bv.innverdi) as decimal(18,2)) as kreditbeloep
		, case
			when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0 
				then ko.mvaprosent
			when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=1 
				then ko.mvaprosentprovisjon
			else bv.MVAPROSENT	
		  end as mvaprosent
		, case
			when ko.flgomvendtprovisjon=1 and ko.kontonrprovisjon is not null 
				then (select 
							max(fritekst1) 
						from super..konteringskonto 
						where kontonr = ko.kontonrprovisjon) --Henter fritekst1 fra konto nr provisjon
			else ko.fritekst1
		  end as fritekst1
		, ko.fritekst2
		, ko.fritekst3
	INTO #SIK
	from bong b
	inner join varesalg..bongvare bv on (bv.bongid=b.bongid)
	left join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
		and ko.flgprovisjonsregel=1 
		and ko.flgprovisjonsregel is not NULL
		AND ko.flgegenregel = 0)
	where b.datotid>=@fradato 
		and b.datotid<@tildato
		and bv.ean in (select eannr from varesalg..eaninfo where eannr = bv.ean and vareegenskap in (select * from FN_ListToTable(',',ko.vareegenskap)) or VARETYPE in (select * from FN_ListToTable(',',ko.varetype)) )
	group by 
		b.utsalgsstednr
		, bv.kreditkonto
		, bv.mvaprosent		
		, ko.flgoverstyrmvaprosent
		, ko.mvaprosent
		, ko.flgomvendtprovisjon
		, ko.mvaprosentprovisjon
		, ko.kontonrprovisjon
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3 

--union	  
	
	select -- provisjon
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, case
			when ko.flgomvendtprovisjon=1 
				then bv.KREDITKONTO
			when ko.flgomvendtprovisjon=0 
				then ko.kontonrprovisjon
			else bv.KREDITKONTO
		end as kreditkontonr
		, cast(sum(bv.omsetning - ((bv.OMSETNING/(1 + bv.MVAPROSENT * 0.01)) * (0.01 * bv.MVAPROSENT)) - bv.innverdi) as decimal(18,2)) as kreditbeloep
		-- 20210422 ref mail fra Helge mva=0
		--, case
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=1 
		--		then ko.mvaprosent
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0 
		--		then ko.mvaprosentprovisjon
		--	else bv.MVAPROSENT
		--end as mvaprosent
		, 0 AS mvaprosent
		,case
			when ko.flgoverstyrfritekst1provisjon = 1
			then ko.overstyrFritekst1Text
			else ko.fritekst1
		end as fritekst1
		, ko.fritekst2
		, ko.fritekst3
	INTO #PROV
	from varesalg..bong b
	inner join varesalg..bongvare bv on (bv.bongid=b.bongid)
	left join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
		and ko.flgprovisjonsregel=1 
		and ko.flgprovisjonsregel is not NULL
		AND ko.flgegenregel = 0)
	where b.datotid>=@fradato 
		and b.datotid<@tildato
		and bv.ean in (select eannr from varesalg..eaninfo where eannr = bv.ean and vareegenskap in (select * from FN_ListToTable(',',ko.vareegenskap)) or VARETYPE in (select * from FN_ListToTable(',',ko.varetype)) )  
	group by
		b.utsalgsstednr
		, bv.kreditkonto
		, bv.mvaprosent		
		, ko.flgoverstyrmvaprosent
		, ko.mvaprosent
		, ko.flgomvendtprovisjon
		, ko.mvaprosentprovisjon
		, ko.kontonrprovisjon
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3 
		,ko.flgoverstyrfritekst1provisjon
		,ko.overstyrFritekst1Text
	ORDER by fritekst1 DESC
	
	
	
	select --Flaxlodd gevinst skal sammen med SIK "Spill i kasse, gjeld til profilhus" over
             b.utsalgsstednr
            ,null as avdelingsnr
            ,null as debetkontonr
            ,null as debetbeloep
            ,@kreditkontonr as kreditkontonr
            ,sum(bb.beloep)*-1 as kreditbeloep
            ,null as mvaprosent
            ,'Spill i kasse, gjeld til profilhus ' as fritekst1
            ,null as fritekst2
            ,'8' as fritekst3
	INTO #SalgFlax
    from varesalg..bong b
    left join varesalg..bongbetmid bb on bb.bongid = b.bongid
    where  b.datotid >= @fradato
            and b.datotid < @tildato
            and bb.betalingsmiddelnr = 300
    group  by 
            b.utsalgsstednr
	
	
	SELECT * INTO #SUM FROM (
	SELECT  * 
	FROM #SIK
	UNION All
	SELECT  * 
	FROM #PROV
	UNION All
	SELECT * 
	FROM #SalgFlax
	) as tmp

	SELECT 
	s.UTSALGSSTEDNR
	,s.avdelingsnr
	,s.debetkontonr
	,SUM(s.debetbeloep) AS debetbeloep 
	,s.kreditkontonr
	,SUM(s.kreditbeloep) AS kreditbeloep 
	,s.mvaprosent
	,s.fritekst1
	,s.fritekst2
	,s.fritekst3 
FROM  #SUM AS s
GROUP BY s.UTSALGSSTEDNR,s.avdelingsnr,s.debetkontonr, s.kreditkontonr,s.mvaprosent, s.fritekst1,s.fritekst2, s.fritekst3
ORDER BY s.fritekst1 DESC


--Flax salg 20210420
	--K – 1593 (Verdi av loddpakke inkl. provisjon på 7,5% av salget, mva felt blank)
	select --Beholdning/Salg Flaxlodd konto 1593 kun omsettning endres til å vise kun bv.omsetning
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, 1593 as kreditkontonr
		--,CAST(sum(bv.omsetning) as decimal(18,2)) --old
		--,ROUND(CAST(SUM( bv.omsetning * 0.925 * 100 ) / 100 as decimal(18,2)),1) AS kreditbeloep --old
		,CAST(sum(bv.omsetning) as decimal(18,2)) as kreditbeloep --20210217
		,null as mvaprosent --20201118
		,'Spill i kasse og Flaxlodd' AS fritekst1
		, ko.fritekst2
		, '8' AS fritekst3
	from bong b
	inner join varesalg..bongvare bv on (bv.bongid=b.bongid)
	left join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
		and ko.flgprovisjonsregel=0
		and ko.flgprovisjonsregel is not NULL
		AND ko.flgegenregel = 0)
	where b.datotid>=@fradato 
		and b.datotid<@tildato
		and bv.ean in (select eannr from varesalg..eaninfo where eannr = bv.ean and VAREEGENSKAP IN(33,38)  AND VARETYPE IN(0,11) )  
	group by 
		b.utsalgsstednr
		, bv.kreditkonto
		, bv.mvaprosent		
		, ko.flgoverstyrmvaprosent
		, ko.mvaprosent
		, ko.flgomvendtprovisjon
		, ko.mvaprosentprovisjon
		, ko.kontonrprovisjon
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3 
    
	
--Fjernet 20210217
--union

--	select -- provisjon Flax_Lodd  Fjernes da provisjon hentes fra FlaxStatistikk kun ved aktivering
--		b.utsalgsstednr
--		, null as avdelingsnr
--		, null as debetkontonr
--		, null as debetbeloep
--		, 3700 as kreditkontonr
--		--,CAST(sum(bv.omsetning) as decimal(18,2))
--	    	--,ROUND(CAST('7.5' *(SUM(bv.omsetning) /100) as decimal(18,2)),1) as kreditbeloep --Old
--		,SUM(bv.OMSETNING) -  ROUND(CAST(SUM( bv.omsetning * 0.925 * 100 ) / 100 as decimal(18,2)),1) AS kreditbeloep --Changed 20200702 AM
--		,null as mvaprosent --20201118
		--, case
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0
		--		then ko.mvaprosent
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0 
		--		then ko.mvaprosentprovisjon
		--	else bv.MVAPROSENT
		--end as mvaprosent
		--,case
		--	when ko.flgoverstyrfritekst1provisjon = 0
		--	then ko.overstyrFritekst1Text
		--	else ko.fritekst1
		--end 
--		,'Flax, provisjon' as fritekst1
--		, ko.fritekst2
--		, '40' AS fritekst3
--	from varesalg..bong b
--	inner join varesalg..bongvare bv on (bv.bongid=b.bongid)
--	left join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
--		and ko.flgprovisjonsregel=0 
--		and ko.flgprovisjonsregel is NULL
--		AND ko.flgegenregel = 0)
--	where b.datotid>=@fradato 
--		and b.datotid<@tildato
--		and bv.ean in (select eannr from varesalg..eaninfo where eannr = bv.ean and VAREEGENSKAP IN(33,38)  AND VARETYPE IN(0,11) )  
--	group by
--		b.utsalgsstednr
--		, bv.kreditkonto
--		, bv.mvaprosent		
--		, ko.flgoverstyrmvaprosent
--		, ko.mvaprosent
--		, ko.flgomvendtprovisjon
--		, ko.mvaprosentprovisjon
--		, ko.kontonrprovisjon
--		, ko.fritekst1
--		, ko.fritekst2
--		, ko.fritekst3 
--		,ko.flgoverstyrfritekst1provisjon
--		,ko.overstyrFritekst1Text
--	ORDER by fritekst1 DESC
 
    

-- Regel for pkt 5.1.14 MBXP

	select 
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, case
			when ko.flgomvendtprovisjon=0 
				then bv.KREDITKONTO
			when ko.flgomvendtprovisjon=1 
				then ko.kontonrprovisjon  
			else bv.KREDITKONTO
			end as kreditkontonr
		, SUM(bv.OMSETNING) as kreditbeloep
		-- Changed 20210415 AM Ref pkt 5.1.14 Mva er Blank
		--, case
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0 
		--		then ko.mvaprosent
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=1 
		--		then ko.mvaprosentprovisjon
		--	else bv.MVAPROSENT	
		--	end as mvaprosent
		, null as mvaprosent
		, case
			when ko.flgomvendtprovisjon=1 and ko.kontonrprovisjon is not null 
				then (select 
							max(fritekst1) 
						from super..konteringskonto 
						where kontonr = ko.kontonrprovisjon) --Henter fritekst1 fra konto nr provisjon (MBXP)
			else ko.fritekst1
			end as fritekst1
		, (
	 		CAST(CAST(SUM(bv.omsetning - ((bv.OMSETNING/(1 + bv.MVAPROSENT * 0.01)) * (0.01 * bv.MVAPROSENT)) - bv.innverdi) AS DECIMAL(14,2)) AS VARCHAR(100))
		) AS fritekst2
		, ko.fritekst3
	from bong b
	inner join varesalg..bongvare bv on (bv.bongid=b.bongid)
	left join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
		and ko.flgprovisjonsregel = 1
		and ko.flgegenregel = 1 )
	where b.datotid>=@fradato 
		and b.datotid<@tildato
		and bv.ean in (select eannr from varesalg..eaninfo where eannr = bv.ean and vareegenskap in (select * from FN_ListToTable(',',ko.vareegenskap)) or VARETYPE in (select * from FN_ListToTable(',',ko.varetype)) )
	group by 
		b.utsalgsstednr
		, bv.kreditkonto
		, bv.mvaprosent		
		, ko.flgoverstyrmvaprosent
		, ko.mvaprosent
		, ko.flgomvendtprovisjon
		, ko.mvaprosentprovisjon
		, ko.kontonrprovisjon
		, ko.fritekst1
		, ko.fritekst3 

end

go