USE Varesalg
go

set ANSI_NULLS ON
GO
set QUOTED_IDENTIFIER ON
GO
if exists(select * from sys.procedures where  name = 'Kontering_varesalg')
	begin 
		drop procedure Kontering_varesalg 
	end;
go
-- =============================================
-- Author:		VR Konsulent
-- Create date: 	04/2013
-- Version:		17.2.6
-- Description:		Proseydre for kontering Varesalg.
-- NB: Lagt til negativ fortegn på "Personalrabatt" grunnet at logikk i kontering.exe trekker fra dette fra kreditbeloep. Men beløpet skal kreditseres.(02.02.2013)
-- =============================================
create procedure Kontering_varesalg (@fradato as datetime, @tildato as datetime)
as
begin
	set NOCOUNT ON;
	
	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
	--set @tildato = @fradato + 1

	begin --Region ulike Parametere
		declare @Bankkontonr int
		, @VaretyperIkkeVaresalg VARCHAR(100)
		, @VareegenskaperIkkeVaresalg VARCHAR(100);

		set @Bankkontonr = (select BANKKONTONR from super..systemoppsett);		
		select @VaretyperIkkeVaresalg = COALESCE(@VaretyperIkkeVaresalg + ','
										, '') 
										+ varetype
		from (
				select 
					distinct varetype 
				from super..konteringskonto 
				where ((flgegenregel=1) 
						or (flgprovisjonsregel=1 ))
					and varetype is not null) 
					as T;
		
		select @VareegenskaperIkkeVaresalg = COALESCE(@VareegenskaperIkkeVaresalg + ','
											, '') 
											+ vareegenskap
		from	(
				select 
					distinct vareegenskap 
				from super..konteringskonto 
				where ((flgegenregel=1) 
						or (flgprovisjonsregel=1)) 
					and vareegenskap is not null) 
					as T;
	
	end --Region slutt.

	select --Føringer på standard varesalg, uten provisjon
		b.utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, bv.KREDITKONTO as kreditkontonr
		,  sum(bv.OMSETNING) + ISNULL(sum(bvg.verdi1),0) as kreditbeloep -- trekker ikke fra mva på personalrabatten 
		, case
			when ko.flgoverstyrmvaprosent = 1 
				then ko.mvaprosent
			else bv.mvaprosent
		end as mvaprosent
		, case bv.KREDITKONTO  
			when 3000 
				then 'Salg ' + Cast (Cast(bv.mvaprosent as INTEGER) as VARCHAR(4)) + '%'			
			else ko.fritekst1
          end as fritekst1
		, ko.fritekst2 as fritekst2
		, ko.fritekst3 as fritekst3
	from varesalg..bong b 
    inner join varesalg..bongvare bv on (bv.bongid = b.bongid 
		-- skal ikke ha med pantovarer, denne kan tas bort når SUP-1826 er fikset og har vært i prod en stund (NB! fjerner vi denne er vi ikke bakoverkompatibel)
		and ( bv.ean <> 9820000000005 ))
    inner join varesalg..eaninfo e on (e.eannr = bv.ean 
		-- denne er i tilfelle det er flere rader med lik ean i eaninfo
		and e.eanid = (select Max(eanid) 
						from varesalg..eaninfo 
						where  eannr = bv.ean) 
		-- utelukker føringer som har feil kreditkontonr
		and (ISNULL(e.VARETYPE,0) not in (select * from FN_ListToTable(',',@VaretyperIkkeVaresalg)))
		and (ISNULL(e.VAREEGENSKAP,0) not in (select * from FN_ListToTable(',',@VareegenskaperIkkeVaresalg))))
    -- personalrabatt
	left join varesalg..bongvaregenfelt bvg ON (bv.bongid = bvg.bongid 
		and bv.ean = bvg.ean 
        and bvg.feltnr = 3601)
    -- konteringskontoer, for presatte fritekster
	inner join super..KONTERINGSKONTO ko on (ko.KONTONR=bv.KREDITKONTO 
		-- utelukker føringer som er provisjon eller egne regler			
		and (ko.flgprovisjonsregel=0) 
		and (ko.flgegenregel=0))
	where  b.datotid >= @fradato 
		and b.datotid < @tildato
	group  by 
		b.utsalgsstednr
		, bv.kreditkonto
		,ko.flgoverstyrmvaprosent
		,ko.mvaprosent
		, bv.mvaprosent
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3 
	order by bv.KREDITKONTO
			, bv.MVAPROSENT
	
	select ---Personal rabatt
		b.utsalgsstednr
		, null as avdelingsnr
		, ko.KONTONR AS debetkontonr
		--,Sum(cast(bvg.verdi1 - ( ( bvg.verdi1 / ( 1 + bv.mvaprosent * 0.01 ) ) * (0.01 * bv.mvaprosent ) ) as decimal(15,3))) AS debetbeloep
		, SUM(bvg.VERDI1) as debetbeloep -- trekker ikke fra mva på personalrabatten
		, null as kreditkontonr
		, null as kreditbeloep
		, case
			when ko.flgoverstyrmvaprosent = 1 
				then ko.mvaprosent
			else bv.mvaprosent
		end as mvaprosent
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3
	from   varesalg..bong b 
	inner join varesalg..bongvare bv on (bv.bongid = b.bongid)
	inner join varesalg..bongvaregenfelt bvg on (bv.bongid = bvg.bongid
		and bv.ean = bvg.ean 		
		and bv.KREDITKONTO != 3055 
		and bv.KREDITKONTO != 3705
		and bvg.feltnr = 3601) -- 3601 er kode for personalrabatt i genfelt-tabellene
	inner join super..konteringskonto ko on (ko.kontonr=5988)
	where  b.datotid >= @fradato 
		and b.datotid < @tildato 
	group  by
		b.utsalgsstednr
		, bv.mvaprosent
		, ko.KONTONR
		, ko.flgoverstyrmvaprosent
		, ko.mvaprosent
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3

	select  -- Egen regel for varesalg! Apotek + Salg my pack + Ruter ...
		b.UTSALGSSTEDNR
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, ko.KONTONR as kreditkontonr
		, sum(bv.OMSETNING) as kreditbeloep
		, case
			when ko.flgoverstyrmvaprosent = 1 
				then ko.mvaprosent
			else bv.mvaprosent
		end as mvaprosent
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3
	from varesalg..bong b 
    inner join varesalg..bongvare bv on (bv.bongid = b.bongid)
    inner join varesalg..eaninfo e on (e.eannr = bv.ean
		and e.eanid = (select Max(eanid) 
						from varesalg..eaninfo 
						where eannr = bv.ean) 		
		and e.VAREEGENSKAP in (select * from FN_ListToTable(',',@VareegenskaperIkkeVaresalg)))
	inner join super..KONTERINGSKONTO ko on (ko.KONTONR=e.KREDITKONTONR
		and (ko.flgprovisjonsregel=0) 
		and (ko.flgegenregel=1))
		and ko.vareegenskap = e.VAREEGENSKAP  
	where  b.datotid >= @fradato 
		and b.datotid < @tildato
	group by 
		b.UTSALGSSTEDNR
		, ko.KONTONR
		,ko.flgoverstyrmvaprosent
		,ko.mvaprosent
		, bv.mvaprosent
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3

end
go 