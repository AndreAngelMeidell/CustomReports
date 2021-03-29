USE Varesalg
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		VR Konsulent - Kristoffer Risa
-- Create date: 	04 2013
-- Version:		17.2.5
-- Description:		SQL prosedyre for utregning av 
--			øreavrunding pr. utsalgssted.
-- =============================================

if exists(SELECT * FROM   sys.procedures WHERE  name = 'Kontering_oreavrunding') --Sletter prosedyre hvis den finnes.
	begin 
		drop procedure Kontering_oreavrunding
	end;
go

create procedure Kontering_oreavrunding (@fradato as datetime, @tildato as datetime)
as 
begin
	set nocount on;
		
	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
	--set @tildato = @fradato + 1
		
	select 
		b.UTSALGSSTEDNR as utsalgsstednr
		, null as avdelingsnr
		, null as debetkontonr
		, null as debetbeloep
		, ko.kontonr as kreditkontonr
		, Sum(bb.beloep) 
		- (select 
				Sum(omsetning)            
			from bong b1           
				inner join bongvare bv1 on b1.bongid=bv1.bongid          
			where datotid >= @fradato 
				and datotid < @tildato
				and b1.utsalgsstednr = b.utsalgsstednr) 
		- (select 
				Sum(-utbetalt + innbetalt)           
			from bong b2           
			where datotid >= @fradato 
				and datotid < @tildato
				and b2.utsalgsstednr = b.utsalgsstednr) as kreditbeloep
		, ko.mvaprosent as mvaprosent
		, ko.fritekst1
		, ko.fritekst2
		, ko.fritekst3
	from varesalg..bong b  
	inner join varesalg..bongbetmid bb ON bb.bongid = b.bongid  
	inner join super..KONTERINGSKONTO ko on ko.KONTONR=7771	
	where b.datotid >= @fradato
		and b.datotid < @tildato
	group by
	  b.UTSALGSSTEDNR
	 , ko.kontonr
	 , ko.mvaprosent  	  
	  , ko.fritekst1
	  , ko.fritekst2
	  , ko.fritekst3 

end
GO
