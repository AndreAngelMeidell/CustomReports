
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
-- Author:			VR Konsulent
-- Create date: 	05 2020
-- Version:			17.2.7
-- Updated: 		14.04.2021 Andre Meidell
-- Description:		Flax i dagligvare aktivering
-- Changes:			14.04.2021 Parametere from DATE to DATETIME and flax in NG-2203
-- =============================================

CREATE PROCEDURE Kontering_FlaxAktivering
    (
      @fradato AS DATETIME ,
      @tildato AS DATETIME
    )
AS

    BEGIN
        SET NOCOUNT ON;
 
	--declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = '2021-04-16'
	--set @tildato = @fradato + 1

	BEGIN 	--Region Parametere + utsalgssted nr logikk
		DECLARE @utsalgsstednr INT ,
                @kreditkontonr INT;
		
		--Changed by Andre 20200812 from '=''' to 'like '%%''	

		SET @kreditkontonr = (	SELECT	CASE	WHEN KJEDE like '%MENY%'
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


	--Changed by Andre 20200812 '1594' to '1593' and 'RR.FLAXPAKKEFAKTURADATO' to 'replace(RR.FLAXPAKKEFAKTURADATO,'-','')'

	
	--Konteringsregel for aktivering av Flaxlodd bunter:
	
	--debetkontonr
	--D–1593 (Verdi inkl. provisjon på 7,5%, mva blank)
        SELECT -- SQL FlaxAktivering: Pakkeverdi ved aktivering		
                @utsalgsstednr AS utsalgsstednr ,
                NULL AS avdelingsnr ,
                1593 AS debetkontonr ,
                --( SELECT    ( RR.FLAXPAKKEVERDI * 0.925 * 100 ) / 100 ) AS debetbeloep ,--Endring 20210217 old
				RR.FLAXPAKKEVERDI AS debetbeloep, --Endring 20210217
                NULL AS kreditkontonr ,
                NULL AS kreditbeloep ,
                NULL AS mvaprosent , -- 20201118
                ( SELECT    RR.FLAXPAKKEID ) AS fritekst1 ,
                ( SELECT    replace(RR.FLAXPAKKEFAKTURADATO,'-','')  ) AS fritekst2 , 
				40 AS fritekst3
        FROM    Rapporter..FLAXSTATISTIKK RR
        WHERE   RR.DATO >= @fradato
                AND RR.DATO < @tildato
		AND RR.FLAXPAKKEVERDI IS NOT NULL

	--kreditkontonr 
	--K-541319 (Kiwi) 
	--K-554654 (Meny) 
	--K-569589 (KMH)
	--(Verdi av loddpakke eks. provisjon på 7,5% av salget, mva blank)

        SELECT -- SQL FlaxAktivering: Gjeld
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
		
	--Kreditkontonr
	--K-3700 provisjon 7,5% mva skal inneholde verdien 0 (integer) 20210414
		
		SELECT -- SQL FlaxAktivering: Provisjon
                @utsalgsstednr AS utsalgsstednr ,
                NULL AS avdelingsnr ,
                NULL AS debetkontonr ,
                NULL AS debetbeloep ,
                3700 as kreditkontonr ,
                SUM(RR.FLAXPAKKEVERDI) -  ROUND(CAST(SUM( RR.FLAXPAKKEVERDI * 0.925 * 100 ) / 100 as decimal(18,2)),1) AS kreditbeloep, --Changed 20200702 AM
                0 AS mvaprosent, --20210414
                'Flax, provisjon' as fritekst1,
                '' AS fritekst2,
				'40' AS fritekst3 
        FROM    Rapporter..FLAXSTATISTIKK RR
        WHERE   RR.DATO >= @fradato
                AND RR.DATO < @tildato
		--AND RR.FLAXPAKKEVERDI IS NOT NULL
		HAVING SUM(RR.FLAXPAKKEVERDI) -  ROUND(CAST(SUM( RR.FLAXPAKKEVERDI * 0.925 * 100 ) / 100 as decimal(18,2)),1)<>0
			
    END; --Slutt for FlaxAktivering SQLer 
 
GO