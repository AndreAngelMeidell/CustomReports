use varesalg
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


if exists(select * from sys.procedures where name = 'Kontering')
	begin 
		drop procedure Kontering;	
	end
go
-- =============================================
-- Author:		VR Konsulent Kristoffer Risa
-- Create date: 	2013
-- Version:		17.2.5
-- Description:		Hoved prosedyre for kontering.
--			Denne finner aller dager som det finnes tall for i BONG
--			og forsøker å kontere disse dagene. 
-- =============================================
create procedure Kontering 	
	@override as bit = 0  --Brukes ved sletting gammelt oppgjør eller ved re-sending\genering av XML
as
begin	
	set nocount on;	
	begin
		
		DECLARE @minDate DATE, @debug BIT;
		SET @minDate = (SELECT ISNULL(verdi,'1900-01-01') FROM super..parametere WHERE navn = 'KONTERINGMINDATO') -- Påkrevd fra 16.2.7 (dersom parametere ikke finnes deaktiveres re-generering funksjonaliteten. )		
		SET @debug = (SELECT CASE ISNULL(verdi,'F') WHEN 'F' THEN 0 ELSE 1 END FROM super..parametere WHERE navn = 'KONTERINGDEBUG')
		
		declare @day as date
		declare dager_cursor cursor read_only fast_forward for 
		SELECT
			distinct cast(datotid as date) 
		from varesalg..bong 
		where DATOTID <= dateadd(day,-1,getdate())  
		AND DATOTID > @minDate
		order by cast(DATOTID as date)

		open dager_cursor
		fetch next from dager_cursor into @day	
	
		while (@@fetch_status = 0 )
		BEGIN
        
			IF(@debug = 1) 
				PRINT 'Starter re-genering for dato: ' + CAST(@day AS VARCHAR(10))
			if (@override = 1) 
				exec varesalg.dbo.kontering_konter @dato = @day, @override = 1;
			else 
				exec varesalg.dbo.kontering_konter @dato = @day	
			
			fetch next from dager_cursor into @day
		end

        close dager_cursor
		deallocate dager_cursor

		-- Kjører ekstern prosedyre hvis det finnes. 
		DECLARE @prosedyre VARCHAR(MAX) = (SELECT TOP 1 VERDI FROM super..PARAMETERE WHERE navn ='KONTERINGEKSTERNPROSEDYRE')
		IF(@prosedyre != '')
		BEGIN 			
			DECLARE @sqlcmd AS NVARCHAR(MAX) 
			SET @sqlcmd = 'EXEC ' + @prosedyre     
			PRINT 'Executing sql: ' + @sqlcmd 
			EXECUTE sp_executesql  @sqlcmd; 
		END 
	end
end
go