use Varesalg
-- ================================================
set ansi_nulls on
go
set quoted_identifier on
go
if exists(select * from sys.procedures where name = 'Super_Logg')
	begin 
		drop procedure Super_Logg; 
	end;
go
-- =============================================
-- Author:		VR konsulent - Kristoffer Risa
-- Create date: 05/2013
-- Version:		17.2.4
-- Description:	Prosedyre for logge meldinger til Super sin logg tabell.
-- =============================================
create procedure Super_Logg	@Melding nvarchar(max), @debug bit = 1
as
begin
	if exists(select * from super..PARAMETERE where navn = 'KONTERINGDEBUG' and VERDI = 'T') or @debug = 1
	begin
		insert into super..logg 
		values     (1, --Nodenr
					Getdate(), --Datotid
					28, --Modulnr (Denne er hardkodet til "Kontering")
					@Melding, 
					0, --Brukernr
					1) --Loggtype
	end			
end
go
