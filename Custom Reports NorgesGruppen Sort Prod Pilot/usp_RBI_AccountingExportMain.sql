USE [BI_Export]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_AccountingExportMain]    Script Date: 26.11.2020 11:37:51 ******/
DROP PROCEDURE [dbo].[usp_RBI_AccountingExportMain]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_AccountingExportMain]    Script Date: 26.11.2020 11:37:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************************************************************/
/*                                              CHANGELOG SECTION                                                             */
/******************************************************************************************************************************/
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 2017-02-14
-- Updated by: Algirdas Berneris
-- Description: Added translation tags  (RS-22678)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 26-MAY-2016
-- Updated by: vsw\geistgin
-- Description: Removed isCurrentStore from join condition due to be able recalculate historical data for stores wehe GLN or 
-- PublicOrgNumber has been changed (RS-26871)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 16-JUN-2016
-- Updated by: vsw\geistgin
-- Description: Sometimes new revision number was given even there were no differences between two accounting executions.
-- This happend because not right tables were comparingin in Accounting V2 code part. The table from Accounting V1 was used. 
-- Because this table is grouped differenly this issue rised. Now in a code the table [RBIE].Leg_AccountingSettlementLine 
-- was replaced to [CBIE].[RBI_AccountingExportDataInterface] (RS-27280)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 5-JUL-2016
-- Updated by: vsw\geistgin
-- Description: Verification included based on new configurations CA_ACCOUNTING_EXPORT_IS_ENABLED.
-- 1-Yes --> then executes calculations. 0-No --> calculations are skiped (RS-23859)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 25-OCT-2016
-- Updated by: vsw\geistgin
-- Description: (RS-29441)  UserNameID is null in dimension but destination table do not support null values so N/A(-1) value is
-- send instead of null.
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 07-NOV-2016
-- Updated by: vsw\geistgin
-- Description: (RS-27681) Only normal receipts included From Fact_receipttender source for @BONGBETMIDSUM calculation.
-- (Tender26 is included here)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 23-FEB-2017
-- Updated by: vsw\geistgin
-- Description: (RS-30270) Parameter @IgnoreNoArticleSalesPreCheckBeforeAccounting was added and IF condition updated to use it.
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 25-APR-2017
-- Updated by: vsw\geistgin
-- Description: (RS-28492) New column for Accounting export was added. AccountingId
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 28-APR-2017
-- Updated by: vsw\geistgin
-- Description: Removed parameter dependencies on Legacy tables (RS-32160)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 25-OCT-2017
-- Updated by: vsw\geistgin
-- Description: (RS-34874)  Implemented procedure which executes standard accounting V1 procedures if there not exist any customized
-- procedure in addition it runs all customized procedures included in usp_CBI_AccountingExportRulesEngineCustomizedV1  
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 08-NOV-2017
-- Updated by: vsw\eugenijus.rozumas
-- Description: (RS-35099) Replaced physical temp tables into actual temp tables. Changed some where clauses to use @DateIdx. 
-- Minor changes for performance improvement. 
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 19-DEC-2017
-- Updated by: vsw\eugenijus.rozumas
-- Description: (RS-26082) Added Interim rule for Accounting.
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 05-JAN-2018
-- Updated by: vsw\kristupas.vaitkus
-- Description: (RS-35982) Added cursors workaround to support columnstore indexes
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 27-FEB-2018
-- Updated by: vsw\eugenijus.rozumas
-- Description: (RS-36376) Rename from INTERIM to SUSPENSE. 
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 29-MAR-2018
-- Updated by: vsw\kristupas.vaitkus
-- Description: Fixed If clause {RS-37311}
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 27-JUL-2018
-- Updated by: vsw\eugenijus.rozumas
-- Description: If store was added to dimension later than it's first receipts changed @MaxStoreRelativeVersion to be taken from
--                the first record of that store (RS-38698)
-------------------------------------------------------------------------------------------------------------------------------	
-- Update date: 22-OCT-2018
-- Updated by: vsw\kristupas.vaitkus
-- Description:StoreName parameter to varchar(256) {RS-40067}
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 05-NOV-2018
-- Updated by: vsw\eugenijus.rozumas
-- Description: Replaced FLOOR with ReceiptHeadIdx ; Changed to CREATE OR ALTER PROCEDURE statement. (RS-39878)
-------------------------------------------------------------------------------------------------------------------------------	
-- Update date: 27-MAY-2019
-- Updated by: gintaras.geistoraitis
-- Description:  Added transaction isolation level READ UNCOMMITTED (RS-42933)
-------------------------------------------------------------------------------------------------------------------------------	
-- Update date: 14-JUN-2019
-- Updated by: gintaras.geistoraitis
-- Description: Global temp table functionality was implemented for Articles and Tenders entities (RS-42934)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 19-JUL-2019
-- Updated by: gintaras.geistoraitis
-- Description: (RS-41286) Functionality of Day-shift parameter was implemented for POS receipts in the Main procedure
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 07-OCT-2019
-- Updated by: gintaras.geistoraitis
-- Description: (RS-45103) nullable saleslocation numbers are excluded from RBIE.Leg_AccountingSettlementPerGeneratedField
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 18-NOV-2019
-- Updated by: eugenijus.rozumas
-- Description: (RS-31629) Commented out references to deprecated and removed objects
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 28-NOV-2019
-- Updated by: eugenijus.rozumas
-- Description: (RS-45872) Added reconciliation precheck
-------------------------------------------------------------------------------------------------------------------------------
-- Create date: 2019-12-18
-- Updated by: gintaras geistoraitis
-- Description: (RS-46206) - Procedure modified to suportfunctionality of delta between two revisions.
----------------------------------------------------------------------------------------------------------------------------------------
-- Create date: 2020-01-17
-- Updated by: eugenijus rozumas
-- Description: (RS-45872) - Added additional logic for reconciliation precheck regarding heartbeatupdated/heartbeatrequested
----------------------------------------------------------------------------------------------------------------------------------------
-- Create date: 2020-01-20
-- Updated by: eugenijus rozumas
-- Description: (RS-47021) - Removed RowIdx generation from the script as it is now an IDENTITY column.
----------------------------------------------------------------------------------------------------------------------------------------
-- Create date: 2020-01-23
-- Updated by: Gintaras Geistoraitis
-- Description: (RS-46020) - Usage of Fact_ReceiptRowForAccounting was replaced by usage of temptable instead of remaining queries
-- to avoid performance isues if days-hift functionality is not in use.
----------------------------------------------------------------------------------------------------------------------------------------
-- Create date: 2020-02-03
-- Updated by: Eugenijus Rozumas
-- Description: (RS-42990) - Commenting out V1 code as it is deprecated
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 27-FEB-2020
-- Updated by: eugenijus.rozumas
-- Description:  Adding support for TotalType = 6 (Store) moved Reconciliation pre-check to be done after we assign correct @ReconciliationTotalType
--				 for Store (RS-47563)
/******************************************************************************************************************************/
/*                                              MAIN SECTION                                                                  */
/* Keep main script up to date                                                                                                */
/******************************************************************************************************************************/ 

CREATE   PROCEDURE [dbo].[usp_RBI_AccountingExportMain]	
	  @date as date
	, @StoreId varchar (100)
	, @override as bit = 0
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	BEGIN TRY --Parametere + logging 
		DECLARE 
		  @LogMessage varchar(300)
		, @RuleVersion varchar(15)
		, @StoreName varchar(256)		--{RS-40067}
		, @BankAccountNumber varchar(25)
		, @FirstSaleDateTime datetime
		, @LastSaleDateTime datetime
		, @revision int
		, @legginnoppgjoer bit
		, @znr int
		, @virkid int
		, @Dognforskyvning int
		, @FromDate datetime
		, @ToDate datetime
		, @ReconciliationTotalType as int,  
         @AccountingPlanHierarchyType varchar(255),
         @AccountingPlanNumber int,
         @DateIdx as int,
         @StoreIdx as int,
         @MaxStoreRelativeVersion as int,
         @GLN as varchar(256),
         @Value_CA_ACCOUNTING_EXPORT_IS_ENABLED as int,
		 @IgnoreNoArticleSalesPreCheckBeforeAccounting as int = 0, --{RS-30270} Default is 1 that means if there were no sales then accounting for selected day is skipped. 
		 @DefaultReconciliationTypeForAccountingExport varchar(255),
		 @MaxSuspenseDifference as decimal(19,5) ,				--| {RS-26082} Values added for Accounting Suspense difference balance
		 @DebitAmount as decimal(19,5) ,						--|	
		 @CreditAmount as decimal(19,5)	,						--|
		 @DebitAccountNumber varchar(100) ,						--|
		 @CreditAccountNumber varchar(100) ,					--|
		 @SuspenseFreeText1 varchar(100) ,						--|
         @SuspenseFreeText2 varchar(100) ,						--|
		 @SuspenseFreeText3 varchar(100) ,						--|
		 @IsReconciliationPrecheckRequired as int = 0,
		 @HeartbeatVerificationForRegeneration AS INT,
		 @AccountingExportSetupVersion AS INT = 2

		 SET @MaxStoreRelativeVersion = (SELECT TOP 1 MAX(RelativeVersion) FROM [BI_Mart].[RBIM].[Dim_Store] WHERE StoreId=@StoreId AND  (@date BETWEEN CAST(ValidFromDate AS DATE) AND CAST(ValidToDate AS DATE)))

		 IF @MaxStoreRelativeVersion IS NULL        -- If store was loaded into dimension later than receipts: get the first record (RS-38698)
         BEGIN
            SET @MaxStoreRelativeVersion = (SELECT TOP 1 MIN(RelativeVersion) FROM [BI_Mart].[RBIM].[Dim_Store] WHERE StoreId=@StoreId)    
         END

         SET @StoreIdx = (SELECT TOP 1 StoreIdx FROM [BI_Mart].[RBIM].[Dim_Store] WHERE StoreId=@StoreId AND RelativeVersion=@MaxStoreRelativeVersion)
	   
	     SET @DefaultReconciliationTypeForAccountingExport = (SELECT TOP 1 Value FROM [RBIE].AccountingExportParameters WHERE ParameterName='DefaultReconciliationTypeForAccountingExport')

		 -- BEGIN Verificarion if accounting export is enabled for a given Store ----------------------------------------------------------------------------------------

	   	 SET @Value_CA_ACCOUNTING_EXPORT_IS_ENABLED = ( SELECT ISNULL(ei.[Value_CA_ACCOUNTING_EXPORT_IS_ENABLED],0) AS [Value_CA_ACCOUNTING_EXPORT_IS_ENABLED] 
														FROM   [BI_Mart].[RBIM].[Dim_Store] ds
																JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] ei on ds.StoreExtraInfoIdx=ei.StoreExtraInfoIdx 
														WHERE ds.StoreId=@StoreId AND ds.isCurrent=1
		 )

	     IF (ISNULL(@Value_CA_ACCOUNTING_EXPORT_IS_ENABLED,0) = 0)
			BEGIN

			 	SET @LogMessage=(SELECT replicate('-',150));
				EXEC[dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;

				SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Konteringseksport er sperret for butikk␣¤')+@StoreId+'.'+dbo.ufn_RBI_InsertResource('¤Alle kalkulasjoner var utelatt for denne butikken¤')); 
				EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				
				SET @LogMessage=(SELECT replicate('-',150));
				EXEC[dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				
				RETURN --Skip
			END 	
		-- END Verificarion if accounting export is enabled for a given Store ----------------------------------------------------------------------------------------

		 SET @GLN = (SELECT TOP 1 GloballocationNo FROM [BI_Mart].[RBIM].[Dim_Store] WHERE StoreIdx=@StoreIdx)		 
		 SET @DateIdx =  (SELECT YEAR(@date) * 10000 + MONTH(@date) * 100 + DAY(@date))
		 SET @AccountingPlanHierarchyType = (SELECT TOP 1 Value FROM [RBIE].AccountingExportParameters WHERE ParameterName='AccountingPlanHierarchyType')		 
		 SET @AccountingPlanNumber = (SELECT dbo.ufn_RBI_AccountingExportGetAccountingPlanNo(@StoreId,@AccountingPlanHierarchyType))
    
        SET @ReconciliationTotalType = 
		CASE
		(SELECT TOP 1 ISNULL(ei.[Value_CA_RECONCILIATIONTYPE_FOR_ACCOUNTING_EXPORT],'') AS [Value_CA_RECONCILIATIONTYPE_FOR_ACCOUNTING_EXPORT]
							    FROM   [BI_Mart].[RBIM].[Dim_Store] ds
							        JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] ei on ds.StoreExtraInfoIdx=ei.StoreExtraInfoIdx 
							    WHERE ds.StoreId=@StoreId AND ds.isCurrent=1)
		WHEN 'Pos' THEN 1
        WHEN 'Operator' THEN 2
		WHEN 'Till' THEN  4
		WHEN 'Store' THEN 6
		ELSE ''
		END
									
		IF 	@ReconciliationTotalType = '' 
		BEGIN 	
			SET @ReconciliationTotalType =
				CASE @DefaultReconciliationTypeForAccountingExport 
				WHEN 'Pos' THEN 1
				WHEN 'Operator' THEN 2
				WHEN 'Till' THEN  4
				WHEN 'Store' THEN 6
				END
		END	

-- BEGIN Reconciliation pre-check for a given Store ----------------------------------------------------------------------------------------
		 
		 SET @IsReconciliationPrecheckRequired = ISNULL((SELECT TOP 1 CASE WHEN ParameterValue IN ('1','True') THEN 1 ELSE 0 END FROM [BI_Kernel].[RBIK].[RSApplicationParameter] WHERE StoreId = @StoreId AND ParameterId = 'Accounting.ReconciliationPrecheck' AND ParameterValue IN ('1','True')),0)		
		
		 IF @IsReconciliationPrecheckRequired = 1
		 BEGIN
			IF EXISTS (SELECT TOP 1 * FROM [RBIE].[UnapprovedReconciliationsPerStore] WHERE StoreId = @StoreId AND CAST([FirstTransaction] AS Date) = @date AND TotalTypeId = @ReconciliationTotalType)
			BEGIN
				SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Fant ikke godkjent eller ikke behandlede oppgjør for butikk¤')+@StoreId+' '+CAST(@date AS VARCHAR(100))+'.'+dbo.ufn_RBI_InsertResource('¤Alle kalkulasjoner var utelatt for denne butikken¤')+'.'+dbo.ufn_RBI_InsertResource('¤Sjekk tabell RBIE.UnapprovedReconciliationsPerStore for mer informasjon om ventende oppgjør¤')); 
				EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;

				SET @HeartbeatVerificationForRegeneration = (SELECT TOP 1 Value FROM [RBIE].AccountingExportParameters WHERE ParameterName = 'UseHeartBeatVerificationBeforeAccounting');

				SET @HeartbeatVerificationForRegeneration = (SELECT CASE WHEN ISNULL(@HeartbeatVerificationForRegeneration,0) = 0 THEN 1 ELSE 0 END)

				IF NOT EXISTS (SELECT TOP 1 * FROM [RBIE].[AccountingExportSettlementsForRegeneration] WHERE IsRegenerated = 0 AND StoreId = @StoreId AND SettlementDate = @date)
				BEGIN
					INSERT INTO [RBIE].[AccountingExportSettlementsForRegeneration] (StoreId,SettlementDate,IsRegenerated,EtlLoadedDate,EtlChangedDate,Source,IsHeartBeatRequested,IsHeartBeatUpdated)
					VALUES (@StoreId, @date, 0, GETDATE(), GETDATE(),'Reconciliation pre-check',@HeartbeatVerificationForRegeneration,@HeartbeatVerificationForRegeneration)
				END

				RETURN --Skip
			END
		 END

--RS-45872 -- END Reconciliation pre-check for a given Store ----------------------------------------------------------------------------------------
------------------------ HeartBeat Verification -----------------------------------------------------------------------------------------------------------
        
		DECLARE @UseHeartBeatVerificationBeforeAccounting INT,
				@HeartBeatTransCount		INT = NULL,
				@DwhBiStageTransCount	INT = NULL,
				@DwhBiMartTransCount	INT = NULL,
				@DwhBiMartNormalTransCount INT = NULL, --Count of Normal receipts in BI_Mart
                @DwhBiExportTransCount	INT = NULL     --Count of receipts in BI_Export. Only Normal receipts are included.
	        
		SET @UseHeartBeatVerificationBeforeAccounting = (SELECT TOP 1 Value FROM RBIE.AccountingExportParameters WHERE ParameterName ='UseHeartBeatVerificationBeforeAccounting')
		
		IF ISNULL(@UseHeartBeatVerificationBeforeAccounting,0) = 1 /*If Heartbeat verification is enabled*/
		BEGIN
					SET @LogMessage=(SELECT replicate('-',150));
					 exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
					SET @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Heartbeat-verifikasjon er aktivert¤')); 
					 exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
	   				SET @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Heartbeat-verifikasjon for butikk: ¤')+@StoreId+ dbo.ufn_RBI_InsertResource('¤ og HB-regel "POSkvittering" er startet¤')); 
					  exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				
					SELECT	  @HeartBeatTransCount	 = [HeartBeatTransCount]
							, @DwhBiStageTransCount	 = [DwhBiStageTransCount]
							, @DwhBiMartTransCount	 = [DwhBiMartTransCount]
							, @DwhBiExportTransCount = [DwhBiExportTransCount]
					FROM [RBIE].[AccountingExportHeartBeatVerification]
					WHERE [StoreId]	= @StoreId  AND [Date] = @date 
						   AND [VerificationTypeId] = 'POSReceipts'

			IF ((ISNULL(@HeartBeatTransCount,-1) =  ISNULL(@DwhBiStageTransCount,-1)) AND (ISNULL(@HeartBeatTransCount,-1) = ISNULL(@DwhBiMartTransCount,-1))) --{RS-37311}
			BEGIN
				SET @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Heartbeat-verifikasjon for butikk: ¤')+@StoreId + dbo.ufn_RBI_InsertResource('¤ og HP-regel "POSkvittering" avsluttet vellykket.¤')); 
				exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				SET @LogMessage=(SELECT replicate('-',150));
			exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
			END
			ELSE
			BEGIN
				set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Ikke alle kvitteringer lastet inn i datavarehuset for butikk: ¤')+@StoreId); 
				exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Kontering for dato: ¤') + convert(varchar, @date , 104) + dbo.ufn_RBI_InsertResource('¤ og butikk: ¤')+@StoreId+dbo.ufn_RBI_InsertResource('¤ var utelatt¤')); 
				exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				SET @LogMessage=(SELECT replicate('-',150));
				exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				RETURN
			END	
		
		END     
--------------------------------------------------------------------------------------------------------------------------------------------------

--Begin Day Shift -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		DECLARE @PosReceiptsUseReconciliationPeriod BIT; -- Not supported in accounting until it will be a must, because it affects performace a lot, set 0 even parameter is set differentlly
		SET @PosReceiptsUseReconciliationPeriod = 0; -- = (SELECT [ParameterValue] FROM [BI_Kernel].[RBIK].[RSApplicationParameter] WHERE StoreId = @StoreId AND ParameterId = 'Accounting.PosReceiptsUseReconciliationPeriod');
		/*
		DECLARE @DateFilterReconciliation as nvarchar(4000)=' ';
        DECLARE @ReconciliationTotalType as int = 2; 
        DECLARE @SQLReconciliationsTempTable as nvarchar(4000)='';
		*/
		DECLARE @TimeIdx INT = 0;
			SET @TimeIdx = (
							SELECT TimeIdx FROM BI_Mart.RBIM.Dim_Time WITH (NOLOCK)
							WHERE  TimeDescription = ( 
													SELECT LEFT([ParameterValue],5) FROM [BI_Kernel].[RBIK].[RSApplicationParameter]
													WHERE StoreId = @StoreId AND ParameterId = 'Accounting.PosReceiptsEndOfDay'
													)
							);

			SET @TimeIdx = ISNULL(@TimeIdx,0); /*Set to Default 00:00:00*/

		DECLARE @ToDateIdx INT =  (SELECT CONVERT (INT, CONVERT (CHAR(8),(CONVERT(DATETIME,convert(CHAR(8),@DateIdx))+1),112)));
        DECLARE @DateFilterSimple as nvarchar(4000)=' ';
    
		IF @PosReceiptsUseReconciliationPeriod = 0 AND @TimeIdx = 0   -- Calendar date and End of Day is set at midnight (Default)
			SET @DateFilterSimple = ' AND F.ReceiptDateIdx = @DateIdx '
		ELSE IF @PosReceiptsUseReconciliationPeriod = 0 AND @TimeIdx != 0 -- Calendar date and End of Day is set after midnight (Day Shift parameter is used)
			SET @DateFilterSimple = ' AND ((F.ReceiptDateIdx = @DateIdx AND F.ReceiptTimeIdx > @TimeIdx) OR (F.ReceiptDateIdx = @ToDateIdx AND F.ReceiptTimeIdx <= @TimeIdx))'
																						
--End Day Shift -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		  SET @virkid = (SELECT ISNULL(ei.[Value_CA_ACCOUNTING_ACCOUNTINGID],'') AS [Value_CA_ACCOUNTING_ACCOUNTINGID]
					     FROM   [BI_Mart].[RBIM].[Dim_Store] ds
					      JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] ei on ds.StoreExtraInfoIdx=ei.StoreExtraInfoIdx 
					     WHERE ds.StoreId= @StoreId AND ds.isCurrent=1)
   
          SET @StoreName = (SELECT [StoreName] FROM [BI_Mart].[RBIM].[Dim_Store] ds WHERe ds.StoreIdx = @StoreIdx)  

          SET @BankAccountNumber = (SELECT ISNULL(ei.[Value_CA_ACCOUNTING_BANKACCOUNTTYPEID],'') AS [Value_CA_ACCOUNTING_BANKACCOUNTTYPEID]
							        FROM   [BI_Mart].[RBIM].[Dim_Store] ds
							         JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] ei on ds.StoreExtraInfoIdx=ei.StoreExtraInfoIdx 
							        WHERE ds.StoreId= @StoreId AND ds.isCurrent=1)		 
       
        SET @IgnoreNoArticleSalesPreCheckBeforeAccounting = (SELECT TOP 1 Value FROM RBIE.AccountingExportParameters WHERE ParameterName ='IgnoreNoArticleSalesPreCheckBeforeAccounting')
		IF @IgnoreNoArticleSalesPreCheckBeforeAccounting IS NULL SET @IgnoreNoArticleSalesPreCheckBeforeAccounting=0 --{RS-30270} Default is 0 that means if there were no sales then accounting for selected day is skipped. 		
		
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- GLOBAL TEMP TABLE IMPLEMENTATION BEGIN ------------------------------------------------------------------------------------------------------------------	
------------------------------------------------------------------------------------------------------------------------------------------------------------	
--- ##Fact_ReceiptRowForAccounting, is used in Engine: Articles --------------------------------------------------------------------------------------------

		DECLARE @SqlReceiptRowForAccountingTempTableDrop	NVARCHAR(max)
		DECLARE @SqlReceiptRowForAccountingTempTableCreate	NVARCHAR(max)
		DECLARE @ReceiptRowForAccountingTempTable VARCHAR(100) = '##Fact_ReceiptRowForAccounting'

		SET @ReceiptRowForAccountingTempTable = '##Fact_ReceiptRowForAccounting' + CONVERT(VARCHAR,@DateIdx) + CONVERT(VARCHAR,@StoreId)

		SET @SqlReceiptRowForAccountingTempTableDrop = 'IF OBJECT_ID(''tempdb..##Fact_ReceiptRowForAccounting'') IS NOT NULL DROP TABLE ##Fact_ReceiptRowForAccounting'

		SET @SqlReceiptRowForAccountingTempTableCreate = '
		SELECT F.*
			INTO ##Fact_ReceiptRowForAccounting
		FROM [BI_Mart].[RBIM].[Fact_ReceiptRowForAccounting] F WITH (NOLOCK) 
		WHERE F.StoreIdx in (SELECT StoreIdx FROM [BI_Mart].[RBIM].[Dim_Store] WHERE StoreId=''@StoreId'')  
		'
		SET @SqlReceiptRowForAccountingTempTableCreate = @SqlReceiptRowForAccountingTempTableCreate + @DateFilterSimple

		SET @SqlReceiptRowForAccountingTempTableCreate = @SqlReceiptRowForAccountingTempTableDrop + ' ' + @SqlReceiptRowForAccountingTempTableCreate
				
		SET @SqlReceiptRowForAccountingTempTableCreate = REPLACE(@SqlReceiptRowForAccountingTempTableCreate,'##Fact_ReceiptRowForAccounting',@ReceiptRowForAccountingTempTable)
		SET @SqlReceiptRowForAccountingTempTableCreate = REPLACE(@SqlReceiptRowForAccountingTempTableCreate,'@DateIdx',@DateIdx)
		SET @SqlReceiptRowForAccountingTempTableCreate = REPLACE(@SqlReceiptRowForAccountingTempTableCreate,'@StoreId',@StoreId)
		
		IF @PosReceiptsUseReconciliationPeriod = 0 AND @TimeIdx != 0
		BEGIN
			SET @SqlReceiptRowForAccountingTempTableCreate = REPLACE(@SqlReceiptRowForAccountingTempTableCreate,'@ToDateIdx',@ToDateIdx)
			SET @SqlReceiptRowForAccountingTempTableCreate = REPLACE(@SqlReceiptRowForAccountingTempTableCreate,'@TimeIdx',@TimeIdx)
		END

		-- PRINT @SqlReceiptRowForAccountingTempTableCreate

		EXEC sys.sp_executesql @SqlReceiptRowForAccountingTempTableCreate

--- ##Fact_RRFA_Tender, is used in Engine: Tenders --------------------------------------------------------------------------------------------------------

		DECLARE @SqlRRFATenderTempTableDrop		NVARCHAR(max)
		DECLARE @SqlRRFATenderTempTableCreate	NVARCHAR(max)
		DECLARE @RRFATenderTempTable VARCHAR(100) = '##Fact_RRFA_Tender'

		SET @RRFATenderTempTable = '##Fact_RRFA_Tender' + CONVERT(VARCHAR,@DateIdx) + CONVERT(VARCHAR,@StoreId)

		SET @SqlRRFATenderTempTableDrop = 'IF OBJECT_ID(''tempdb..##Fact_RRFA_Tender'') IS NOT NULL DROP TABLE ##Fact_RRFA_Tender'

		SET @SqlRRFATenderTempTableCreate = '
		SELECT DISTINCT F.ReceiptHeadIdx, F.ReceiptStatusIdx, F.TillId, F.SalesLocationNo 
			INTO ##Fact_RRFA_Tender
		FROM [BI_Mart].[RBIM].[Fact_ReceiptRowForAccounting] F WITH (NOLOCK)
			INNER JOIN [BI_Mart].[RBIM].[Dim_Store] dS on F.StoreIdx = dS.StoreIdx
		WHERE dS.StoreId= ''@StoreId''
		'
		
		SET @SqlRRFATenderTempTableCreate = @SqlRRFATenderTempTableCreate + @DateFilterSimple

		SET @SqlRRFATenderTempTableCreate =  @SqlRRFATenderTempTableDrop + ' ' + @SqlRRFATenderTempTableCreate
				
		SET @SqlRRFATenderTempTableCreate = REPLACE(@SqlRRFATenderTempTableCreate,'##Fact_RRFA_Tender',@RRFATenderTempTable)
		SET @SqlRRFATenderTempTableCreate = REPLACE(@SqlRRFATenderTempTableCreate,'@DateIdx',@DateIdx)
		SET @SqlRRFATenderTempTableCreate = REPLACE(@SqlRRFATenderTempTableCreate,'@StoreId',@StoreId)

		IF @PosReceiptsUseReconciliationPeriod = 0 AND @TimeIdx != 0
		BEGIN
			SET @SqlRRFATenderTempTableCreate = REPLACE(@SqlRRFATenderTempTableCreate,'@ToDateIdx',@ToDateIdx)
			SET @SqlRRFATenderTempTableCreate = REPLACE(@SqlRRFATenderTempTableCreate,'@TimeIdx',@TimeIdx)
		END
		-- PRINT @SqlRRFATenderTempTableCreate

		EXEC sys.sp_executesql @SqlRRFATenderTempTableCreate

--- ##Fact_ReceiptTender, is used in Engine: Tenders -------------------------------------------------------------------------------------------------------

		DECLARE @SqlFactReceiptTenderTempTableDrop		NVARCHAR(max)
		DECLARE @SqlFactReceiptTenderTempTableCreate	NVARCHAR(max)
		DECLARE @FactReceiptTenderTempTable	VARCHAR(100) = '##Fact_ReceiptTender'

		SET @FactReceiptTenderTempTable = @FactReceiptTenderTempTable + CONVERT(VARCHAR,@DateIdx) + CONVERT(VARCHAR,@StoreId)

		SET @SqlFactReceiptTenderTempTableDrop = 'IF OBJECT_ID(''tempdb..##Fact_ReceiptTender'') IS NOT NULL DROP TABLE ##Fact_ReceiptTender'

		SET @SqlFactReceiptTenderTempTableCreate = '
		SELECT F.*
			INTO ##Fact_ReceiptTender
		FROM [BI_Mart].[RBIM].[Fact_ReceiptTender] F WITH (NOLOCK)
			INNER JOIN [BI_Mart].[RBIM].[Dim_Store] dS  WITH (NOLOCK) ON F.StoreIdx = dS.StoreIdx
			INNER JOIN [BI_Mart].[RBIM].[Dim_ReceiptStatus] RCT ON RCT.ReceiptStatusIdx=F.ReceiptStatusIdx
		WHERE dS.StoreId = ''@StoreId'' AND RCT.ReceiptStatusId in (1,5) 
		 '
		--F.ReceiptDateIdx, F.ReceiptHeadIdx, F.[ReceiptTenderIdx],F.[StoreIdx],F.[TenderIdx],F.[CurrencyIdx],F.[SubTenderIdx],F.[Amount],F.[CustomerIdx],F.[CashierUserIdx]
		SET @SqlFactReceiptTenderTempTableCreate = @SqlFactReceiptTenderTempTableCreate + @DateFilterSimple
		SET @SqlFactReceiptTenderTempTableCreate = @SqlFactReceiptTenderTempTableDrop + ' ' +  @SqlFactReceiptTenderTempTableCreate

		SET @SqlFactReceiptTenderTempTableCreate = REPLACE(@SqlFactReceiptTenderTempTableCreate,'##Fact_ReceiptTender',@FactReceiptTenderTempTable)
		SET @SqlFactReceiptTenderTempTableCreate = REPLACE(@SqlFactReceiptTenderTempTableCreate,'@DateIdx',@DateIdx)
		SET @SqlFactReceiptTenderTempTableCreate = REPLACE(@SqlFactReceiptTenderTempTableCreate,'@StoreId',@StoreId)

		IF @PosReceiptsUseReconciliationPeriod = 0 AND @TimeIdx != 0
		BEGIN
			SET @SqlFactReceiptTenderTempTableCreate = REPLACE(@SqlFactReceiptTenderTempTableCreate,'@ToDateIdx',@ToDateIdx)
			SET @SqlFactReceiptTenderTempTableCreate = REPLACE(@SqlFactReceiptTenderTempTableCreate,'@TimeIdx',@TimeIdx)
		END

		-- PRINT @SqlFactReceiptTenderTempTableCreate

		EXEC sys.sp_executesql @SqlFactReceiptTenderTempTableCreate
	
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- GLOBAL TEMP TABLE IMPLEMENTATION END --------------------------------------------------------------------------------------------------------------------	
------------------------------------------------------------------------------------------------------------------------------------------------------------
---V2-------------------------------------------------------------------------------------------------------------------------------------------------------
		
		-- IF (@AccountingExportSetupVersion = 2)
		BEGIN TRY
			
			-- Gets first last sale from a global temp table {RS-46020}
			DECLARE @FirstSaleSql nvarchar(1000) = '', @LastSaleSql nvarchar(1000) = '';
            DECLARE @FirstParmDefinition nvarchar(500) = N'@FirstSaleDateTimeOUT datetime OUTPUT';
			DECLARE @LastParmDefinition  nvarchar(500) = N'@LastSaleDateTimeOUT datetime OUTPUT';
			
			SET @FirstSaleSql = @FirstSaleSql + N' SELECT @FirstSaleDateTimeOUT = (SELECT TOP 1 CAST(CAST( dd.FullDate AS VARCHAR(10)) +'' ''+ CAST( dt.TimeDescription AS VARCHAR(5)) AS DATETIME)
												   FROM '+@ReceiptRowForAccountingTempTable+' AS f WITH (NOLOCK)
												   LEFT JOIN [BI_MART].RBIM.Dim_Date AS dd ON f.ReceiptDateIdx = dd.DateIdx
												   LEFT JOIN [BI_MART].RBIM.Dim_Time AS dt ON f.ReceiptTimeIdx = dt.TimeIdx
												   WHERE  f.SalesAmount <> 0 	
												   ORDER BY f.ReceiptDateIdx asc, f.ReceiptTimeIdx asc
												   )';

			SET @LastSaleSql = @LastSaleSql + N' SELECT @LastSaleDateTimeOUT = (SELECT TOP 1 CAST(CAST( dd.FullDate AS VARCHAR(10)) +'' ''+ CAST( dt.TimeDescription AS VARCHAR(5)) AS DATETIME)
												   FROM '+@ReceiptRowForAccountingTempTable+' AS f WITH (NOLOCK)
												   LEFT JOIN [BI_MART].RBIM.Dim_Date AS dd ON f.ReceiptDateIdx = dd.DateIdx
												   LEFT JOIN [BI_MART].RBIM.Dim_Time AS dt ON f.ReceiptTimeIdx = dt.TimeIdx
												   ORDER BY f.ReceiptDateIdx desc, f.ReceiptTimeIdx desc
												   )';

            EXEC sp_executesql @FirstSaleSql, @FirstParmDefinition, @FirstSaleDateTimeOUT =  @FirstSaleDateTime OUTPUT;
			EXEC sp_executesql @LastSaleSql, @LastParmDefinition, @LastSaleDateTimeOUT = @LastSaleDateTime OUTPUT;
			
		END	TRY
		BEGIN CATCH
			SET @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Kontoføring feilet¤') +' '+ error_message());
			EXEC [dbo].usp_RBI_AccountingExportLog @Message =  @LogMessage, @StoreId=@StoreId;
		END CATCH 
		
----------------------------------------------------------------------------------------------------------------------------------------------------
		
		SET @LogMessage = (SELECT dbo.ufn_RBI_InsertResource('¤Kontering startet for¤')+ convert(varchar, @date , 104) +'.');
		EXEC [dbo].usp_RBI_AccountingExportLog @Message =  @LogMessage, @StoreId=@StoreId;
		SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Oppsettsversjon¤')+':'+ ' 2 '+ dbo.ufn_RBI_InsertResource('¤ og bankkontonummer: ¤') + isnull(@BankAccountNumber, 0) + '. ' + @StoreName+'.');
		EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
	END TRY
	BEGIN CATCH
		SET @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Kontering feilet på steg ¤') + error_message());
		EXEC [dbo].usp_RBI_AccountingExportLog @Message =  @LogMessage, @StoreId=@StoreId;
	END CATCH 

	IF (@IgnoreNoArticleSalesPreCheckBeforeAccounting=0)  
	BEGIN
		SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Hopp over "ingen-varer-solgt"-sjekk for bokføring er skrudd av:¤')); 
		EXEC[dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
	END 
	ELSE BEGIN
	SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Hopp over "ingen-varer-solgt"-sjekk for bokføring er skrudd på:¤')); 
		EXEC[dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
	END
    
	IF (@IgnoreNoArticleSalesPreCheckBeforeAccounting=0 AND @FirstSaleDateTime IS NULL) 
		begin 
			set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Ingen kvitteringer funnet for dato¤')+ convert(varchar, @date , 104) +'.')
			exec [dbo].usp_RBI_AccountingExportLog @Message =  @LogMessage, @StoreId=@StoreId; 
		end 
	ELSE IF ((@BankAccountNumber IS NULL) or (@BankAccountNumber = '')) 
		begin 
			set @LogMessage =(select dbo.ufn_RBI_InsertResource('¤Oppgjør: Feilet ettersom bankkontonummer mangler i ¤')+' Leg_StoreSetup');
			exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
		end	
	ELSE IF((@virkid IS NULL) or (@virkid = ''))	
		begin 
			set @LogMessage =(select dbo.ufn_RBI_InsertResource('¤Oppgjør feilet grunnet manglende ekstern butikk-id i ¤')+' Leg_StoreSetup');
			exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
		end            
	ELSE 
		BEGIN -- starts to count
---- BEGIN drop temp table of Accounting V2 with more output columns ---------------------------------------------------------------------------------------
	          if exists(select * from sys.tables where name = 'Temp_AccountingSettlementLine') -- Old physical table, replaced with temp table instead RS-35099
				begin try --sletter RBIE.Temp_Leg_AccountingSettlementLinedersom den finnes fra før.
					drop table RBIE.Temp_AccountingSettlementLine; 
				end try
				begin catch
				--	set @LogMessage =(select dbo.ufn_RBI_InsertResource('¤Telling: ¤')+ ERROR_MESSAGE());
				--	exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				end catch 
				
			  if  OBJECT_ID('tempdb..#Temp_AccountingSettlementLine') IS NOT NULL --Logikk for slette temp tabell dersom den finnes fra før.
				begin try --sletter #Temp_AccountingSettlementLinedersom den finnes fra før.
					drop table #Temp_AccountingSettlementLine; 
				end try
				begin catch
				--	set @LogMessage =(select dbo.ufn_RBI_InsertResource('¤Telling: ¤')+ ERROR_MESSAGE());
				--	exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				end catch               			
		
-- END drop temp table of Accounting V2 with more output columns -----------------------------------------------------------------------------------------
			BEGIN
---- BEGIN create temp table of Accounting V2 with more output columns --------------------------------------------------------------------------------------				   

				BEGIN TRY
					CREATE TABLE #Temp_AccountingSettlementLine  
					( 
						[RowIdx]                    [INT] IDENTITY(1,1) NOT NULL, 
						[SalesLocationNumber]       [INT] NULL, 
						[DepartmentNumber]          [INT] NULL, 
						[DebitAccountNumber]        [INT] NULL, 
						[DebitAmount]               [DECIMAL](19,5) NULL, 
						[CreditAccountNumber]       [INT] NULL, 
						[CreditAmount]              [DECIMAL](19,5) NULL, 
						[VatRate]                   [DECIMAL](19,5) NULL, 
						----------------------------------------------------

						/*
						[Quantity]                  [DECIMAL](19,5) NULL
						*/
						----------------------------------------------------
						[FreeText1]                 [VARCHAR](255) NULL, 
						[FreeText2]                 [VARCHAR](255) NULL, 
						[FreeText3]                 [VARCHAR](255) NULL, 
						----------------------------------------------------
						[ReconciliationZNR]			[INT] NOT NULL,  
		    			[VatClassId]				[DECIMAL](19,5) NULL, 
		    			[AccountingGroupId]         [VARCHAR](255) NOT NULL, 
		    			[CustomerIdx]               [INT] NOT NULL,   
						[SupplierIdx]               [INT] NOT NULL,   
						[TenderIdx]                 [INT] NOT NULL,    
						[SubTenderIdx]              [INT] NOT NULL,   
						[CashierIdx]                [INT] NOT NULL,    
						[CashRegisterIdx]           [INT] NOT NULL,     
						[CustomerWarrantyIdx]       [INT] NOT NULL,   
						[ReasonCodeIdx]             [INT] NOT NULL,
		    			[CurrencyIdx]               [SMALLINT] NOT NULL, 
		    			[BagId]						[VARCHAR](255) NULL, 
		    			[TillId]					[VARCHAR](255) NULL,   
		    			[OperatorId]				[INT] NULL,  
		    			[AccountingRuleNo]          [INT] NOT NULL, 
						[LinkedStoreIdx]            [INT] NULL
		    			) ;
				END TRY
				BEGIN CATCH
					SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Telling: ¤')+ERROR_MESSAGE());
					EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
				END CATCH
-- END drop temp table of Accounting V2 with more output columns -------------------------------------------------------------------------------------------

-- BEGIN EXEC Accounting Export v2 Rules -------------------------------------------------------------------------------------------------------------------
				
				BEGIN
					BEGIN TRY -- Accounting rules based on UI Setup 
				
					SET @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Prosedyre¤')+' [dbo].usp_RBI_AccountingExportDynamicRules '+dbo.ufn_RBI_InsertResource('¤ er startet ved å bruke Bokføringsoppsett versjonsnummer: ¤')+CAST(@AccountingExportSetupVersion as varchar (5)));
					EXEC[dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;		
					
		            INSERT INTO #Temp_AccountingSettlementLine
		    		EXEC [dbo].usp_RBI_AccountingExportDynamicRules @DateIdx=@DateIdx, @StoreId=@StoreId, @AccountingPlan=@AccountingPlanNumber ; 
		    		SET @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Prosedyre¤')+'[dbo].usp_RBI_AccountingExportDynamicRules : ' +  Cast(@@ROWCOUNT AS VARCHAR(5)) +' '+ dbo.ufn_RBI_InsertResource('¤Linjer for dato: ¤')+ CAST(@date as varchar(10)))
		 			EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
		            
					END TRY
					BEGIN CATCH
						SET @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Prosedyre feilet: ¤')+' [dbo].usp_RBI_AccountingExportDynamicRules. ' + ERROR_MESSAGE());
						EXEC[dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;		
					END CATCH

					-- BEGIN Check for Accounting Suspense Rule ---------------------------------------------------------------------------------------------
					BEGIN TRY 

						--we need to remove over 2 decimals before adding this suspense line NG-1840 Andre 20201126 kl 11:29
						UPDATE #Temp_AccountingSettlementLine 	SET DebitAmount = round(DebitAmount,2), CreditAmount = ROUND(CreditAmount,2);

						SELECT 
							  @DebitAmount = SUM(ISNULL(DebitAmount,0))
							, @CreditAmount = SUM(ISNULL(CreditAmount,0))
						FROM #Temp_AccountingSettlementLine

						SELECT  @MaxSuspenseDifference = CA_ACCOUNTING_SUSPENSE_MAX_AMOUNT,
								@DebitAccountNumber = CA_ACCOUNTING_SUSPENSE_DEBITACCOUNT ,
								@CreditAccountNumber = CA_ACCOUNTING_SUSPENSE_CREDITACCOUNT ,
								@SuspenseFreeText1 = CA_ACCOUNTING_SUSPENSE_FREETEXT1 ,
								@SuspenseFreeText2 = CA_ACCOUNTING_SUSPENSE_FREETEXT2 ,
								@SuspenseFreeText3 = CA_ACCOUNTING_SUSPENSE_FREETEXT3 
						FROM BI_Export.dbo.AccountingPlans as [Plan] (NOLOCK)
						WHERE AccountingPlanNo = @AccountingPlanNumber 

						SELECT  @MaxSuspenseDifference = COALESCE(CAST(NULLIF(ei.Value_CA_ACCOUNTING_SUSPENSE_MAX_AMOUNT,'') as DECIMAL (19,5)), @MaxSuspenseDifference),
								@DebitAccountNumber = COALESCE(NULLIF(ei.Value_CA_ACCOUNTING_SUSPENSE_DEBITACCOUNT,''), @DebitAccountNumber) ,
								@CreditAccountNumber = COALESCE(NULLIF(ei.Value_CA_ACCOUNTING_SUSPENSE_CREDITACCOUNT,''), @CreditAccountNumber) ,
								@SuspenseFreeText1 = COALESCE(NULLIF(ei.Value_CA_ACCOUNTING_SUSPENSE_FREETEXT1,''), @SuspenseFreeText1, '') ,
								@SuspenseFreeText2 = COALESCE(NULLIF(ei.Value_CA_ACCOUNTING_SUSPENSE_FREETEXT2,''), @SuspenseFreeText2, '') ,
								@SuspenseFreeText3 = COALESCE(NULLIF(ei.Value_CA_ACCOUNTING_SUSPENSE_FREETEXT3,''), @SuspenseFreeText3, '') 
						FROM BI_Mart.RBIM.Dim_Store as ds (NOLOCK)
						LEFT JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] ei on ds.StoreExtraInfoIdx=ei.StoreExtraInfoIdx 							
						WHERE ds.StoreId = @StoreId
						AND ds.IsCurrentStore = 1
					
						IF(@CreditAmount != @DebitAmount)	-- Check if Suspense Rule is applied {RS-26082}
						AND (ABS(@CreditAmount - @DebitAmount)<= @MaxSuspenseDifference)						
						BEGIN						 
							
							SET @LogMessage = (
							SELECT dbo.ufn_RBI_InsertResource('¤Prosedyre¤')
							+ ' [dbo].usp_RBI_AccountingExportRulesEngineAccountingSuspense '
							+ dbo.ufn_RBI_InsertResource('¤ er startet ved å bruke Bokføringsoppsett versjonsnummer: ¤')
							+ CAST(@AccountingExportSetupVersion AS VARCHAR (5)));

							EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;							
							
							INSERT INTO #Temp_AccountingSettlementLine
							EXEC [dbo].[usp_RBI_AccountingExportRulesEngineAccountingSuspense] 
							@DebitAmount=@DebitAmount, 
							@DebitAccountNumber = @DebitAccountNumber,
							@CreditAmount=@CreditAmount, 
							@CreditAccountNumber = @CreditAccountNumber,
							@StoreId=@StoreId,
							@SuspenseFreeText1 = @SuspenseFreeText1,
							@SuspenseFreeText2 = @SuspenseFreeText2,
							@SuspenseFreeText3 = @SuspenseFreeText3
							

						END	
							            
					END TRY

					BEGIN CATCH

						SET @LogMessage = (
						SELECT dbo.ufn_RBI_InsertResource('¤Prosedyre feilet: ¤')
						+ ' [dbo].usp_RBI_AccountingExportRulesEngineAccountingSuspense. ' 
						+ ERROR_MESSAGE());

						EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;	

					END CATCH

					-- END Check for Accounting Suspense Rule ------------------------------------------------------------------------------------------------
			    
			 
			END
			END
-- END EXEC Accounting Export v2 Rules ----------------------------------------------------------------------------------------------------------------------		
               
			set @znr = (select max(znr) from [RBIE].Leg_AccountingSettlement 
							where StoreId=@StoreId and SettlementDate=@date and DeletedDateTime is null);                              
			set @revision = 1;
			set @legginnoppgjoer = 0;
						
			if (@znr is not null)
			
				begin
				
					set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Disse oppgjørene eksisterer på følgende Znr: ¤')+cast(@znr as varchar));
					exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;	

					set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Sammenligner oppgjør (Debit og Kredit) med eksisterende oppgjør¤'));
					exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;					
					
					DECLARE @CheckCreditAmount AS INT;
					DECLARE @CheckDebitAmount  AS INT;
             
					SET @CheckCreditAmount = (SELECT count(*) as CreditAmount
											FROM (
												select isnull(CreditAmount, 0) as CreditAmount from #Temp_AccountingSettlementLine /*where StoreId=@StoreId*/  
												except												
												select isnull(CreditAmountLCY, 0) as CreditAmount from [CBIE].[RBI_AccountingExportDataInterface] where ZNR = @znr
												and StoreId=@StoreId) as T);                                                                                        
					 
					SET @CheckDebitAmount = (select count(*) as DebitAmount
											from (
												select isnull(DebitAmount, 0) as DebitAmount from #Temp_AccountingSettlementLine /*where StoreId=@StoreId*/     
												except											
												select isnull(DebitAmountLCY, 0) as DebitAmount from [CBIE].[RBI_AccountingExportDataInterface] where ZNR = @znr
												and StoreId=@StoreId) as T);
                    
					IF (((@CheckCreditAmount > 0) or (@CheckDebitAmount > 0)) or (@override = 1))
					begin 
											
						SET @revision = (	SELECT	isnull(Revision, 1) + 1 
											FROM [RBIE].Leg_AccountingSettlement 
											WHERE StoreId=@StoreId                                                                                                        
											      and SettlementDate=@date 
												  and DeletedDateTime is null)

						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Differanse funnet mellom eksisterende oppgjør og dette oppgjøret!¤'));
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
					
						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Forsøker å skrive eksisterende oppgjør til tabell "KonteringsOppgjørLinjeLogg"¤'));
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
						  
						begin try
							insert into [RBIE].Leg_AccountingSettlementLineLog
										(ZNR
										,StoreID                                                                                    
										,SalesLocationNumber 
										,DepartmentNumber   
										,DebitAccountNumber  
										,DebitAmount
										,CreditAccountNumber 
										,CreditAmount  
										,VatRate
										,Dimension1
										,Dimension2
										,Dimension3
										,SettlementDate 
										,Revision)
									select
										 ZNR
										,StoreId                                                                                    
										,SalesLocationNumber 
										,DepartmentNumber   
										,DebitAccountNumber  
										,DebitAmount
										,CreditAccountNumber 
										,CreditAmount  
										,VatRate
										,Dimension1
										,Dimension2
										,Dimension3
										,SettlementDate 
										,@revision-1                                                                                  
									from [RBIE].Leg_AccountingSettlementLine where StoreId=@StoreId and znr=@znr   
									
									-- Insert into accounting settlement header log table a header of previuos accounting revision important for delta functionality
									INSERT INTO [RBIE].[AccountingExportSettlementHeadLog]
										([StoreId]
										, [ZNR]
										, [StoreExternalId]
										, [SettlementDate]
										, [SettlementExecutionDateTime]
										, [FirstSaleDateTime]
										, [LastSaleDateTime]
										, [CreatedDateTime]
										, [ChangedDatetime]
										, [XmlExportedDateTime]
										, [ApprovedDatetime]
										, [DeletedDateTime]
										, [Revision]
										, [XmlExportType]
										, [LadStatus]
										, [EtlLoadedDate]
										)
									SELECT
										[StoreId]
										, [ZNR]
										, [StoreExternalId]
										, [SettlementDate]
										, [SettlementExecutionDateTime]
										, [FirstSaleDateTime]
										, [LastSaleDateTime]
										, [CreatedDateTime]
										, [ChangedDatetime]
										, [XmlExportedDateTime]
										, [ApprovedDatetime]
										, [DeletedDateTime]
										, [Revision]
										, [XmlExportType]
									  	, [LadStatus]  
										, GETDATE()
									FROM [RBIE].Leg_AccountingSettlement WHERE StoreId=@StoreId and znr=@znr
-- BEGIN Accounting Export V2 move data to Interface Log table --------------------------------------------------------------------------------------------------------------------						
							
							INSERT INTO CBIE.RBI_AccountingExportLogDataInterface(
											StoreIdx
										, StoreId
										, StoreExternalId  
										, AccountingId
										, PublicOrganizationNumber 
										, GlobalLocationNumber
										, LinkedStoreIdx --RS-28520
										, ZNR
										, SalesLocationNumber
										, DepartmentNumber
										, DebitAccountNumber
										, DebitAmountLCY
										, CreditAccountNumber
										, CreditAmountLCY
										, VatRate
										/*,Quantity*/
										, FreeText1
										, FreeText2
										, FreeText3
										, VatClassId
										, AccountingGroupId
										, CustomerIdx
										, CustomerId
										, SupplierIdx
										, SupplierId
										, TenderIdx
										, TenderId
										, SubTenderIdx
										, SubTenderId
										, CashierIdx
										, CashierId
										, CashRegisterNo
										, ReconciliationZNR
										, CustomerWarrantyIdx
										, CustomerWarrantyId
										, CustomerWarrantyGroupId
										, ReasonCodeIdx
										, ReasonNo
										, CurrencyIdx
										, CurrencyCode
										, BagId
										, TillId
										, OperatorId  
										, AccountingRuleNo
										, SettlementDate
										, EtlLoadedDate
										, RevisionNumber
										)	
							SELECT	  StoreIdx
									, StoreId
									, StoreExternalId  
									, AccountingId
									, PublicOrganizationNumber 
									, GlobalLocationNumber
									, LinkedStoreIdx
									, ZNR
									, SalesLocationNumber
									, DepartmentNumber
									, DebitAccountNumber
									, DebitAmountLCY
									, CreditAccountNumber
									, CreditAmountLCY
									, VatRate
									/*,Quantity*/
									, FreeText1
									, FreeText2
									, FreeText3
									, VatClassId
									, AccountingGroupId
									, CustomerIdx
									, CustomerId
									, SupplierIdx
									, SupplierId
									, TenderIdx
									, TenderId
									, SubTenderIdx
									, SubTenderId
									, CashierIdx
									, CashierId
									, CashRegisterNo
									, ReconciliationZNR
									, CustomerWarrantyIdx
									, CustomerWarrantyId
									, CustomerWarrantyGroupId
									, ReasonCodeIdx
									, ReasonNo
									, CurrencyIdx
									, CurrencyCode
									, BagId
									, TillId
									, OperatorId  
									, AccountingRuleNo
									, SettlementDate
									, GETDATE()
									, @revision-1
											
							FROM CBIE.RBI_AccountingExportDataInterface
							WHERE StoreId=@StoreId and znr=@znr
						
						end try
						begin catch
							set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Mislykket skriving til loggtabellen. Feilmelding: ¤') + ERROR_MESSAGE());
							exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;						
						end catch

-- END Accounting Export V2 move data to Interface Log table ----------------------------------------------------------------------------------------------------------------------							
	 
						BEGIN TRY 
							-- IMPORTANT!!! CASCADE DELETE ON LINES ARE INITIATED ON DELETE  
							DELETE FROM  [RBIE].Leg_AccountingSettlement WHERE StoreId=@StoreId and  znr = @znr;
							SET @legginnoppgjoer = 1
						END TRY
						BEGIN CATCH
							SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Mislykket sletting av gamle oppgjør¤') + ERROR_MESSAGE());
							EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
						END CATCH								
					end	
					else
					begin 
					 	set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Ingen endring i oppgjøret¤'));
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;						
					end 
				end	  
			else 
				begin 
					set @legginnoppgjoer = 1
					if not exists(select * from [RBIE].Leg_AccountingSettlement where StoreId=@StoreId) 
						begin
							set @znr = 1;
						end          
					else
						begin 
							set @znr = (select isnull(max(znr), 0) + 1 from [RBIE].Leg_AccountingSettlement Where StoreId=@StoreId);                                      
						end
				end
					
			if (@legginnoppgjoer = 1) 			
				begin 
					begin try 		
						
						insert into [RBIE].Leg_AccountingSettlement --Legger inn konteringsoppgjoer
									(StoreId                                                                                        
									,ZNR 
									, SettlementExecutionDateTime 
									, SettlementDate 
									, FirstSaleDateTime 
									, LastSaleDateTime 
									, StoreExternalId 
									, CreatedDateTime
									, ChangedDatetime 
									, XmlExportedDateTime 
									, ApprovedDateTime 
									, DeletedDateTime
									, LadStatus 
									, Revision)
						values  (    @StoreId                                                                                     
						            ,@ZNR
									, CURRENT_TIMESTAMP
									, @date
									, CASE @IgnoreNoArticleSalesPreCheckBeforeAccounting  WHEN 0  THEN @FirstSaleDateTime ELSE ISNULL(@FirstSaleDateTime,@date) END  --{RS-30270} if no article sales pre-check is off then if no sales found(NULL) First trnsaction date is set to SettlementDate  
									, CASE @IgnoreNoArticleSalesPreCheckBeforeAccounting  WHEN 0  THEN @LastSaleDateTime ELSE ISNULL(@LastSaleDateTime,@date) END    --{RS-30270} if no article sales pre-check is off then if no sales found(NULL) Last trnsaction date is set to SettlementDate  
								    , @virkid 
									, CURRENT_TIMESTAMP
									, CURRENT_TIMESTAMP
									, NULL
									, NULL
									, NULL
									, 0         
									, @revision );											
							
--- BEGIN Accounting Export V2 affected changes ---------------------------------------------------------------------------------------------------------------- 
						
							INSERT INTO  [RBIE].Leg_AccountingSettlementLine 
									( 
										StoreId                                                                                       
									, ZNR 
									, SalesLocationNumber
									, DepartmentNumber  
									, DebitAccountNumber 
									, DebitAmount 
									, CreditAccountNumber
									, CreditAmount 
									, VatRate 
									, Dimension1 
									, Dimension2 
									, Dimension3 
									, SettlementDate
									)
							SELECT	  @StoreId                                                                                
									, @znr
									, SalesLocationNumber
									, DepartmentNumber  
									, DebitAccountNumber 
									, SUM(DebitAmount) AS DebitAmount
									, CreditAccountNumber
									, SUM(CreditAmount) AS CreditAmount
									, VatRate 
									, FreeText1 
									, FreeText2 
									, FreeText3 
									, @date
							FROM #Temp_AccountingSettlementLine
							GROUP BY  SalesLocationNumber
									, DepartmentNumber  
									, DebitAccountNumber 
									, CreditAccountNumber
									, VatRate 
									, FreeText1 
									, FreeText2 
									, FreeText3
								
							INSERT INTO [CBIE].RBI_AccountingExportDataInterface 
									(  
										StoreIdx
										, StoreId
										, StoreExternalId  
										, AccountingId
										, PublicOrganizationNumber 
										, GlobalLocationNumber 
										, LinkedStoreIdx
										, ZNR
										, SalesLocationNumber
										, DepartmentNumber
										, DebitAccountNumber
										, DebitAmountLCY
										, CreditAccountNumber
										, CreditAmountLCY
										, VatRate
										/*,Quantity*/
										, FreeText1
										, FreeText2
										, FreeText3
										, VatClassId
										, AccountingGroupId
										, CustomerIdx
										, CustomerId
										, SupplierIdx
										, SupplierId
										, TenderIdx
										, TenderId
										, SubTenderIdx
										, SubTenderId
										, CashierIdx
										, CashierId
										, CashRegisterNo
										, ReconciliationZNR
										, CustomerWarrantyIdx
										, CustomerWarrantyId
										, CustomerWarrantyGroupId
										, ReasonCodeIdx
										, ReasonNo
										, CurrencyIdx
										, CurrencyCode
										, BagId
										, TillId
										, OperatorId  
										, AccountingRuleNo
										, SettlementDate 
										, EtlLoadedDate 
									)	
								  
							SELECT    @StoreIdx  
									, @StoreId                                                                                
									, S.StoreExternalId  
									, SEI.[Value_CA_ACCOUNTING_ACCOUNTINGID]
									, S.PublicOrganizationNumber 
									, S.GlobalLocationNo
									, TMP.LinkedStoreIdx
									, @znr		
									, TMP.SalesLocationNumber
									, TMP.DepartmentNumber  
									, TMP.DebitAccountNumber 
									, TMP.DebitAmount 
									, TMP.CreditAccountNumber
									, TMP.CreditAmount 
									, TMP.VatRate 
									/*,TMP.Quantity*/
									, TMP.FreeText1 
									, TMP.FreeText2 
									, TMP.FreeText3 
									, TMP.VatClassId
									, TMP.AccountingGroupId
									, TMP.CustomerIdx
									, CUS.CustomerId
									, TMP.SupplierIdx
									, SUP.SupplierId
									, TMP.TenderIdx
									, TEN.TenderId
									, TMP.SubTenderIdx
									, STE.SubTenderId
									, TMP.CashierIdx
									, ISNULL(USR.UserNameID,-1) /*RS-29441*/ 
									, TMP.CashRegisterIdx 
									, TMP.ReconciliationZNR
									, TMP.CustomerWarrantyIdx
									, CW.CustomerWarrantyId
									, CW.CustomerWarrantyGroupId
									, TMP.ReasonCodeIdx
									, RC.ReasonNo
									, TMP.CurrencyIdx
									, C.CurrencyCode
									, TMP.BagId
									, TMP.TillId
									, TMP.OperatorId  
									, TMP.AccountingRuleNo
									, @date
									, GETDATE()
							FROM #Temp_AccountingSettlementLine TMP     
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_Customer AS CUS ON  Tmp.CustomerIdx=CUS.CustomerIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_Supplier AS SUP ON  Tmp.SupplierIdx=SUP.SupplierIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_Tender AS TEN ON  Tmp.TenderIdx=TEN.TenderIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_SubTender AS STE ON  Tmp.SubTenderIdx=STE.SubTenderIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_User AS USR ON Tmp.CashierIdx=USR.UserIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_CustomerWarranty AS CW ON Tmp.CustomerWarrantyIdx=CW.CustomerWarrantyIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_ReasonCode AS RC ON Tmp.ReasonCodeIdx=RC.ReasonCodeIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_Currency AS C ON Tmp.CurrencyIdx=C.CurrencyIdx
									LEFT OUTER JOIN [BI_Mart].RBIM.Dim_Store S ON S.StoreIdx=@StoreIdx
									LEFT OUTER JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] SEI ON SEI.[StoreExtraInfoIdx]=S.[StoreExtraInfoIdx]
						  
--- END Accounting Export V2 affected changes ---------------------------------------------------------------------------------------------------------------- 					  
						  
					
						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Postert: ¤')+' [RBIE].Leg_AccountingSettlementLine '+ (select cast(count(*) as varchar(20)) from [RBIE].Leg_AccountingSettlementLine where StoreId=@StoreId and znr = @znr) + ' ' + dbo.ufn_RBI_InsertResource('¤linjer med Znr: ¤')+ Cast(@znr AS VARCHAR(20)));  
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Postert: ¤')+' [CBIE].RBI_AccountingExportDataInterface '+ (select cast(count(*) as varchar(20)) from [CBIE].RBI_AccountingExportDataInterface  where StoreId=@StoreId and znr = @znr) + ' ' + dbo.ufn_RBI_InsertResource('¤linjer med Znr: ¤')+ Cast(@znr AS VARCHAR(20)));  
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
					end try
					begin  catch
						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤') + error_message());
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;      
					end catch
							                          
					begin try 
											
						declare @SalesLocationNumber as int;
						declare @BONG_KASSENR as int;
						declare @BONG_KASSERERNR as int;
						declare @BONGBETMIDSUM as int;
						declare @BETMIDOPPGJOERSUM as int;
						
                        declare utsalgssteder cursor read_only fast_forward
							for
								select distinct [SalesLocationNumber]
								from #Temp_AccountingSettlementLine
								where [SalesLocationNumber] IS NOT NULL

                        -----------------------------------------------------------------------------------------------------------------------------------
                       open utsalgssteder
						fetch next from utsalgssteder into @SalesLocationNumber

						while (@@FETCH_STATUS = 0 )
							begin
								begin try
								    -- Moves to log table a previuos revision
									INSERT INTO [RBIE].AccountingExportSettlementPerGeneratedFieldLog
											(RowIdx
											,StoreId  
											,ZNR 
											,FieldNumber 										
											,FieldNumberValue1 
											,FieldNumberData1 
											,FieldNumberData2
											,Revision
											)
									SELECT
									  [RowIdx]
									, [StoreId]
									, [ZNR]
									, [FieldNumber]
									, [FieldNumberValue1]
									, [FieldNumberData1]
									, [FieldNumberData2]
									, @revision-1
									FROM [RBIE].[Leg_AccountingSettlementPerGeneratedField] 
									WHERE StoreId=@StoreId and FieldNumber=3100 and ZNR=@znr and FieldNumberData2=@revision-1

									DELETE FROM [RBIE].Leg_AccountingSettlementPerGeneratedField                                          
								    WHERE StoreId=@StoreId and FieldNumber=3100 and ZNR=@znr and FieldNumberData2=@revision-1             
								    

									insert into [RBIE].Leg_AccountingSettlementPerGeneratedField
											(   StoreId,                                                                                 
												FieldNumber ,
												ZNR ,
												FieldNumberValue1 ,
												FieldNumberData1 ,
												FieldNumberData2
											)
									values  (	@StoreId,  
												3100, -- FieldNumber - int 3100 til 31004
												@znr , -- ZNR - int
												cast(@SalesLocationNumber as decimal) , -- FieldNumberValue1 - decimal												
												@GLN, 
												@revision  -- FieldNumberData2 - varchar(50)
											)
								end try
								begin catch
									set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤') + error_message());
									exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId;                 
								end catch                                      
								fetch next from utsalgssteder into @SalesLocationNumber
							end 

						close utsalgssteder
						deallocate utsalgssteder

								
						DECLARE @kassenr_Sql varchar(500) = 'SELECT DISTINCT CashRegisterNo FROM '+@ReceiptRowForAccountingTempTable+' WITH (NOLOCK)'

						CREATE TABLE #kassenr (CashRegisterId INT NOT NULL)

						INSERT INTO #kassenr EXEC (@kassenr_Sql)

						DECLARE kassenr cursor read_only fast_forward
						FOR
						SELECT CashRegisterId FROM #kassenr				    			
							
						-----------------------------------------------------------------------------------------------------------------------------------
						open kassenr 
						fetch next from kassenr into @BONG_KASSENR

						while ( @@fetch_status = 0 )
							begin 
								begin try
								    -- Moves to log table a previuos revision
								    INSERT INTO [RBIE].AccountingExportSettlementPerGeneratedFieldLog
											(RowIdx
											,StoreId  
											,ZNR 
											,FieldNumber 										
											,FieldNumberValue1 
											,FieldNumberData1 
											,FieldNumberData2
											,Revision
											)
									SELECT
									  [RowIdx]
									, [StoreId]
									, [ZNR]
									, [FieldNumber]
									, [FieldNumberValue1]
									, [FieldNumberData1]
									, [FieldNumberData2]
									, @revision-1
									FROM [RBIE].[Leg_AccountingSettlementPerGeneratedField] 
									WHERE StoreId=@StoreId and FieldNumber=3101 and ZNR=@znr and FieldNumberData2=@revision-1

								    DELETE FROM [RBIE].Leg_AccountingSettlementPerGeneratedField                                          
								    WHERE StoreId=@StoreId and FieldNumber=3101 and ZNR=@znr and FieldNumberData2=@revision-1             

									insert into [RBIE].Leg_AccountingSettlementPerGeneratedField
											( 	StoreId,                                                                                   
												FieldNumber ,
												ZNR ,
												FieldNumberValue1 ,
												FieldNumberData1 ,
												FieldNumberData2
											)
									values  (	@StoreId,  
												3101, -- FieldNumber - int 3100 til 31004
												@znr , -- ZNR - int
												cast(@BONG_KASSENR as decimal) , -- FieldNumberValue1 - decimal
												cast(@BONG_KASSENR as varchar(5)) , -- FieldNumberData1 - varchar(50)
												@revision -- FieldNumberData2 - varchar(50)
											)
								end try
								begin catch
									set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤') + error_message());
									exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId;                 
								end catch
								fetch next from kassenr into @BONG_KASSENR                                      
							end
								
						close kassenr
						deallocate kassenr
								
						
													
						DECLARE @kasserernr_Sql varchar(500) = 'SELECT DISTINCT UserNameID FROM '+@ReceiptRowForAccountingTempTable+'  AS f  WITH (NOLOCK)
																LEFT JOIN [BI_MART].RBIM.Dim_User du ON f.CashierUserIdx = du.UserIdx'

						CREATE TABLE #kasserernr (CashierId varchar(255))
						INSERT INTO #kasserernr  EXEC  (@kasserernr_Sql)

						DECLARE kasserernr cursor read_only fast_forward   ------- {RS-35982}
						FOR
							SELECT CashierId FROM #kasserernr
						 
						-----------------------------------------------------------------------------------------------------------------------------------
                            
						open kasserernr
						fetch next from kasserernr into @BONG_KASSERERNR
								
						while ( @@FETCH_STATUS = 0 )
							begin
								begin try
								   -- Moves to log table a previuos revision
								   INSERT INTO [RBIE].AccountingExportSettlementPerGeneratedFieldLog
											(RowIdx
											,StoreId  
											,ZNR 
											,FieldNumber 										
											,FieldNumberValue1 
											,FieldNumberData1 
											,FieldNumberData2
											,Revision
											)
									SELECT
									  [RowIdx]
									, [StoreId]
									, [ZNR]
									, [FieldNumber]
									, [FieldNumberValue1]
									, [FieldNumberData1]
									, [FieldNumberData2]
									, @revision-1
									FROM [RBIE].[Leg_AccountingSettlementPerGeneratedField] 
									WHERE StoreId=@StoreId and FieldNumber=3102 and ZNR=@znr and FieldNumberData2=@revision-1


								    DELETE FROM [RBIE].Leg_AccountingSettlementPerGeneratedField                                          
								    WHERE StoreId=@StoreId and FieldNumber=3102 and ZNR=@znr and FieldNumberData2=@revision-1             

									insert into [RBIE].Leg_AccountingSettlementPerGeneratedField
											( 	StoreId,                                                                                  
												FieldNumber ,
												ZNR ,
												FieldNumberValue1 ,
												FieldNumberData1 ,
												FieldNumberData2
											)
									values  ( 
												@StoreId,                     
												3102, -- FieldNumber - int 3100 til 31004
												@znr , -- ZNR - int
												cast(@BONG_KASSERERNR as decimal) , -- FieldNumberValue1 - decimal
												cast(@BONG_KASSERERNR as varchar(5)) , -- FieldNumberData1 - varchar(50)
												@revision  -- FieldNumberData2 - varchar(50)
											)                                      
								end try
								begin catch
									set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤') +' '+ error_message());
									exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId;                                        
								end catch
								fetch next from kasserernr into @BONG_KASSERERNR                                      
							end
								
						close kasserernr
						deallocate kasserernr

						
						begin try
						
							DECLARE @BONGBETMIDSUM_Sql nvarchar(1000) = ''
							DECLARE @ParamDefinition5 nvarchar(500) = N'@BONGBETMIDSUM_OUT decimal(19,5) OUTPUT';
									
							SET @BONGBETMIDSUM_Sql = @BONGBETMIDSUM_Sql + N' SELECT @BONGBETMIDSUM_OUT = SUM(f.Amount) FROM '+@FactReceiptTenderTempTable+' AS f WITH (NOLOCK)';

							EXEC sp_executesql @BONGBETMIDSUM_Sql, @ParamDefinition5, @BONGBETMIDSUM_OUT = @BONGBETMIDSUM OUTPUT;
							  
                        -----------------------------------------------------------------------------------------------------------------------------------  
                          -- Moves to log table a previuos revision
						  INSERT INTO [RBIE].AccountingExportSettlementPerGeneratedFieldLog
											(RowIdx
											,StoreId  
											,ZNR 
											,FieldNumber 										
											,FieldNumberValue1 
											,FieldNumberData1 
											,FieldNumberData2
											,Revision
											)
									SELECT
									  [RowIdx]
									, [StoreId]
									, [ZNR]
									, [FieldNumber]
									, [FieldNumberValue1]
									, [FieldNumberData1]
									, [FieldNumberData2]
									, @revision-1
									FROM [RBIE].[Leg_AccountingSettlementPerGeneratedField] 
									WHERE StoreId=@StoreId and FieldNumber=3103 and ZNR=@znr and FieldNumberData2=@revision-1

                            DELETE FROM [RBIE].Leg_AccountingSettlementPerGeneratedField                                          
						    WHERE StoreId=@StoreId and FieldNumber=3103 and ZNR=@znr and FieldNumberData2=@revision-1             
						
							insert into [RBIE].Leg_AccountingSettlementPerGeneratedField
										( 
											StoreId,                                                                             
											FieldNumber ,
											ZNR ,
											FieldNumberValue1 ,
											FieldNumberData1 ,
											FieldNumberData2
										)
								values  ( 
											@StoreId,                                                                            
											3103, -- FieldNumber - int 3100 til 31004
											@znr , -- ZNR - int
											cast(@BONGBETMIDSUM as decimal) , -- FieldNumberValue1 - decimal
											cast(@BONGBETMIDSUM as varchar(50)) , -- FieldNumberData1 - varchar(50)
											@revision  -- FieldNumberData2 - varchar(50)
										)                              
						end try
						begin catch
							set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤')+' ' + error_message());
							exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;   
						end catch								
						
						begin try						  
					
							SET @BETMIDOPPGJOERSUM = (	
									SELECT SUM(Amount) 
									FROM  [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender AS A  WITH (NOLOCK)
									LEFT JOIN [BI_MART].RBIM.Dim_Store AS D
										ON A.StoreIdx = D.StoreIdx
									LEFT JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS B
										ON A.TotalTypeIdx = B.TotalTypeIdx 
									WHERE StoreId=@StoreId 
									AND A.ReconciliationDateIdx= @DateIdx 
									AND B.TotalTypeId = @ReconciliationTotalType    
														)
														
															
						  ---------------------------------------------------------------------------------------------------------------------------------									
                          -- Moves to log table a previuos revision  
							INSERT INTO [RBIE].AccountingExportSettlementPerGeneratedFieldLog
											(RowIdx
											,StoreId  
											,ZNR 
											,FieldNumber 										
											,FieldNumberValue1 
											,FieldNumberData1 
											,FieldNumberData2
											,Revision
											)
							SELECT
									  [RowIdx]
									, [StoreId]
									, [ZNR]
									, [FieldNumber]
									, [FieldNumberValue1]
									, [FieldNumberData1]
									, [FieldNumberData2]
									, @revision-1
							FROM [RBIE].[Leg_AccountingSettlementPerGeneratedField] 
							WHERE StoreId=@StoreId and FieldNumber=3104 and ZNR=@znr and FieldNumberData2=@revision-1


							DELETE FROM [RBIE].Leg_AccountingSettlementPerGeneratedField                                          
							WHERE StoreId=@StoreId and FieldNumber=3104 and ZNR=@znr and FieldNumberData2=@revision-1             
							
							insert into [RBIE].Leg_AccountingSettlementPerGeneratedField
										( 
											StoreId,                                                          
											FieldNumber ,
											ZNR ,
											FieldNumberValue1 ,
											FieldNumberData1 ,
											FieldNumberData2
										)
								values  ( 
											@StoreId,                                                        
											3104, -- FieldNumber - int 3100 til 31004
											@znr , -- ZNR - int
											cast(@BETMIDOPPGJOERSUM as decimal) , -- FieldNumberValue1 - decimal
											cast(@BETMIDOPPGJOERSUM as varchar(50)) , -- FieldNumberData1 - varchar(50)
											@revision  -- FieldNumberData2 - varchar(50)
										)                              
						end try
						begin catch
							set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤') + error_message());
							exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;   
						end catch                         
					end try
					begin catch
						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Kontering feilet¤') + error_message() + dbo.ufn_RBI_InsertResource('¤Mislykket skriving til tabell "KonteringsOppgjørGenFelt"¤'));
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
					end catch 						
			END
					
			exec [dbo].usp_RBI_AccountingExportApproval @znr = @znr, @StoreId=@StoreId;					
			set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Ferdig dato: ¤')+ ':' + convert(varchar, @date , 104) +' '+ dbo.ufn_RBI_InsertResource('¤ med Znr  ¤') + cast(@znr as varchar(20))); 
			exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;
			
		end 
	

-- Drop global temp tables after calculations are completed
	
	SET  @SqlReceiptRowForAccountingTempTableDrop = REPLACE( @SqlReceiptRowForAccountingTempTableDrop,'##Fact_ReceiptRowForAccounting',@ReceiptRowForAccountingTempTable)		
	SET  @SqlRRFATenderTempTableDrop = REPLACE( @SqlRRFATenderTempTableDrop,'##Fact_RRFA_Tender',@RRFATenderTempTable)
	SET  @SqlFactReceiptTenderTempTableDrop = REPLACE(@SqlFactReceiptTenderTempTableDrop ,'##Fact_ReceiptTender',@FactReceiptTenderTempTable)

   	EXEC sys.sp_executesql @SqlReceiptRowForAccountingTempTableDrop
	EXEC sys.sp_executesql @SqlRRFATenderTempTableDrop
	EXEC sys.sp_executesql @SqlFactReceiptTenderTempTableDrop
	
-- Drop global temp tables after calculations ar[d[dbo].[usp_RBI_AccountingExportRulesEngineCCInvoices]bo].[usp_RBI_AccountingExportRulesEngineCCReceipts]e completed

-- Accounting Delta Functionality 

   DECLARE @IsDeltaAccountingExportEnabled BIT = 0;
   SET @IsDeltaAccountingExportEnabled = (SELECT TOP 1 Value FROM [RBIE].AccountingExportParameters WHERE ParameterName='IsDeltaAccountingExportEnabled');
   
   IF (ISNULL(@IsDeltaAccountingExportEnabled,0) = 1) /*Before calculating delta it is verified if delta export of accounting is enabled */
   BEGIN TRY

    /*Gets type of export file which is assigned for the store: 0 - Default Xml file, 1-N - Some other custom formats*/
	DECLARE @ExportFileFormat INT = (SELECT ISNULL(ei.[Value_CA_ACCOUNTING_EXPORT_FILE_FORMAT],0) AS [Value_CA_ACCOUNTING_EXPORT_FILE_FORMAT] 
									 FROM [BI_Mart].[RBIM].[Dim_Store] ds
										LEFT JOIN [BI_Mart].[RBIM].[Out_StoreExtraInfo] ei on ds.StoreExtraInfoIdx=ei.StoreExtraInfoIdx 
									 WHERE ds.StoreId=@StoreId AND ds.isCurrent=1
									);  

    /*Gets the value of current revision only if current accounting revision was approved and not deleted.*/
	DECLARE @CurrRevision INT = (SELECT Revision FROM [RBIE].[Leg_AccountingSettlement]
								 WHERE StoreId = @StoreId AND SettlementDate = @date AND ApprovedDatetime IS NOT NULL AND DeletedDateTime IS NULL AND XmlExportedDateTime IS NULL); 
   
    /*Gets last exported revision. If it is a custom file export at least revision must be approve what means balance between Credit and Debit existed.*/
    DECLARE @PrevRevision INT = (SELECT MAX(Revision) FROM [RBIE].[AccountingExportSettlementHeadLog]
				       			 WHERE StoreId = @StoreId AND SettlementDate = @date AND ApprovedDatetime IS NOT NULL AND 
							           ((XmlExportedDateTime IS NOT NULL AND DeletedDateTime IS NULL AND @ExportFileFormat=0) OR @ExportFileFormat!=0)
								);
	/*Verifies if delta between revisions already exists to protect from wrong manual executions*/
	--DECLARE @IsDeltaExists INT = (SELECT COUNT (*) FROM [RBIE].[AccountingExportSettlementLineDelta] WHERE Revision = @CurrRevision AND PrevRevision = @PrevRevision);
	   
	IF (@CurrRevision IS NOT NULL AND @PrevRevision IS NOT NULL)
	BEGIN  
		EXEC dbo.usp_RBI_getAccountingExportDeltaBetweenRevisions
			 @StoreId = @StoreId 
			,@SettlementDate = @date
			,@ZNR = @znr 
			,@CurrRevision = @CurrRevision 
			,@PrevRevision = @PrevRevision 

    END
  END TRY
  BEGIN CATCH
	SET @LogMessage=(SELECT dbo.ufn_RBI_InsertResource('¤Kontering feilet¤')+' ' + error_message());
	EXEC [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId;   
  END CATCH

   select * from CBIE.RBI_AccountingExportDataInterface where StoreId=@StoreId and znr = @znr; --Viser konteringsoppgjøret	
end

GO

