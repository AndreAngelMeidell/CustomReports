USE [BI_Export]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_AccountExport_ToFile]    Script Date: 08.09.2020 08:42:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Martin Stangeby Lunde - Visma Retail AS>
-- CreatedDate: <13.04.2016>
-- SProc input-param:
--		@StoreId [Storeid or 0. 0 Means all stores. SQL to find all stores is implemeted bellow]
-- Global Parameters: 
--		@ExportFullLatestRevision [ (ExportMode) 1="Full, then delta" 0="Full on latest revision" ]
--		@DebugMode [ 0=Production, 1=Debug ]
--		@DestroyTempTables [ 1="Destroy all global temporary tables after usage" 0="Do not destroy" ]
--		@DestroyTempViews [ 1="Destroy all temporary views after usage" 0="Do not destroy" ]
-- Dependencies:
-- TODO: NB!NB!NB! DEBUGGING OF MORE THAN ONE STORE (DEPARTMENT) ON ONE SETTLEMENT DAY WILL RESULT IN AN ERROR.
--                 MUST CHANGE TEMP-TABLE-NAMES ON SETTLEMENT DAYS FROM (EXAMPLE) -->
--				   ##LastExportedFromDatabase'+@GuidWithoutHyphen' TO INCLUDE @StoreOnDateRunningNumber
--				   ##LastExportedFromDatabase'+@StoreOnDateRunningNumber+''+@GuidWithoutHyphen
-- =============================================

-- Changed 20190921 Andre
-- Changes 20200907 due to use of leg tables not in use anymore

CREATE PROCEDURE [dbo].[usp_CBI_AccountExport_ToFile] 
	@FromDate AS DATE ,
	@ToDate AS DATE,
	@StoreId AS VARCHAR(1000),
	@ExportFullLatestRevision AS BIT, 
	@ExportedBy AS VARCHAR(1000)	
AS
BEGIN
	
	DECLARE @NumberOfDaysBack INT = (SELECT TOP 1 Value FROM [CBIE].CBI_AccountingExportParameters  WHERE ParameterName = 'NumberOfDaysDelay') --4 days delay
	--DECLARE @FromDate AS DATE = GETDATE() - @NumberOfDaysBack;
	--DECLARE @ToDate AS DATE = GETDATE()
	--DECLARE @StoreId AS VARCHAR(1000) = 0
	--DECLARE @ExportFullLatestRevision AS BIT = 0
	--DECLARE @ExportedBy AS VARCHAR(1000) = 'sys'
	


	DECLARE @SQL NVARCHAR(4000)	
	DECLARE @FullExportSql NVARCHAR(4000)
	DECLARE @DeltaExportSql NVARCHAR(4000)
	DECLARE @Guid VARCHAR(200)
	DECLARE @GuidWithoutHyphen VARCHAR(200)			
	DECLARE @CMD VARCHAR(8000)
	DECLARE @ParamDefinition NVARCHAR(4000)
	DECLARE @StoreOnDateTotalCount INT
	DECLARE @StoreOnDateIndex INT
	DECLARE @StoreOnDateRunningNumber NVARCHAR(4000)
	DECLARE @StoreOnDateZNR NVARCHAR(4000)
	DECLARE @StoreOnDateCountTotalRevisions INT
	DECLARE @StoreOnDateCountTotalRevisionsFromDatabase INT
	DECLARE @StoreIdOnDateAndZNR VARCHAR(1000)
	DECLARE @Semikolon AS NVARCHAR(1) = ';'		
	DECLARE @SettlementDate DATE		
	DECLARE @SumTotalSettlementDays INT	
	DECLARE @CountSettlementDays INT		
	DECLARE @FullExportPath VARCHAR(1000)
	DECLARE @ExportFileName VARCHAR(1000)	
	DECLARE @BCPCommands VARCHAR(1000)
	DECLARE @ExportPath VARCHAR(1000)
	DECLARE @DebugMode BIT
	DECLARE @DestroyTempTables BIT
	DECLARE @DestroyTempViews BIT		
	DECLARE @DatabaseBCPCommand VARCHAR(1000)
	DECLARE @UserBCPCommand VARCHAR(1000)
	DECLARE @PasswordBCPCommand VARCHAR(1000)
	DECLARE @PrintExportFileContentToScreen BIT
	DECLARE @ExportResultContainer VARCHAR(MAX)
	
	-- CONFIG START	
	SET @DebugMode = 0
	SET @DestroyTempTables = 1
	SET @DestroyTempViews = 1	
	
	--SET @DatabaseBCPCommand = 'N13OS2SSQ127\A104610'
	--SET @DatabaseBCPCommand = 'N13OS2SSQ178T1\A104610'
	SET @DatabaseBCPCommand = 'N13OS2SSQ177\A104610'
	SET @UserBCPCommand = 'rsuser'
	SET @PasswordBCPCommand = '5aIqQz53'
	SET @BCPCommands = '-c -CACP -t -S'
	SET @ExportPath = '\\N13OS2SUT351\104610Data$\Ax\AX.Settle.V1\'
	--SET @ExportPath = '\\N13OS2SUT351\104610Data$\AX\Settle.test\' --for test
	--SET @ExportPath = 'C:\temp\AccDebug\'
	SET @ExportFileName = 'Accounting'
	SET @PrintExportFileContentToScreen = 1
	SET @Guid = NEWID()	
	SET @GuidWithoutHyphen = REPLACE(@Guid, '-', '')
	-- CONFIG END

	-- COMMON PROCEDURE TABLES START 	
		
	--Setting up temp-table on stores from input		
	SET @SQL = 
	'SELECT 
		distinct IDENTITY(INT,1,1) AS id, storeid 
		INTO ##StoresFromInput'+@GuidWithoutHyphen+'
		FROM BI_Mart.RBIM.Dim_Store 
		WHERE isCurrentStore=1'
		IF(@StoreId != 0)
		BEGIN
			SET @SQL = @SQL + ' AND StoreId = '''+@StoreId+''''
		END
		SET @SQL = @SQL + ' ORDER BY storeid ASC'
		
	EXEC sp_executesql @SQL
	
	--Setting up a temp-table on export result to file
	SET @SQL = 'CREATE TABLE ##ExportResult'+@GuidWithoutHyphen+'(output varchar(MAX) null)'
	EXEC sp_executesql @SQL			

	-- COMMON PROCEDURE TABLES END

	IF(@DebugMode = 1)
	BEGIN			
		PRINT '<Parameter>DebugMode is set to ' + CAST(@DebugMode AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>DestroyTempTables is set to ' + CAST(@DestroyTempTables AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>DestroyTempViews is set to ' + CAST(@DestroyTempViews AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>DatabaseBCPCommand is set to ' + CAST(@DatabaseBCPCommand AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>UserBCPCommand is set to ' + CAST(@UserBCPCommand AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>PasswordBCPCommand is set to ' + CAST(@PasswordBCPCommand AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>BCPCommands is set to ' + CAST(@BCPCommands AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>ExportPath is set to ' + CAST(@ExportPath AS VARCHAR(100)) + '<Parameter>'
		PRINT '<Parameter>CommonExportFileName is set to ' + CAST(@ExportFileName AS VARCHAR(100)) + '<Parameter>'		
		PRINT '<Parameter>PrintExportResultToScreen is set to ' + CAST(@PrintExportFileContentToScreen AS VARCHAR(100)) + '<Parameter>'				
		PRINT '<Parameter>GUID is set to ' + @GuidWithoutHyphen + '<Parameter>'
	END

	IF(@FromDate = @ToDate)
	BEGIN
		SET @SettlementDate = @FromDate
		SET @SumTotalSettlementDays = 0 --Start with zero index
		SET @CountSettlementDays = 0
		IF(@DebugMode = 1)
		BEGIN			
			PRINT '<INFO>Run accounting on date ' + CAST(@FromDate AS VARCHAR(1000)) + '<INFO>'
		END
	END
	ELSE
	BEGIN
		SET @SumTotalSettlementDays = DATEDIFF(DAY, @FromDate, @ToDate) 		
		SET @CountSettlementDays = 0
		
		IF(@DebugMode = 1)
		BEGIN			
			PRINT '<INFO>Run accounting from date ' + CAST(@FromDate AS VARCHAR(1000)) + ' to date ' + CAST(@ToDate AS VARCHAR(1000)) + '<INFO>'
			PRINT '<INFO>Total count of accounting days is ' + CAST(@SumTotalSettlementDays+1 AS VARCHAR(100)) + '<INFO>'
		END
	END

	IF(@DebugMode = 1)
	BEGIN
		IF(@StoreId = 0)		
			PRINT '<INFO>Run accounting on every store<INFO>'		
		ELSE
			PRINT '<INFO>Run accounting on store ' + CAST(@StoreId AS VARCHAR(1000)) + '<INFO>'
	END

	--Begin loop of days between @FromDate - @ToDate
	WHILE @SumTotalSettlementDays >= @CountSettlementDays 
	BEGIN
		
		IF(@DebugMode = 1 AND @SumTotalSettlementDays > 1)
		BEGIN			
			PRINT '<INFO>Now run accounting on date ' + CAST(DATEADD(day,@CountSettlementDays,@FromDate) AS VARCHAR(1000)) + '<INFO>'
		END		 
		
		SET @SettlementDate = DATEADD(day,@CountSettlementDays,@FromDate)		

		--Join RBI_AccountingExportDataInterface together with RBI_AccountingExportLogDataInterface (master + log) to fake revision on master table by adding a colomn. Master table do not have revision. Logic bellow asume it exist
		EXEC [dbo].usp_CBI_AccountingExportLogDataInterface @SettlementDate, @GuidWithoutHyphen

		SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''INFO'',''Start running procedure BI_Export.usp_CBI_AccountingExport on date '+CONVERT(VARCHAR(8), @SettlementDate, 112)+''', '''+@Guid+''','''+@StoreId+''',GETDATE(),'''+@ExportedBy+''')'        
		EXEC sp_executesql @SQL
										
		SET @SQL = '
		SELECT 		
			IDENTITY(INT,1,1) as id,
			CAST(aeldi.StoreId AS VARCHAR(1000)) + CAST(aeldi.ZNR AS VARCHAR(1000)) + CAST(aeldiCount.RevisionNumber AS VARCHAR(1000)) AS RunningNumber,
			aeldiCount.RevisionNumber as MaxRevision,
			aeldi.ZNR,
			aeldi.StoreId
		INTO 
			##StoreOnDateWithId'+@GuidWithoutHyphen+'
		FROM
			[BI_Export].CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen+' AS aeldi		
			INNER JOIN  
				(SELECT
					aeldiInner.StoreId,
					aeldiInner.ZNR,
					MAX(aeldiInner.RevisionNumber)+1 AS RevisionNumber
					FROM 
					[BI_Export].CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen+' AS aeldiInner
				WHERE 
					SettlementDate = '''+LEFT(CONVERT(VARCHAR, @SettlementDate, 120), 10)+' 00:00:00''
					AND StoreId in (SELECT StoreId from ##StoresFromInput'+@GuidWithoutHyphen+')
				GROUP BY
					aeldiInner.StoreId,
					aeldiInner.ZNR) 
			AS aeldiCount ON aeldiCount.StoreId = aeldi.StoreId AND aeldiCount.ZNR = aeldi.ZNR AND aeldiCount.RevisionNumber = aeldi.RevisionNumber+1
		WHERE
			aeldi.SettlementDate = '''+LEFT(CONVERT(VARCHAR, @SettlementDate, 120), 10)+' 00:00:00''
			AND aeldi.StoreId in (SELECT StoreId from ##StoresFromInput'+@GuidWithoutHyphen+')		
		GROUP BY 
			CAST(aeldi.StoreId AS VARCHAR(1000)) + CAST(aeldi.ZNR AS VARCHAR(1000)) + CAST(aeldiCount.RevisionNumber AS VARCHAR(1000)),
			aeldiCount.RevisionNumber,
			aeldi.ZNR,
			aeldi.StoreId'		
		EXEC sp_executesql @SQL

		IF(@DebugMode = 1)
		BEGIN
			PRINT '<INFO>get info on all stores with revision<INFO>'
			PRINT '<SQL>'+@SQL+'<SQL>'
		END	

		--Find total count of all the ZNR's on this spesific date
		SET @ParamDefinition = N'@CountZnrOnDateWithIdOUT NVARCHAR(MAX) OUTPUT'		
		SET @SQL = 'SELECT @CountZnrOnDateWithIdOUT = COUNT(*) FROM ##StoreOnDateWithId'+@GuidWithoutHyphen		
		EXEC sp_executesql @SQL,@ParamDefinition,@CountZnrOnDateWithIdOUT = @StoreOnDateTotalCount OUTPUT

		IF(@DebugMode = 1)
		BEGIN			
			PRINT '<INFO>Beginning looping @StoreOnDateTotalCount... One loop on each StoreId<INFO>'
			PRINT '<Parameter>StoreOnDateTotalCount=' + CAST(@StoreOnDateTotalCount AS VARCHAR(100)) + '<Parameter>'
		END			
				
		SET @StoreOnDateIndex = 1			
		WHILE @StoreOnDateIndex <= @StoreOnDateTotalCount
		BEGIN		
	
			IF(@DebugMode = 1)
			BEGIN							
				PRINT '<Parameter>StoreOnDateIndex = ' + CAST(@StoreOnDateIndex AS VARCHAR(100)) + '<Parameter>'
				PRINT '<Parameter>StoreOnDateTotalCount = ' + CAST(@StoreOnDateTotalCount AS VARCHAR(100)) + '<Parameter>'				
			END
			
			--Get RunningNumber on this row and id
			SET @ParamDefinition = N'@RunningNumberOUT NVARCHAR(MAX) OUTPUT'	  
			SET @SQL = 'SELECT @RunningNumberOUT = RunningNumber FROM ##StoreOnDateWithId'+@GuidWithoutHyphen+' WHERE id = '+CONVERT(NVARCHAR(MAX),@StoreOnDateIndex)	
			EXEC sp_executesql 	@SQL,@ParamDefinition,@RunningNumberOUT = @StoreOnDateRunningNumber OUTPUT
			
			IF(@DebugMode = 1)
			BEGIN
				PRINT '<INFO>Get RunningNumber on this row and id<INFO>'			
				PRINT '<Parameter>ZnrOnDateRunningNumber=' + CAST(@StoreOnDateRunningNumber AS VARCHAR(100)) + '<Parameter>'
			END	

			--Get ZNR on this row and id
			SET @ParamDefinition = N'@ZNROUT NVARCHAR(MAX) OUTPUT'	  
			SET @SQL = 'SELECT @ZNROUT = ZNR FROM ##StoreOnDateWithId'+@GuidWithoutHyphen+' WHERE id = '+CONVERT(NVARCHAR(MAX),@StoreOnDateIndex)				
			EXEC sp_executesql 	@SQL,@ParamDefinition,@ZNROUT = @StoreOnDateZNR OUTPUT			

			IF(@DebugMode = 1)
			BEGIN				
				PRINT '<Parameter>ZnrOnDateZNR=' + CAST(@StoreOnDateZNR AS VARCHAR(100)) + '<Parameter>'
			END				

			--Get StoreId on this row and id
			SET @ParamDefinition = N'@STOREIDOUT NVARCHAR(MAX) OUTPUT'	  
			SET @SQL = 'SELECT @STOREIDOUT = StoreId FROM ##StoreOnDateWithId'+@GuidWithoutHyphen+' WHERE id = '+CONVERT(NVARCHAR(MAX),@StoreOnDateIndex)				
			EXEC sp_executesql 	@SQL,@ParamDefinition,@STOREIDOUT = @StoreIdOnDateAndZNR OUTPUT				

			IF(@DebugMode = 1)
			BEGIN				
				PRINT '<Parameter>StoreIdOnDateAndZNR=' + CAST(@StoreIdOnDateAndZNR AS VARCHAR(100)) + '<Parameter>'
			END				

			--Get MaxRevision on this row and id
			SET @ParamDefinition = N'@CountTotalRevisionsOUT INT OUTPUT'	  
			SET @SQL = 'SELECT @CountTotalRevisionsOUT = MaxRevision FROM ##StoreOnDateWithId'+@GuidWithoutHyphen+' WHERE id = '+CONVERT(NVARCHAR(MAX),@StoreOnDateIndex)							
			EXEC sp_executesql 	@SQL,@ParamDefinition,@CountTotalRevisionsOUT = @StoreOnDateCountTotalRevisions OUTPUT	

			IF(@DebugMode = 1)
			BEGIN
				PRINT '<INFO>MaxRevision on this StoreId and SettlementDate<INFO>'				
				PRINT '<Parameter>ZnrOnDateCountTotalRevisions=' + CAST(@StoreOnDateCountTotalRevisions AS VARCHAR(100)) + '<Parameter>'
				PRINT '<SQL>' + @SQL + '<SQL>'
			END				
			
			SET @SQL = 'SELECT TOP 1
							RunningNumber, RevisionLastExported 
						INTO 
							##LastExportedFromDatabase'+@StoreOnDateRunningNumber+''+@GuidWithoutHyphen+'
						FROM 
							[BI_Export].[CBIE].[CBI_AccountingRevisionExport] 
						WHERE
							ZNR = '''+@StoreOnDateZNR+'''
							AND ExportedStoreId = '''+@StoreIdOnDateAndZNR+'''
						ORDER BY RevisionLastExported DESC'												
			EXEC sp_executesql @SQL

			IF(@DebugMode = 1)
			BEGIN
				PRINT '<INFO>Find RunningNumber and RevisionLastExported from database<INFO>'
				PRINT '<SQL>'+@SQL+'<SQL>'
			END			

			--Get CountTotalRevisionsFromDatabase on this row and id
			SET @ParamDefinition = N'@CountTotalRevisionsFromDatabaseOUT INT OUTPUT'	  
			SET @SQL = 'SELECT @CountTotalRevisionsFromDatabaseOUT = RevisionLastExported FROM ##LastExportedFromDatabase'+@StoreOnDateRunningNumber+''+@GuidWithoutHyphen	
			EXEC sp_executesql 	@SQL,@ParamDefinition,@CountTotalRevisionsFromDatabaseOUT = @StoreOnDateCountTotalRevisionsFromDatabase OUTPUT		

			--This revision has not been saved to database before and empty resultset is returned, aka NULL. Set it to 0 to do comparsion beneath.
			IF(@@ROWCOUNT = 0)
			BEGIN
				SET @StoreOnDateCountTotalRevisionsFromDatabase = 0
			END
			
			IF(@DebugMode = 1)
			BEGIN
				PRINT '<INFO>CountTotalRevisionsFromDatabase on this StoreId and SettlementDate<INFO>'				
				PRINT '<Parameter>ZnrOnDateCountTotalRevisionsFromDatabase = ' + CAST(@StoreOnDateCountTotalRevisionsFromDatabase AS VARCHAR(1000)) + '<Parameter>'				
			END	

			--Send complete accounting on last revision. First time received since no database records is found or complete export is forced by parameter @ExportFullLatestRevision
			IF(@StoreOnDateCountTotalRevisionsFromDatabase = 0 OR @ExportFullLatestRevision = 0)
			BEGIN							
				BEGIN TRY	

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>Send complete accounting on last revision. No database records is found<INFO>'				
						PRINT '<Parameter>ZnrOnDateCountTotalRevisionsFromDatabase=' + CAST(@StoreOnDateCountTotalRevisionsFromDatabase AS VARCHAR(100)) + '<Parameter>'
						PRINT '<Parameter>ExportFullLatestRevision=' + CAST(@ExportFullLatestRevision AS VARCHAR(100)) + '<Parameter>'
					END		
					/*
						OPPDATERT FOR VITA UTTREKK
					*/
		
					SET @SQL = '
					SELECT 
							''L''  +  '''+@Semikolon+'''										-- RECORDTYPE							
								+ CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID as VARCHAR(1000))
								+ CAST(aeldi.ZNR AS VARCHAR(1000)) 
								+ CAST(aeldi.RevisionNumber AS VARCHAR(1000)) 
								+  '''+@Semikolon+'''											--AS LØPENR
							+ CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID AS VARCHAR(1000)) +  '''+@Semikolon+'''		-- AS StoreId
							+ CAST(aeldi.ZNR AS VARCHAR(1000)) +  '''+@Semikolon+'''			-- AS ZNR
							+ CAST(aeldi.RevisionNumber AS VARCHAR(1000)) +  '''+@Semikolon+'''	-- AS Revisjon nr
							+ '''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''+@Semikolon+'''	-- AS REGNSKAPSDATO
							+ '''+CONVERT(VARCHAR(8), GETDATE(), 112)+''+@Semikolon+'''			--AS UTTREKKSDATO							
							+ ISNULL(aeldi.FreeText1,'''') + '''+@Semikolon+'''								-- AS BILAGSTEKST
							+ aeldi.FreeText2 + '''+@Semikolon+'''								-- AS BILAGSTEKST2
							+ aeldi.FreeText3 + '''+@Semikolon+'''								-- Magento Ordre nr 
							+ CASE
								WHEN aeldi.DebitAccountNumber IS NULL 
								THEN CAST(aeldi.CreditAccountNumber AS VARCHAR(20)) + '''+@Semikolon+'''
								ELSE CAST(aeldi.DebitAccountNumber AS VARCHAR(20)) + '''+@Semikolon+'''
							END																	-- AS KONTONR
							+ ISNULL(CAST(CONVERT(DECIMAL(19,2),SUM(aeldi.DebitAmountLCY)) AS VARCHAR(1000)),'''') + '''+@Semikolon+''' --AS Debit beløp
							
							
							+ ISNULL(CAST(CONVERT(DECIMAL(19,2),SUM(aeldi.CreditAmountLCY)) AS VARCHAR(1000)),'''') + '''+@Semikolon+''' --AS Kredit beløp
							+ CASE WHEN aeldi.AccountingRuleNo NOT IN (41,42)
								THEN ISNULL(CAST(aeldi.VatRate AS VARCHAR(20)),'''')
								ELSE '''' END + '''+@Semikolon+'''											-- AS MVAKODE
							
							+ CASE
								WHEN aeldi.FreeText2 != '''' AND aeldi.FreeText2 IN (''4901'',''5943'',''5947'',''5949'',''5950'',''5956'',''6012'')
								THEN aeldi.FreeText2
								ELSE 
								CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID as VARCHAR(1000)) 
							END + '''+@Semikolon+'''				-- AS Avdeling(kostandsbærer)
							
							+ CASE 
								WHEN aeldi.BagId IS NOT NULL 
								THEN CAST(aeldi.BagId AS VARCHAR(1000)) + '''+@Semikolon+'''
								ELSE '''+@Semikolon+''' 
							END																		-- AS POSENR
							+ CASE
								WHEN aeldi.FreeText2 != '''' AND aeldi.FreeText2 IN (''4901'',''5943'',''5947'',''5949'',''5950'',''5956'',''6012'')
								THEN aeldi.FreeText2
								ELSE 
								CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID as VARCHAR(1000)) 
							END + '''+@Semikolon+'''												-- AS BUTIKKNR	
							+ CAST(aeldi.GlobalLocationNumber AS VARCHAR(1000)) + '''+@Semikolon+'''--AS  EanLokasjon
							+ '''+@Semikolon+'''													--AS Egendefinert3
							+ '''+@Semikolon+'''													--AS Egendefinert4							
							+ '''+@Semikolon+'''													--AS Egendefinert5
							+ '''+@Semikolon+'''													--AS Egendefinert6
							+ '''+@Semikolon+'''													--AS Egendefinert7
							+ '''+@Semikolon+'''													--AS Egendefinert8
							+ '''+@Semikolon+'''													--AS Egendefinert9
							
							AS ''output'',
							aeldi.AccountingRuleNo
		
					INTO ##FullExport'+@GuidWithoutHyphen+'
					FROM 
						[BI_Export].CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen+' AS aeldi
						INNER JOIN BI_Mart.RBIM.Out_StoreExtraInfo s on s.StoreId = aeldi.StoreId
					WHERE 
						aeldi.SettlementDate = '''+CONVERT(VARCHAR(8), @SettlementDate, 112)+'''												
						AND aeldi.StoreId = '''+@StoreIdOnDateAndZNR+'''						
						AND aeldi.RevisionNumber = 	(SELECT 
							MIN(aeldi.RevisionNumber)
						FROM 
							[BI_Export].CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen+' AS aeldi
						WHERE 
							aeldi.SettlementDate = '''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''' AND
							aeldi.StoreId = '''+@StoreIdOnDateAndZNR+''')'
					SET @SQL = @SQL + '								
					GROUP BY 
						aeldi.AccountingRuleNo
						,aeldi.StoreId
						,aeldi.ZNR
						,aeldi.RevisionNumber
						,aeldi.SettlementDate
						,aeldi.FreeText1	
						,aeldi.FreeText2
						,aeldi.FreeText3	
						,aeldi.DebitAccountNumber
						,aeldi.CreditAccountNumber					
						,aeldi.StoreId
						,aeldi.BagId
						,aeldi.TillId
						,aeldi.VatRate
						,aeldi.GlobalLocationNumber 
						,s.Value_CA_ACCOUNTING_ACCOUNTINGID
					'					
					SET @SQL = @SQL + ' ORDER BY AccountingRuleNo'

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>SQL to make complete export file<INFO>'						
						PRINT '<SQL>' + @SQL + '<SQL>'
					END		
					EXEC sp_executesql @SQL
					
					--Add this store to export-table
					SET @SQL = 'INSERT INTO ##ExportResult'+@GuidWithoutHyphen+' SELECT output from ##FullExport'+@GuidWithoutHyphen			
					EXEC sp_executesql @SQL												 					

					SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExport] VALUES ('''+@StoreOnDateRunningNumber+''','''+@StoreOnDateZNR+''','''+@Guid+''','+CONVERT(VARCHAR(50),@StoreOnDateCountTotalRevisions)+','''+@StoreIdOnDateAndZNR+''',''COMPLETE'','''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''','''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''',GETDATE(),'''+@ExportedBy+''')'
					EXEC sp_executesql @SQL				

					IF(@DebugMode = 1)
					BEGIN							
						PRINT '<INFO>Running complete accounting - Insert into CBI_AccountingRevisionExport<INFO>'			
						PRINT '<SQL>' + @SQL + '<SQL>'			
					END	

					SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''INFO'',''Running complete accounting on RunningNumber='+@StoreOnDateRunningNumber+' RevisionId='+CAST(@StoreOnDateCountTotalRevisions AS VARCHAR(50))+''', '''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'						
					EXEC sp_executesql @SQL

				END	TRY
				BEGIN CATCH
					SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''ERROR'','''+REPLACE(ERROR_MESSAGE(),'''','')+''', '''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'
					EXEC sp_executesql @SQL
					SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''ERROR'','''+@SQL+''', '''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'
					EXEC sp_executesql @SQL
						
					IF(@DebugMode = 1)
					BEGIN
						PRINT '<ERROR>ERRORMESSAGE FROM TRY/CATCH INSIDE FULL EXPORT CATCH <ERROR>'
						PRINT '<ERROR>ErrorMessage=' + REPLACE(ERROR_MESSAGE(),'''','')	+ '<ERROR>'		
						PRINT '<ERRORSQL>'+@SQL+'<ERRORSQL>'
					END
					
					RETURN -1
					

				END CATCH
			END
			--Send delta accounting. Received more than one time. Or resend complete export on last revision							
			ELSE IF(@StoreOnDateCountTotalRevisions > 1 AND @StoreOnDateCountTotalRevisions > @StoreOnDateCountTotalRevisionsFromDatabase AND @ExportFullLatestRevision = 1) 
			BEGIN									
				BEGIN TRY						
					
					IF(@DebugMode = 1)
					BEGIN			
						PRINT '<INFO>Send delta accounting. Accounting on this day and store is sent earlier<INFO>'
						PRINT '<Parameter>ZnrOnDateCountTotalRevisions = ' + CAST(@StoreOnDateCountTotalRevisions AS VARCHAR(100)) + '<Parameter>'
						PRINT '<Parameter>ExportFullLatestRevision = ' + CAST(@ExportFullLatestRevision AS VARCHAR(100)) + '<Parameter>' 						
						PRINT '<SQL>' + @SQL + '<SQL>'           						
					END		
															
					--Get all records from from the newest revision
					SET @SQL = '
					SELECT 
						StoreId
						,ZNR
						,SettlementDate
						,FreeText1
						,FreeText2
						,FreeText3
						,DebitAccountNumber
						,DebitAmountLCY
						,CreditAccountNumber
						,CreditAmountLCY
						,AccountingRuleNo
						,BagId
						,TillId
						,VatRate
						,GlobalLocationNumber
					INTO
						##AllRecordsOnNewRevision'+@GuidWithoutHyphen+'
					FROM 
						[BI_Export].CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen+'
					WHERE 
						ZNR='+CAST(@StoreOnDateZNR AS VARCHAR(50))+' AND RevisionNumber=0
						AND StoreId = '''+@StoreIdOnDateAndZNR+''''
						
					EXEC sp_executesql @SQL
						
					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>Get all records from from the newest revision<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>'           
					END	

					--Get all records from from the latest revision runned from the database
					SET @SQL = '
					SELECT 
						StoreId
						,ZNR
						,SettlementDate
						,FreeText1
						,FreeText2
						,FreeText3
						,DebitAccountNumber
						,DebitAmountLCY
						,CreditAccountNumber
						,CreditAmountLCY
						,AccountingRuleNo
						,Bagid
						,TillId
						,VatRate
						,GlobalLocationNumber
					INTO
						##AllRecordsOnLastRevision'+@GuidWithoutHyphen+'
					FROM 
						[BI_Export].CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen+'
					WHERE 
						ZNR='+CAST(@StoreOnDateZNR AS VARCHAR(50))+' AND RevisionNumber='+CAST(@StoreOnDateCountTotalRevisionsFromDatabase AS VARCHAR(50))+'
						AND StoreId = '''+@StoreIdOnDateAndZNR+''''
					EXEC sp_executesql @SQL
						
					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>Get all records from from the latest revision runned from the database<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>'           
					END	
						
					-- Start Delta calculation
					SET @SQL = '
					SELECT 
						StoreId,
						ZNR,
						SettlementDate,
						FreeText1,
						FreeText2,
						FreeText3,
						DebitAccountNumber,
						DebitAmountLCY,
						CreditAccountNumber,
						CreditAmountLCY,
						AccountingRuleNo,
						BagId,
						TillId
						,VatRate
						,GlobalLocationNumber
					INTO ##AllRecordsWithChangeFromLastRevision'+@GuidWithoutHyphen+'
					FROM
						(
							SELECT 
								''LastRevision'' AS TableName, 
								LastRevision.StoreId, 
								LastRevision.ZNR, 
								LastRevision.SettlementDate, 
								LastRevision.FreeText1,
								LastRevision.FreeText2,
								LastRevision.FreeText3,
								LastRevision.DebitAccountNumber, 
								LastRevision.DebitAmountLCY,
								LastRevision.CreditAccountNumber,
								LastRevision.CreditAmountLCY,
								LastRevision.AccountingRuleNo,
								LastRevision.BagId,
								LastRevision.TillId
								,LastRevision.VatRate
								,LastRevision.GlobalLocationNumber
							FROM ##AllRecordsOnLastRevision'+@GuidWithoutHyphen+' AS LastRevision
							UNION ALL
							SELECT 
							''NewRevision'' as TableName, 
							NewRevision.StoreId, 
							NewRevision.ZNR, 
							NewRevision.SettlementDate, 
							NewRevision.FreeText1,
							NewRevision.FreeText2,
							NewRevision.FreeText3,
							NewRevision.DebitAccountNumber, 
							NewRevision.DebitAmountLCY,
							NewRevision.CreditAccountNumber,
							NewRevision.CreditAmountLCY,
							NewRevision.AccountingRuleNo,
							NewRevision.BagId,
							NewRevision.TillId
							,NewRevision.VatRate
							,NewRevision.GlobalLocationNumber
							FROM ##AllRecordsOnNewRevision'+@GuidWithoutHyphen+' AS NewRevision
						) tmp
					GROUP BY 
						StoreId
						,ZNR
						,SettlementDate
						,FreeText1
						,FreeText2
						,FreeText3
						,DebitAccountNumber
						,DebitAmountLCY
						,CreditAccountNumber
						,CreditAmountLCY
						,AccountingRuleNo
						,BagId
						,TillId
						,VatRate
						,GlobalLocationNumber
					HAVING COUNT(*) = 1' --	HAVING COUNT(*) = 1 is used to get records that are unique in New- and LastRevision					
						
					EXEC sp_executesql @SQL

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>Returns a result with all changes in new revision since last revision<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>'           
					END	

					--What exist in last revision but not in the newest revision
					SET @SQL = '
					SELECT 
						StoreId, 
						ZNR, 
						SettlementDate, 
						FreeText1,
						FreeText2,
						FreeText3,
						DebitAccountNumber,
						DebitAmountLCY * -1 AS DebitAmountLCY, 
						CreditAccountNumber,
						CreditAmountLCY * -1 AS CreditAmountLCY,
						AccountingRuleNo,
						BagId,
						TillId
						,VatRate
						,GlobalLocationNumber
					INTO ##RecordsFoundInLastRevisionNotInNew'+@GuidWithoutHyphen+'
					FROM ##AllRecordsOnLastRevision'+@GuidWithoutHyphen+'

					EXCEPT

					SELECT 
						StoreId, 
						ZNR, 
						SettlementDate, 
						FreeText1,
						FreeText2,
						FreeText3,
						DebitAccountNumber,
						DebitAmountLCY * -1 AS DebitAmountLCY, 
						CreditAccountNumber,
						CreditAmountLCY * -1 AS CreditAmountLCY,
						AccountingRuleNo,
						BagId,
						TillId	 
						,VatRate
						,GlobalLocationNumber

					FROM ##AllRecordsOnNewRevision'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL							

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>What exist in last revision but not in the newest revision when using delta revisions<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>'           
					END	
													
					--What exist in new revision, but did not exist in last runned revision from the revision table
					SET @SQL = '
					SELECT * 
					INTO ##FoundInNewRevisionNotInOld'+@GuidWithoutHyphen+'
					FROM ##AllRecordsOnNewRevision'+@GuidWithoutHyphen+'

					EXCEPT

					SELECT * 
					FROM ##AllRecordsOnLastRevision'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
											

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>What exist in new revision, but did not exist in last runned revision from the revision table when using delta revision<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>'           
					END	

					--What is common in both revisions, but has different value on amount? Rule: "New revision amont" - "Old revision amount". Negative values may apear.
					SET @SQL = '
					SELECT
						NewRevision.StoreId, 
						NewRevision.ZNR, 
						NewRevision.SettlementDate, 
						NewRevision.FreeText1,
						NewRevision.FreeText2,
						NewRevision.FreeText3,
						NewRevision.DebitAccountNumber, 
						SUM(NewRevision.DebitAmountLCY) - SUM(LastRevision.DebitAmountLCY) AS DebitAmountLCY, 
						NewRevision.CreditAccountNumber,
						SUM(NewRevision.CreditAmountLCY) - SUM(LastRevision.CreditAmountLCY) AS CreditAmountLCY,
						NewRevision.AccountingRuleNo,
						NewRevision.BagId,
						NewRevision.TillId
						,NewRevision.VatRate
						,NewRevision.GlobalLocationNumber
					INTO ##DifferencesInNewRevisionComparedToLastRunnedRevision'+@GuidWithoutHyphen+'
					FROM ##AllRecordsOnNewRevision'+@GuidWithoutHyphen+' AS NewRevision
					INNER JOIN ##AllRecordsOnLastRevision'+@GuidWithoutHyphen+' AS LastRevision 
						ON NewRevision.FreeText1 = LastRevision.FreeText1 
						AND NewRevision.FreeText2 = LastRevision.FreeText2
						AND NewRevision.FreeText3 = LastRevision.FreeText3
						AND NewRevision.StoreId = LastRevision.StoreId 
						AND NewRevision.ZNR = LastRevision.ZNR 
						AND NewRevision.DebitAccountNumber = LastRevision.DebitAccountNumber 
						AND NewRevision.CreditAccountNumber = LastRevision.CreditAccountNumber 
						AND NewRevision.AccountingRuleNo = LastRevision.AccountingRuleNo 
						AND NewRevision.TillId = LastRevision.TillId 
						AND NewRevision.BagId = LastRevision.BagId
						AND NewRevision.VatRate = LastRevision.VatRate
						AND NewRevision.GlobalLocationNumber = LastRevision.GlobalLocationNumber
					GROUP BY 
						NewRevision.StoreId, 
						NewRevision.ZNR, 
						NewRevision.SettlementDate, 
						NewRevision.FreeText1,
						NewRevision.FreeText2,
						NewRevision.FreeText3,
						NewRevision.DebitAccountNumber,
						NewRevision.CreditAccountNumber,
						NewRevision.AccountingRuleNo,
						NewRevision.BagId,
						NewRevision.TillId
						,NewRevision.VatRate
						,NewRevision.GlobalLocationNumber'						
					EXEC sp_executesql @SQL

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>What is common in both revisions, but has different value on amount? Rule: "New revision amont" - "Old revision amount". Negative values may apear. When using delta revision<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>'           
					END	

					--Merge and calculated result
					SET @SQL = '
					SELECT 
						result.*
					INTO ##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen+'
					FROM
						(
							SELECT * FROM ##RecordsFoundInLastRevisionNotInNew'+@GuidWithoutHyphen+' 
							UNION
							SELECT * FROM ##FoundInNewRevisionNotInOld'+@GuidWithoutHyphen+' 
							UNION
							SELECT * FROM ##DifferencesInNewRevisionComparedToLastRunnedRevision'+@GuidWithoutHyphen+'
						) AS result'											

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<INFO>SQL to with merged and calculated result when using delta export<INFO>'
						PRINT '<SQL>' + @SQL + '<SQL>' 
					END

					EXEC sp_executesql @SQL
						
					IF(@@ROWCOUNT > 0)
					BEGIN
				
						SET @SQL = 'ALTER TABLE ##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen+' ADD RevisionNumber INT'
						EXEC sp_executesql @SQL					
						IF(@DebugMode = 1)
						BEGIN
							PRINT '<INFO>SQL to alter table with revision number when using delta export<INFO>'
							PRINT '<SQL>' + @SQL + '<SQL>' 
						END

						SET @SQL = 'UPDATE ##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen+' SET RevisionNumber='+CAST(@StoreOnDateCountTotalRevisions AS VARCHAR(50))
						EXEC sp_executesql @SQL				
						IF(@DebugMode = 1)
						BEGIN
							PRINT '<INFO>SQL to update revision number to temp-table when using delta export<INFO>'
							PRINT '<SQL>' + @SQL + '<SQL>' 
						END						
											
						/*
							OPPDATERT FOR VITA UTTREKK
						*/

						SET @SQL = '
						SELECT 
								''L''  +  '''+@Semikolon+'''										-- RECORDTYPE							
									+ CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID as VARCHAR(1000))
									+ CAST(aeldi.ZNR AS VARCHAR(1000)) 
									+ CAST(aeldi.RevisionNumber AS VARCHAR(1000)) 
									+  '''+@Semikolon+'''											--AS LØPENR
								+ CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID AS VARCHAR(1000)) +  '''+@Semikolon+'''		-- AS StoreId
								+ CAST(aeldi.ZNR AS VARCHAR(1000)) +  '''+@Semikolon+'''			-- AS ZNR
								+ CAST(aeldi.RevisionNumber AS VARCHAR(1000)) +  '''+@Semikolon+'''	-- AS Revisjon nr
								+ '''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''+@Semikolon+'''	-- AS REGNSKAPSDATO
								+ '''+CONVERT(VARCHAR(8), GETDATE(), 112)+''+@Semikolon+'''			--AS UTTREKKSDATO							
								+ ISNULL(aeldi.FreeText1,'''') + '''+@Semikolon+'''								-- AS BILAGSTEKST
								+ aeldi.FreeText2 + '''+@Semikolon+'''								-- AS BILAGSTEKST2
								+ aeldi.FreeText3 + '''+@Semikolon+'''								-- Magento Ordre nr 
								+ CASE
									WHEN aeldi.DebitAccountNumber IS NULL 
									THEN CAST(aeldi.CreditAccountNumber AS VARCHAR(20)) + '''+@Semikolon+'''
									ELSE CAST(aeldi.DebitAccountNumber AS VARCHAR(20)) + '''+@Semikolon+'''
								END																	-- AS KONTONR
								+ ISNULL(CAST(CONVERT(DECIMAL(19,2),SUM(aeldi.DebitAmountLCY)) AS VARCHAR(1000)),'''') + '''+@Semikolon+''' --AS Debit beløp
							
							
								+ ISNULL(CAST(CONVERT(DECIMAL(19,2),SUM(aeldi.CreditAmountLCY)) AS VARCHAR(1000)),'''') + '''+@Semikolon+''' --AS Kredit beløp
								+ CASE WHEN aeldi.AccountingRuleNo NOT IN (41,42)
									THEN ISNULL(CAST(aeldi.VatRate AS VARCHAR(20)),'''')
									ELSE '''' END + '''+@Semikolon+'''											-- AS MVAKODE
							
								+ CASE
									WHEN aeldi.FreeText2 != '''' AND aeldi.FreeText2 IN (''4901'',''5943'',''5947'',''5949'',''5950'',''5956'',''6012'')
									THEN aeldi.FreeText2
									ELSE 
									CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID as VARCHAR(1000)) 
								END + '''+@Semikolon+'''				-- AS Avdeling(kostandsbærer)
							
								+ CASE 
									WHEN aeldi.BagId IS NOT NULL 
									THEN CAST(aeldi.BagId AS VARCHAR(1000)) + '''+@Semikolon+'''
									ELSE '''+@Semikolon+''' 
								END																		-- AS POSENR
								+ CASE
									WHEN aeldi.FreeText2 != '''' AND aeldi.FreeText2 IN (''4901'',''5943'',''5947'',''5949'',''5950'',''5956'',''6012'')
									THEN aeldi.FreeText2
									ELSE 
									CAST(s.Value_CA_ACCOUNTING_ACCOUNTINGID as VARCHAR(1000)) 
								END + '''+@Semikolon+'''												-- AS BUTIKKNR	
								+ CAST(aeldi.GlobalLocationNumber AS VARCHAR(1000)) + '''+@Semikolon+'''--AS  EanLokasjon
								+ '''+@Semikolon+'''													--AS Egendefinert3
								+ '''+@Semikolon+'''													--AS Egendefinert4							
								+ '''+@Semikolon+'''													--AS Egendefinert5
								+ '''+@Semikolon+'''													--AS Egendefinert6
								+ '''+@Semikolon+'''													--AS Egendefinert7
								+ '''+@Semikolon+'''													--AS Egendefinert8
								+ '''+@Semikolon+'''													--AS Egendefinert9
							
								AS ''output'',
								aeldi.AccountingRuleNo
		
						INTO ##DeltaExport'+@GuidWithoutHyphen+'
						FROM 
							##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen+' AS aeldi
						INNER JOIN BI_Mart.RBIM.Out_StoreExtraInfo s on s.StoreId = aeldi.StoreId
						WHERE 
							aeldi.SettlementDate = '''+CONVERT(VARCHAR(8), @SettlementDate, 112)+'''						
							AND aeldi.StoreId = '''+@StoreIdOnDateAndZNR+''''
						SET @SQL = @SQL + '								
						GROUP BY 
							aeldi.AccountingRuleNo
							,aeldi.StoreId
							,aeldi.ZNR
							,aeldi.RevisionNumber
							,aeldi.SettlementDate
							,aeldi.FreeText1	
							,aeldi.FreeText2
							,aeldi.FreeText3	
							,aeldi.DebitAccountNumber
							,aeldi.CreditAccountNumber					
							,aeldi.StoreId
							,aeldi.BagId
							,aeldi.TillId
							,aeldi.VatRate
							,aeldi.GlobalLocationNumber 
							,s.Value_CA_ACCOUNTING_ACCOUNTINGID
						'					
					
						SET @SQL = @SQL + ' ORDER BY AccountingRuleNo'					

						IF(@DebugMode = 1)
						BEGIN
							PRINT '<INFO>Delta export SQL on last revision<INFO>'
							PRINT '<SQL>' + @SQL + '<SQL>'  
							SET @DeltaExportSql = @SQL         																
						END		
						EXEC sp_executesql @SQL					

						--Add this store to export-table
						SET @SQL = 'INSERT INTO ##ExportResult'+@GuidWithoutHyphen+' SELECT output from ##DeltaExport'+@GuidWithoutHyphen			
						EXEC sp_executesql @SQL							
		
								
						SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExport] VALUES ('''+@StoreOnDateRunningNumber+''','''+@StoreOnDateZNR+''','''+@Guid+''','+CONVERT(VARCHAR(50),@StoreOnDateCountTotalRevisions)+','''+@StoreIdOnDateAndZNR+''',''DELTA'','''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''','''+CONVERT(VARCHAR(8), @SettlementDate, 112)+''',GETDATE(),'''+@ExportedBy+''')'
						EXEC sp_executesql @SQL												

						IF(@DebugMode = 1)
						BEGIN			
							PRINT '<INFO>Insert into CBI_AccountingRevisionExport<INFO>'	
							PRINT '<SQL>' + @SQL + '<SQL>'												
						END			
								
						SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''INFO'', ''Running delta accounting on RunningNumber='+@StoreOnDateRunningNumber+' with RevisionId='+CAST(@StoreOnDateCountTotalRevisions AS VARCHAR(50))+'. Last exported revision was '+CAST(@StoreOnDateCountTotalRevisionsFromDatabase AS VARCHAR(50))+''','''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'
						EXEC sp_executesql @SQL
					END 
					ELSE --No deltachanges
					BEGIN
						SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''INFO'',''No changes since last export on RunningNumber='+@StoreOnDateRunningNumber+' with RevisionId='+CAST(@StoreOnDateCountTotalRevisions AS VARCHAR(50))+'. Last exported revision was '+CAST(@StoreOnDateCountTotalRevisionsFromDatabase AS VARCHAR(50))+''','''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'
						EXEC sp_executesql @SQL																					
					END					
				END	TRY
				BEGIN CATCH
					SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''ERROR'', '''+REPLACE(ERROR_MESSAGE(),'''','')+''', '''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'
					EXEC sp_executesql @SQL

					SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''ERROR'', '''+@SQL+''', '''+@Guid+''','''+@StoreIdOnDateAndZNR+''',GETDATE(),'''+@ExportedBy+''')'
					EXEC sp_executesql @SQL

					IF(@DebugMode = 1)
					BEGIN
						PRINT '<ERROR>ErrorMessage from TRY/CATCH INSIDE DELTA CHANGES<ERROR>'
						PRINT '<ERROR>ErrorMessage=' + REPLACE(ERROR_MESSAGE(),'''','') + '<ERROR>'
						PRINT '<ERRORSQL>'+@SQL+'<ERRORSQL>'
					END

					RETURN -1

				END CATCH
			END--Finish delta accounting

			SET @StoreOnDateIndex= @StoreOnDateIndex + 1

			IF(@DebugMode = 1)
			BEGIN			
				PRINT '<Parameter>@StoreOnDateIndex increasing by 1 and is now set to='+CAST(@StoreOnDateIndex AS VARCHAR(100))+'<Parameter>'			
				PRINT '<Parameter>DestroyTempTables is set to ' + CAST(@DestroyTempTables AS VARCHAR(1000)) + '<Parameter>'
			END			
			
			IF(@DestroyTempTables = 1)
			BEGIN
				--START Clean up temp-tables used in this SProc								

				IF OBJECT_ID('Tempdb..##LastExportedFromDatabase'+@StoreOnDateRunningNumber+''+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##LastExportedFromDatabase'+@StoreOnDateRunningNumber+''+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##Interim'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##Interim'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##InterimData'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##InterimData'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##FullExport'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##FullExport'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##DeltaExport'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##DeltaExport'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END				

				IF OBJECT_ID('Tempdb..##AllRecordsOnNewRevision'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##AllRecordsOnNewRevision'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##AllRecordsOnLastRevision'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##AllRecordsOnLastRevision'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##AllRecordsWithChangeFromLastRevision'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##AllRecordsWithChangeFromLastRevision'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##RecordsFoundInLastRevisionNotInNew'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##RecordsFoundInLastRevisionNotInNew'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##FoundInNewRevisionNotInOld'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##FoundInNewRevisionNotInOld'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##DifferencesInNewRevisionComparedToLastRunnedRevision'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##DifferencesInNewRevisionComparedToLastRunnedRevision'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##InterimDelta'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##InterimDelta'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END

				IF OBJECT_ID('Tempdb..##InterimDataDelta'+@GuidWithoutHyphen) IS NOT NULL
				BEGIN 
					SET @Sql = 'DROP TABLE ##InterimDataDelta'+@GuidWithoutHyphen
					EXEC sp_executesql @SQL
				END
			END
			ELSE
			BEGIN
				IF(@DebugMode = 1)
				BEGIN	
					PRINT '<INFO>Print all temp-tables to debug<INFO>'			
					PRINT '<INFO>FULL EXPORT TABLES<INFO>'					
					PRINT 'SELECT * FROM ##StoreOnDateWithId'+@GuidWithoutHyphen
					PRINT 'SELECT * FROM ##LastExportedFromDatabase'+@GuidWithoutHyphen
					PRINT 'SELECT * FROM ##Interim'+@GuidWithoutHyphen
					PRINT 'SELECT * FROM ##InterimData'+@GuidWithoutHyphen
					PRINT '<INFO>Full Export SQL<INFO>'+@GuidWithoutHyphen	
					PRINT '<SQL>' + @FullExportSql + '<SQL>'
					PRINT ''						
					PRINT ''						
					PRINT '<INFO>DELTA EXPORT TABLES<INFO>'						
					PRINT 'SELECT * FROM ##AllRecordsOnNewRevision'+@GuidWithoutHyphen
					PRINT 'SELECT * FROM ##AllRecordsOnLastRevision'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##AllRecordsWithChangeFromLastRevision'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##RecordsFoundInLastRevisionNotInNew'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##FoundInNewRevisionNotInOld'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##DifferencesInNewRevisionComparedToLastRunnedRevision'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##MergedAndCalculatedRevisionDelta'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##InterimDelta'+@GuidWithoutHyphen	
					PRINT 'SELECT * FROM ##InterimDataDelta'+@GuidWithoutHyphen					
					PRINT '<INFO>Delta Export SQL<INFO>'+@GuidWithoutHyphen	
					PRINT '<SQL>' + @DeltaExportSql + '<SQL>'
				END
			END			
			--Clean up temp-tables and views used on this store this day  END			

			--Clean up parameters START			
			SET	@StoreOnDateRunningNumber = ''
			SET	@StoreOnDateZNR = ''
			SET	@StoreIdOnDateAndZNR = ''
			SET	@StoreOnDateCountTotalRevisions = 0
			SET	@StoreOnDateCountTotalRevisionsFromDatabase = 0			
			--Clean up parameters END
		END --END this day
		
		IF(@DestroyTempViews = 1)
		BEGIN
			IF EXISTS(SELECT 1 FROM sys.views 			
			WHERE object_id = OBJECT_ID('CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen))
			BEGIN 	
				SET @Sql = 'DROP VIEW CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen
				EXEC sp_executesql @SQL
			END					
		END
		ELSE
		BEGIN
			IF(@DebugMode = 1)
			BEGIN		
				PRINT '<INFO>Print all temp-views to debug<INFO>'					
				PRINT 'SELECT * FROM CBIE.AccountingExportLogDataInterfaceView'+@GuidWithoutHyphen								
			END
		END						

		IF(@PrintExportFileContentToScreen = 1)
		BEGIN		
			SET @SQL = 'SELECT output FROM ##ExportResult'+@GuidWithoutHyphen
			EXEC sp_executesql @SQL
		END
		ELSE
		BEGIN
			--Get CountTotalRevisionsFromDatabase on this row and id
			SET @ParamDefinition = N'@ExportResultOUT VARCHAR(MAX) OUTPUT'	  
			SET @SQL = 'SELECT @ExportResultOUT = output FROM ##ExportResult'+@GuidWithoutHyphen	
			EXEC sp_executesql 	@SQL,@ParamDefinition,@ExportResultOUT = @ExportResultContainer OUTPUT		
		END

		IF(@@ROWCOUNT > 0)
		BEGIN

			----Set id column to make sure mssql export the result in the given: order by id asc. Otherwise the result will be exported randomly
			--SET @SQL = 'ALTER TABLE ##ExportResult'+@GuidWithoutHyphen+' ADD id INT IDENTITY(1,1)'
			--EXEC sp_executesql @SQL

			SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''INFO'',''Start exporting file on date '+CONVERT(VARCHAR(8), @SettlementDate, 112)+''', '''+@Guid+''','''+@StoreId+''',GETDATE(),'''+@ExportedBy+''')'        
			EXEC sp_executesql @SQL

			--BCP COPY FILE START
			EXEC sp_configure'xp_cmdshell', 1  
			RECONFIGURE									

			SET @FullExportPath = @ExportPath+@ExportFileName +'_'+ REPLACE(CONVERT(VARCHAR(10), @SettlementDate, 112), '/', '')+ '_'+ FORMAT(GETDATE() , 'yyyyMMdd_HHmmss') + '.txt'

			IF(@DebugMode = 1)
			BEGIN
				SET @FullExportPath = @ExportPath+'Debug\'+@ExportFileName  + '_'+REPLACE(CONVERT(VARCHAR(10), @SettlementDate, 112), '/', '')+'.txt'
				PRINT '<INFO>Exporting resultfile to path: ' + @FullExportPath + '. Make sure the path exist<INFO>'
			END									
                    
			SET @CMD = 'BCP "SELECT output FROM ##ExportResult'+@GuidWithoutHyphen+'" queryout "'+@FullExportPath+'" '+@BCPCommands +' '+ @DatabaseBCPCommand+' -U '+@UserBCPCommand+' -P '+@PasswordBCPCommand+''
			EXEC master..xp_cmdshell @CMD

			IF(@DebugMode = 1)
			BEGIN						
				PRINT '<SQL>' + @CMD + '<SQL>'
			END		
			--BCP COPY FILE END	
		END
		ELSE
		BEGIN
			SET @SQL = 'INSERT INTO [BI_Export].[CBIE].[CBI_AccountingRevisionExportLog] VALUES(''WARNING'', ''Nothing to export. Export file will not be created.'', '''+@Guid+''','''+@StoreId+''',GETDATE(),'''+@ExportedBy+''')'
			EXEC sp_executesql @SQL

			IF(@DebugMode = 1)
			BEGIN					
				PRINT '<WARNING>Nothing to export. Export file will not be created.<WARNING>'
			END
		END

		IF OBJECT_ID('Tempdb..##ExportResult'+@GuidWithoutHyphen) IS NOT NULL
		BEGIN 
			SET @Sql = 'DELETE FROM ##ExportResult'+@GuidWithoutHyphen
			EXEC sp_executesql @SQL
		END
		
		--Since there might be no result on this temp-table inside a day, temp-table deletion will not catch this. Destroy it outside end of day
		IF OBJECT_ID('Tempdb..##StoreOnDateWithId'+@GuidWithoutHyphen) IS NOT NULL
		BEGIN 
			SET @Sql = 'DROP TABLE ##StoreOnDateWithId'+@GuidWithoutHyphen
			EXEC sp_executesql @SQL
		END	

		--CLEAN UP THIS STORE ON THIS SETTLEMENTDATE END

		SET @CountSettlementDays = @CountSettlementDays + 1

		IF(@DebugMode = 1)
		BEGIN				
			IF(@CountSettlementDays+1 <= @SumTotalSettlementDays+1)
			BEGIN
				PRINT '<INFO>Fetching next day. Day ' + CAST(@CountSettlementDays+1 AS VARCHAR(100)) + ' of total ' + CAST(@SumTotalSettlementDays+1 AS VARCHAR(100)) + '<INFO>'			
			END
		END
	
	END--END all days

	IF(@DebugMode = 1)
	BEGIN									
		PRINT '<Parameter>All days are fetched..<Parameter>'
	END

	-- CLEAN UP COMMON PROCEDURE TABLES START
	IF(@DestroyTempTables = 1)
	BEGIN
		IF OBJECT_ID('Tempdb..##StoresFromInput'+@GuidWithoutHyphen) IS NOT NULL
		BEGIN 
			SET @Sql = 'DROP TABLE ##StoresFromInput'+@GuidWithoutHyphen
			EXEC sp_executesql @SQL
		END	

		IF OBJECT_ID('Tempdb..##ExportResult'+@GuidWithoutHyphen) IS NOT NULL
		BEGIN 
			SET @Sql = 'DROP TABLE ##ExportResult'+@GuidWithoutHyphen
			EXEC sp_executesql @SQL
		END						
	END
	ELSE				
	BEGIN		
		IF(@DebugMode = 1)
		BEGIN
			PRINT '<INFO>Continue print all temp-tables to debug<INFO>'			
			PRINT '<INFO>Common procedure tables<INFO>'			
			PRINT 'SELECT * FROM ##StoresFromInput'+@GuidWithoutHyphen
			PRINT 'SELECT * FROM ##ExportResult'+@GuidWithoutHyphen
		END
	END
	
	-- CLEAN UP COMMON PROCEDURE TABLES END

	RETURN 0 --OK

END-- END PROCEDURE
GO

