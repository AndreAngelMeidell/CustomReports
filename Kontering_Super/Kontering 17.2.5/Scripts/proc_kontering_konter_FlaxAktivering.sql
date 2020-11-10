
USE Varesalg;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS ( SELECT  *
            FROM    sys.procedures
            WHERE   name = 'Kontering_FlaxAktivering' )
    BEGIN 
        DROP PROCEDURE Kontering_FlaxAktivering;
    END;
GO

-- =============================================
-- Author:		VR Konsulent
-- Create date: 	05 2020
-- Version:		17.2.5
-- Updated: 		12.08.2020 Andre Meidell
-- Description:		Flax i dagligvare aktivering
-- =============================================

CREATE PROCEDURE Kontering_FlaxAktivering
    (
      @fradato AS DATE ,
      @tildato AS DATE
    )
AS
    BEGIN
        SET NOCOUNT ON;
 
	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = '2020-05-16'
	--set @tildato = @fradato + 1

	BEGIN 	--Region Parametere + utsalgssted nr logikk
		DECLARE @utsalgsstednr INT ,
                @kreditkontonr INT;
		
		--Changed by Andre 20200812 from '=''' to 'like '%%''	

		SET @kreditkontonr = ( SELECT   CASE WHEN KJEDE like '%MENY%'
                                                  THEN '554654'
                                                WHEN KJEDE like '%KIWI%'
                                                  THEN '541319'
                                                ELSE '569589'
                                                  END AS 'kreditkontonr'
					FROM     Super..SYSTEMOPPSETT AS kjede);

            	SET @utsalgsstednr = ( 	SELECT   MAX(UTSALGSSTEDNR)
                                   	FROM     Super..UTSALGSSTED
                                   	WHERE    KORTNAVN = 'Supermarked');
		
            	IF ( @utsalgsstednr IS NULL )
                SET @utsalgsstednr = ( 	SELECT   MAX(UTSALGSSTEDNR)
                                       	FROM     Super..UTSALGSSTED
                                       	WHERE    PROFIL IS NOT NULL);
        END; --Region slutt


	-- Changed by Andre 20200812 '1594' to '1593' and 'RR.FLAXPAKKEFAKTURADATO' to 'replace(RR.FLAXPAKKEFAKTURADATO,'-','')'

	--debetkontonr 
        SELECT -- SQL FlaxAktivering: netto salg debet
                @utsalgsstednr AS utsalgsstednr ,
                NULL AS avdelingsnr ,
                1593 AS debetkontonr ,
                ( SELECT    ( RR.FLAXPAKKEVERDI * 0.925 * 100 ) / 100 ) AS debetbeloep ,
                NULL AS kreditkontonr ,
                NULL AS kreditbeloep ,
                0 AS mvaprosent ,
                ( SELECT    RR.FLAXPAKKEID ) AS fritekst1 ,
                ( SELECT    replace(RR.FLAXPAKKEFAKTURADATO,'-','')  ) AS fritekst2 , 
		40 AS fritekst3
        FROM    Rapporter..FLAXSTATISTIKK RR
        WHERE   RR.DATO >= @fradato
                AND RR.DATO < @tildato
		AND RR.FLAXPAKKEVERDI IS NOT NULL

	--kreditkontonr 
        SELECT -- SQL FlaxAktivering: netto salg og provisjon
                @utsalgsstednr AS utsalgsstednr ,
                NULL AS avdelingsnr ,
                NULL AS debetkontonr ,
                NULL AS debetbeloep ,
                @kreditkontonr AS kreditkontonr ,
                ( SELECT    ( RR.FLAXPAKKEVERDI * 0.925 * 100 ) / 100 ) AS kreditbeloep ,
                NULL AS mvaprosent ,
                ( SELECT    RR.FLAXPAKKEID  ) AS fritekst1 ,
                ( SELECT    replace(RR.FLAXPAKKEFAKTURADATO,'-','') ) AS fritekst2 ,
                40 AS fritekst3
        FROM    Rapporter..FLAXSTATISTIKK RR
        WHERE   RR.DATO >= @fradato
                AND RR.DATO < @tildato
		AND RR.FLAXPAKKEVERDI IS NOT NULL
			
    END; --Slutt for FlaxAktivering SQLer

GO