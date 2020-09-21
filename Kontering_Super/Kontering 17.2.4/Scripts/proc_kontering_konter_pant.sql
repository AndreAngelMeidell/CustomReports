USE Varesalg
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
if exists(select * from sys.procedures WHERE  name = 'Kontering_pant') 
	begin 
		drop procedure Kontering_pant
	end;
go

-- =============================================
-- Author:		VR Konsulent Kristoffer Risa
-- Create date: 04 2013
-- Version:		17.2.4 Andre Meidell
-- Description:	Prosedyre som henter Pant og Panto dataset for konteringsoppgjoer.
-- 20200901  Andre Meidell Changed due to duplicate if Panto data in VBDTransaction and StoreService
-- =============================================
create procedure Kontering_pant (@fradato as datetime, @tildato as datetime)
as
begin
	set nocount on;
 
	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
	--set @tildato = @fradato + 1

	begin --Region Parametere + utsalgssted nr logikk
		declare @avdelingsnrpantut int
		, @varegruppenrpantut int
		, @avdelingsnrpantinn int
		, @varegruppenrpantinn int
		, @utsalgsstednr int
		, @sjekk_pant int
		, @sjekk_pant1 INT;
		set @avdelingsnrpantut = (select verdi from super..PARAMETERE where NAVN='AVDUTPANT')
		set @varegruppenrpantut = (select verdi from super..PARAMETERE where NAVN='VGRUTPANT')
		set @avdelingsnrpantinn = (select verdi from super..PARAMETERE where NAVN='AVDINNPANT')
		set @varegruppenrpantinn = (select verdi from super..PARAMETERE where NAVN='VGRINNPANT')
		set @utsalgsstednr = (select max(utsalgsstednr) from super..UTSALGSSTED where KORTNAVN = 'Supermarked');
		
		if (@utsalgsstednr is null)	set @utsalgsstednr = (select max(utsalgsstednr) from super..UTSALGSSTED where PROFIL is not null);
	end --Region slutt
		
	select --§§ SQL for kjøp solgt
		b.utsalgsstednr
		, NULL as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, bv.kreditkonto as kreditkontonr
		, sum(bv.omsetning) as kreditbeloep
		, bv.mvaprosent
		, cast('Salg pant' as varchar(10)) as fritekst1
		, null as fritekst2
		, null as fritekst3
	from varesalg..bong b
	inner join varesalg..bongvare bv on bv.bongid=b.bongid
	inner join varesalg..eaninfo e on e.eannr=bv.ean
		and e.eanid=(select max(eanid) 
					from varesalg..eaninfo 
					where eannr=bv.ean)
	where b.datotid>=@fradato 
		and b.datotid<@tildato 
		and bv.kreditkonto=3055 
		and (((e.avdelingsnr=@avdelingsnrpantut) and (e.varegruppenr=@varegruppenrpantut)) 
			or ((bv.ean>=99950) and (bv.ean<=99997)))
	group by 
		b.utsalgsstednr	
		, bv.kreditkonto
		, bv.mvaprosent

	
	select --§§ SQL for kjøpt Pant
		b.utsalgsstednr
		, null as avdelingsnr
		, bv.kreditkonto as debetkontonr
		, (-1 * sum(bv.omsetning)) as debetbeloep
		, null as kreditkontonr
		, null as kreditbeloep
		, bv.mvaprosent
		, cast('Kjøp pant' as varchar(10)) as fritekst1
		, null as fritekst2
		, null as fritekst3
	from varesalg..bong b
	inner join varesalg..bongvare bv on bv.bongid=b.bongid
	left join varesalg..eaninfo e on e.eannr=bv.ean
		and e.eanid=(select max(eanid) 
					from varesalg..eaninfo 
					where eannr=bv.ean)
	where b.datotid>=@fradato 
		and b.datotid<@tildato 
		and bv.kreditkonto=3055 
		and (
			((e.avdelingsnr=@avdelingsnrpantinn) and (e.varegruppenr=@varegruppenrpantinn)) 
			or ((bv.ean=99910) 
				or ((bv.ean>=9800000000000) and (bv.ean<=9809999999999)) 
				or ((bv.ean>=98000000) and (bv.ean<=98099999)))
			)
	group by 
		b.utsalgsstednr			
		, bv.kreditkonto
		, bv.mvaprosent
	
	select -- SQL PANTO: utbetalt innløst
		b.utsalgsstednr
		, null as avdelingsnr
		, 2992 as debetkontonr
		, sum(-1 * bvg.verdi1) as debetbeloep
		, null as kreditkontonr
		, null as kreditbeloep
		, null as mvaprosent
		, 'Panto' as fritekst1
		, null as fritekst2
		, '7' as fritekst3
	from varesalg..bong b
		inner join varesalg..bongvaregenfelt bvg on bvg.bongid=b.bongid 
			and bvg.feltnr=3000 
  			and bvg.feltdata1='21'
	where b.datotid>=@fradato 
		and b.datotid<@tildato
	group by 
			b.utsalgsstednr

--Added for control of datasouce in use	
DECLARE @sjekk_pant_StoreService as INT
SET @sjekk_pant_StoreService = ISNULL((	SELECT SUM(RR.AMOUNT)
						from [StoreServices].[ReverseVending].[RVM_RECEIPTS] RR
						where RR.Panto_Lottery = 1 
						and RR.Rvm_CreatedTime >= @fradato 
						AND RR.Rvm_CreatedTime < @tildato
						),0)

DECLARE @sjekk_pant_vbdtransactions as INT
SET @sjekk_pant_vbdtransactions = ISNULL((	SELECT SUM(RR.AMOUNT)
						from vbdtransactions..Rvm_Receipts RR
						where RR.Panto_Lottery = 1 
						and RR.Rvm_CreatedTime >= @fradato 
						AND RR.Rvm_CreatedTime < @tildato
						),0)


--Kjører PANTO SQL dersom VBDTransaction har mer data en StoreService og ikke er tom
IF (@sjekk_pant_StoreService>=@sjekk_pant_vbdtransactions AND @sjekk_pant_StoreService IS NOT NULL) 
	begin
				
		declare @rounding bit = 1
		,@sum decimal(18 ,2)
		,@avrundingsum decimal(18,2); 		
		set @sum = (select 
						sum(RR.Amount)
					from [StoreServices].[ReverseVending].[RVM_RECEIPTS] RR  
					where  RR.panto_lottery = 1 
						and RR.rvm_createdtime >= @fradato 
						and RR.rvm_createdtime < @tildato);
		set @avrundingsum = (select 
								(Ceiling(Sum(RR.amount * 0.0975 * 100)) / 100) + (Floor(Sum(RR.amount * 0.9025 * 100)) / 100)
							from [StoreServices].[ReverseVending].[RVM_RECEIPTS] RR 
							where  RR.panto_lottery = 1 
								and RR.rvm_createdtime >= @fradato 
								and RR.rvm_createdtime < @tildato)

		if (@sum != @avrundingsum) 
		begin
			set @rounding = 0; --Stemmer ikke sum så foretar vi ikke avrundingsregler!
		end

		select -- SQL PANTO: netto salg debet
			@utsalgsstednr as utsalgsstednr
			, null as avdelingsnr
			, 3055 as debetkontonr
			, Sum(RR.Amount) as debetbeloep
			, null as kreditkontonr
			, null as kreditbeloep
			, 0 as mvaprosent
			, 'Panto' as fritekst1
			, null as fritekst2
			, '7' as fritekst3
		from [StoreServices].[ReverseVending].[RVM_RECEIPTS] RR
		where RR.Panto_Lottery = 1 
			and RR.Rvm_CreatedTime >= @fradato 
			and RR.Rvm_CreatedTime < @tildato

		select -- SQL PANTO: netto salg og provisjon
			@utsalgsstednr as utsalgsstednr
			, null as avdelingsnr
			, null as debetkontonr
			, null as debetbeloep
			, 2992 as kreditkontonr
			,case @rounding
			when 1 
				then Floor(Sum(RR.amount * 0.9025 * 100)) / 100 
			when 0
				then Sum(RR.amount * 0.9025 * 100) / 100 
			end as kreditbeloep
			, null as mvaprosent
			, 'Panto' as fritekst1
			, null as fritekst2
			, '7' as fritekst3 
		from   [StoreServices].[ReverseVending].[RVM_RECEIPTS] RR 
		where  RR.panto_lottery = 1 
			and RR.rvm_createdtime >= @fradato 
			and RR.rvm_createdtime < @tildato 
			
		union
			
		select 
			@utsalgsstednr as utsalgsstednr
			, null as avdelingsnr
			, null as debetkontonr
			, null as debetbeloep
			, 3708 as kreditkontonr
			, case @rounding
				when 1 
					then Ceiling(Sum(RR.amount * 0.0975 * 100)) / 100 
				when 0 
					then sum(RR.amount * 0.0975 *100) /100
			end as kreditbeloep
			, Cast(0 as double precision) as mvaprosent
			, 'Panto' as fritekst1
			, null as fritekst2
			, '7' as fritekst3 
		from   [StoreServices].[ReverseVending].[RVM_RECEIPTS] RR 
		where  RR.panto_lottery = 1 
			and RR.rvm_createdtime >= @fradato 
			and RR.rvm_createdtime < @tildato
end


--Kjører PANTO SQL dersom StoreService har mer data en VBDTransaction og ikke er tom
IF (@sjekk_pant_StoreService<@sjekk_pant_vbdtransactions AND @sjekk_pant_vbdtransactions IS NOT NULL) 
	begin 
				
		declare @rounding1 bit = 1
		,@sum1 decimal(18 ,2)
		,@avrundingsum1 decimal(18,2); 		
		set @sum = (select 
						sum(RR.Amount)
					from vbdtransactions..rvm_receipts RR  
					where  RR.panto_lottery = 1 
						and RR.rvm_createdtime >= @fradato 
						and RR.rvm_createdtime < @tildato);
		set @avrundingsum = (select 
								(Ceiling(Sum(RR.amount * 0.0975 * 100)) / 100) + (Floor(Sum(RR.amount * 0.9025 * 100)) / 100)
							from vbdtransactions..rvm_receipts RR 
							where  RR.panto_lottery = 1 
								and RR.rvm_createdtime >= @fradato 
								and RR.rvm_createdtime < @tildato)

		if (@sum != @avrundingsum) 
		begin
			set @rounding1 = 0; --Stemmer ikke sum så foretar vi ikke avrundingsregler!
		end

		select -- SQL PANTO: netto salg debet
			@utsalgsstednr as utsalgsstednr
			, null as avdelingsnr
			, 3055 as debetkontonr
			, Sum(RR.Amount) as debetbeloep
			, null as kreditkontonr
			, null as kreditbeloep
			, 0 as mvaprosent
			, 'Panto' as fritekst1
			, null as fritekst2
			, '7' as fritekst3
		from vbdtransactions..Rvm_Receipts RR
		where RR.Panto_Lottery = 1 
			and RR.Rvm_CreatedTime >= @fradato 
			and RR.Rvm_CreatedTime < @tildato

		select -- SQL PANTO: netto salg og provisjon
			@utsalgsstednr as utsalgsstednr
			, null as avdelingsnr
			, null as debetkontonr
			, null as debetbeloep
			, 2992 as kreditkontonr
			,case @rounding1
			when 1 
				then Floor(Sum(RR.amount * 0.9025 * 100)) / 100 
			when 0
				then Sum(RR.amount * 0.9025 * 100) / 100 
			end as kreditbeloep
			, null as mvaprosent
			, 'Panto' as fritekst1
			, null as fritekst2
			, '7' as fritekst3 
		from   vbdtransactions..rvm_receipts RR 
		where  RR.panto_lottery = 1 
			and RR.rvm_createdtime >= @fradato 
			and RR.rvm_createdtime < @tildato 
			
		union
			
		select 
			@utsalgsstednr as utsalgsstednr
			, null as avdelingsnr
			, null as debetkontonr
			, null as debetbeloep
			, 3708 as kreditkontonr
			, case @rounding1
				when 1 
					then Ceiling(Sum(RR.amount * 0.0975 * 100)) / 100 
				when 0 
					then sum(RR.amount * 0.0975 *100) /100
			end as kreditbeloep
			, Cast(0 as double precision) as mvaprosent
			, 'Panto' as fritekst1
			, null as fritekst2
			, '7' as fritekst3 
		from   vbdtransactions..rvm_receipts RR 
		where  RR.panto_lottery = 1 
			and RR.rvm_createdtime >= @fradato 
			and RR.rvm_createdtime < @tildato

	end --Slutt for PANTO SQLer
END

go