USE Varesalg
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:			VR Konsulent
-- Create date: 	04 2013
-- Version:			17.2.6
-- Description: 	Kontering for BIB	
-- =============================================

if exists(SELECT * FROM   sys.procedures WHERE  name = 'Kontering_bib') 
	begin 
		drop procedure Kontering_bib 
	end;
go

create procedure Kontering_bib (@fradato as datetime, @tildato as datetime)
as
begin
	SET NOCOUNT ON;

	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
	--set @tildato = @fradato + 1

	declare @bankkontonr as varchar(5);
	set @bankkontonr = (select bankkontonr from super..SYSTEMOPPSETT)

	select
		b.utsalgsstednr
		, null as avdelingsnr
		, @bankkontonr as debetkontonr
		, -1 * sum(bv.omsetning) as debetbeloep
		, null as kreditkontonr
		, null as kreditbeloep
		, null as mvaprosent
		, ko.fritekst1
		, ko.fritekst2 /*'Antall transaksjoner: '*/ + cast(cast(sum(bv.stk)as integer) as varchar(10)) as fritekst2
		, ko.fritekst3
	from varesalg..bong b
	inner join varesalg..bongvare bv on bv.bongid=b.bongid
	inner join varesalg..eaninfo e on e.eannr=bv.ean 
		and e.varetype in (3,4)
		and e.eanid=(select max(e2.eanid) 
					from varesalg..eaninfo e2 
					where e2.eannr=e.eannr)
	left join super..KONTERINGSKONTO ko on e.VARETYPE in (select * from FN_ListToTable(',',ko.varetype))--Endret slik at linken blir varetype.	
	where b.datotid>=@fradato 
		and b.datotid<@tildato
	group by 
		b.utsalgsstednr
		,bv.kreditkonto
		,ko.fritekst1
		,ko.fritekst2
		,ko.fritekst3 
	having sum(bv.omsetning) < 0

	select
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, @bankkontonr as kreditkontonr
		, sum(bv.omsetning) as kreditbeloep
		, null as mvaprosent
		, ko.fritekst1
		, ko.fritekst2 /*'Antall transaksjoner: '*/ + cast(cast(sum(bv.stk)as integer) as varchar(10)) as fritekst2
		, ko.fritekst3       
	from varesalg..bong b
	inner join varesalg..bongvare bv on bv.bongid=b.bongid
	inner join varesalg..eaninfo e on e.eannr=bv.ean 
		and e.varetype in (3,4)
		and e.eanid=(select max(e2.eanid) 
					from varesalg..eaninfo e2 
					where e2.eannr=e.eannr)
	left join super..KONTERINGSKONTO ko on e.VARETYPE in (select * from FN_ListToTable(',',ko.varetype))	  
	where b.datotid>=@fradato 
		and b.datotid<@tildato
	group by 
		b.utsalgsstednr
		,bv.kreditkonto
		,ko.fritekst1
		,ko.fritekst2
		,ko.fritekst3 
	having sum(bv.omsetning) >= 0

	select
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, @bankkontonr as kreditkontonr
		, sum(bv.omsetning) as kreditbeloep
		, null as mvaprosent
		, case bvg.feltdata1
			when '5' then 'BiB gebyr innskudd' 
			when '6' then 'BiB gebyr uttak'
			else 'Feil'
		  end as fritekst1
		, 'Antall transaksjoner: ' + cast(cast(sum(bv.stk)as integer) as varchar(10)) as fritekst2
		, null as fritekst3
	from varesalg..bong b
	inner join varesalg..bongvare bv on bv.bongid=b.bongid
	inner join varesalg..BONGVAREGENFELT bvg on bvg.bongid=bv.bongid 
		and bvg.ean=bv.ean 
		and bvg.feltnr=3000 
		and (bvg.feltdata1='5' or bvg.feltdata1='6')
	left join varesalg..eaninfo e on e.eannr=bv.ean  
		and e.eanid=(select max(eanid) 
					from varesalg..eaninfo 
					where eannr=bv.ean)	
	where b.datotid>=@fradato 
		and b.datotid<@tildato
	group by 
		b.utsalgsstednr
		,bv.kreditkonto
		,bvg.feltdata1			

end
go