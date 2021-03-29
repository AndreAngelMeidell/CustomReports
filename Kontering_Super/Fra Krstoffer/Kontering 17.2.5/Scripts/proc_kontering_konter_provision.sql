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
-- Create date: 	04 2013
-- Version:		17.2.5
-- Description:		<Description>
-- =============================================
create procedure Kontering_provisjon (@fradato as datetime, @tildato as datetime)
as
begin
SET NOCOUNT ON;
--declare @rounding bit = 1
--	declare @fradato as datetime
--	declare @tildato as datetime
--	set @fradato = '2020-06-04'
--	set @tildato = @fradato + 1
	
	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
	--set @tildato = @fradato + 1

	/*
	-- Konteringskonto.flgomvendtprovisjon brukes i de tilfeller hvor man har brukt kontonr for provisjon på varen i WinSuper
	-- På telekort og spill i kasse er dette gjort (3700 og 3705), men ikke for BlackHawk.
	-- Logikken i SQL under må derfor hensynta dette
	*/
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

union	  
	
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
		, case
			when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=1 
				then ko.mvaprosent
			when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0 
				then ko.mvaprosentprovisjon
			else bv.MVAPROSENT
		end as mvaprosent
		,case
			when ko.flgoverstyrfritekst1provisjon = 1
			then ko.overstyrFritekst1Text
			else ko.fritekst1
		end as fritekst1
		, ko.fritekst2
		, ko.fritekst3
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
	
	
	
	select --gjeld til profilhus Flax_lodd
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, 1593 as kreditkontonr
		--,CAST(sum(bv.omsetning) as decimal(18,2))
		,ROUND(CAST(SUM( bv.omsetning * 0.925 * 100 ) / 100 as decimal(18,2)),1) AS kreditbeloep --old
		--('7.5' * SUM( bv.omsetning) /100 )  

		,null as mvaprosent --20201118
		--, case
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0 
		--		then ko.mvaprosent
		--	when ko.flgoverstyrmvaprosent=1 and ko.flgomvendtprovisjon=0
		--		then ko.mvaprosentprovisjon
		--	else bv.MVAPROSENT	
		-- end as mvaprosent
		--, case
		--	when ko.flgomvendtprovisjon=0 and ko.kontonrprovisjon is null 
		--		then (select 
		--					max(fritekst1) 
		--				from super..konteringskonto 
		--				where kontonr = ko.kontonrprovisjon) --Henter fritekst1 fra konto nr provisjon
		--	else ko.fritekst1
		--  end 
		,'Salg Flax lodd' AS fritekst1
		, ko.fritekst2
		, '40' AS fritekst3
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
union

	select -- provisjon Flax_Lodd
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, 3700 as kreditkontonr
		--,CAST(sum(bv.omsetning) as decimal(18,2))
	    	--,ROUND(CAST('7.5' *(SUM(bv.omsetning) /100) as decimal(18,2)),1) as kreditbeloep --Old
		,SUM(bv.OMSETNING) -  ROUND(CAST(SUM( bv.omsetning * 0.925 * 100 ) / 100 as decimal(18,2)),1) AS kreditbeloep --Changed 20200702 AM
		,null as mvaprosent --20201118
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
		,'Flax, provisjon' as fritekst1
		, ko.fritekst2
		, '40' AS fritekst3
	from varesalg..bong b
	inner join varesalg..bongvare bv on (bv.bongid=b.bongid)
	left join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
		and ko.flgprovisjonsregel=0 
		and ko.flgprovisjonsregel is NULL
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
		,ko.flgoverstyrfritekst1provisjon
		,ko.overstyrFritekst1Text
	ORDER by fritekst1 DESC
 
    
	/* 
		NY regel for MBXP
	*/
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