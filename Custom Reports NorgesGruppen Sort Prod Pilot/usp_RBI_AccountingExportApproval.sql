USE [BI_Export]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_AccountingExportApproval]    Script Date: 03.06.2021 10:18:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************************************************************/
/*                                              CHANGELOG SECTION                                                             */
/******************************************************************************************************************************/
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 07-NOV-2016
-- Updated by: vsw\geistgin
-- Description: (RS-27681) Reconciliations and Receipts verification rule was updated. From Tenders source only normal 
-- receipts now are included and all tenders that are not part of reconciliation were excluded (TenderId=26)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 2017-02-14
-- Updated by: Algirdas Berneris
-- Description: Added translation tags  (RS-22678)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 28-APR-2017
-- Updated by: vsw\geistgin
-- Description: Removed parameter dependencies on Legacy tables (RS-32160)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 16-JUL-2018
-- Updated by: vsw\geistgin
-- Description:  Support of Receipt status Receipt return (Retro Void) was included in accounting export (RS-38572)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 27-MAY-2019
-- Updated by: gintaras.geistoraitis
-- Description:  Added transaction isolation level and removed execution of procedure for lad update, it was locking issue and 
-- not used anymore for accounting aproval (RS-42933)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 27-FEB-2020
-- Updated by: eugenijus.rozumas
-- Description:  Adding support for TotalType = 6 (Store) and removing deprectaded Accounting V1 references (RS-47563)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 30-JUL-2020
-- Updated by: Dmytro Fedorchuk
-- Description: Categorize AE logs (RS-36363)
-------------------------------------------------------------------------------------------------------------------------------
-- Update date: 23-NOV-2020
-- Updated by: Dmytro Fedorchuk
-- Description: Fix settlement date (RS-50787)
-------------------------------------------------------------------------------------------------------------------------------	
-- Update date: 03-DEC-2020
-- Updated by: alexandru.lungu
-- Description: Changed file encoding from ANSI to UTF-8 BOM for reading special character '¤' (RS-50511)

/******************************************************************************************************************************/
/*                                              MAIN SECTION                                                                  */
/* Keep main script up to date                                                                                                */
/******************************************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_RBI_AccountingExportApproval]	
	@znr as int,
	@StoreId as varchar (100)
as
begin	
set nocount on;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	declare @LogMessage as varchar(300);
	declare @LogSeverity as int;
	declare @Approved as int; --Sjekker om oppgjøret godkjent fra før.
	declare @ReconciliationTotalType as int
	declare @DefaultReconciliationTypeForAccountingExport varchar(255)
	declare @AccountingExportSetupVersion varchar(5)
			
	-- V2 For Reconciliation and Receipt -------------------------------
	DECLARE	 @FirstTransactionDateIdx AS INT
			,@LastTransactionDateIdx  AS INT
			,@FirstTransactionTimeIdx AS INT
			,@LastTransactionTimeIdx  AS INT
	---------------------------------------------------------------------
	SET @AccountingExportSetupVersion = 2 /*(SELECT TOP 1 Value FROM [RBIE].AccountingExportParameters WHERE ParameterName='AccountingExportSetupVersion')*/
	SET @DefaultReconciliationTypeForAccountingExport = (SELECT TOP 1 Value FROM [RBIE].AccountingExportParameters WHERE ParameterName='DefaultReconciliationTypeForAccountingExport')

	   IF (@AccountingExportSetupVersion =2)	
    	BEGIN
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
	     END 

--   ELSE IF (ISNULL(@AccountingExportSetupVersion,1) = 1)  
--  BEGIN
--SET @ReconciliationTotalType = (select UseTotalTypeForApprovement from  RBIE.Leg_StoreSetup where StoreId=@StoreId)                      
--     END	

	
	set @Approved = (select count(*) from [RBIE].AccountingExportSettlementHead where StoreId=@StoreId and znr = @znr and ApprovedDateTime is null); /***{was added in BI DWH solution}***/
				
	if (@Approved > 0) 
		begin --Starter logikk for å godkjenne oppgjør.
			
			--§§§ Dognforskyvning håndtering
			    begin try --#Region for Dognforskyvning logikk. 
				declare @Dognforskyvning as int; 
				declare @date as date;	
				declare @FromDate as datetime;
				declare @ToDate as datetime;
				declare @DateIdx as int;
	
    --           IF (ISNULL(@AccountingExportSetupVersion,1) = 1)
    --           BEGIN
				--set @Dognforskyvning = (select cast(isnull(Value,0) as int) from [RBIE].Leg_Parameter where Name = 'DOGNFORSKYVNING');
				--set @date = (select cast(SettlementDate as date) from [RBIE].AccountingExportSettlementHead where StoreId=@StoreId and znr = @znr);  /***{was added in BI DWH solution}***/	
				--set @FromDate = @date;
				--set @FromDate = dateadd(hour,@Dognforskyvning,@FromDate);			
				--set @ToDate = @FromDate + 1;
			 --  END	
			   set @date = (select cast(SettlementDate as date) from [RBIE].AccountingExportSettlementHead where StoreId=@StoreId and znr = @znr);  /***{was added in BI DWH solution}***/	
			   set @DateIdx =  (SELECT YEAR(@date) * 10000 + MONTH(@date) * 100 + DAY(@date))
			   
			  -- Lagt til "AND f.StoreIdx in" 20210502  AM
			  
			  IF (@AccountingExportSetupVersion = 2)
			  BEGIN
			  
				  SELECT  @FirstTransactionDateIdx=MIN(f.FirstTransactionDateIdx), @LastTransactionDateIdx= MAX(f.LastTransactionDateIdx)
				  FROM  [BI_Mart].[RBIM].[Fact_ReconciliationSystemTotalPerTender] f
						  INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS tt ON 
							f.TotalTypeIdx = tt.TotalTypeIdx AND TotalTypeId = @ReconciliationTotalType 
				  WHERE f.ReconciliationDateIdx = @DateIdx 
				  AND f.StoreIdx in (SELECT TOP 1 ds.StoreIdx FROM BI_Mart.RBIM.Dim_Store AS ds WHERE ds.StoreId=@StoreId AND ds.isCurrent=1)
	               
				  SELECT @FirstTransactionTimeIdx=Min(f.FirstTransactionTimeIdx)
        		  FROM [BI_Mart].[RBIM].[Fact_ReconciliationSystemTotalPerTender] f  
        				 INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS tt ON 
							f.TotalTypeIdx = tt.TotalTypeIdx AND TotalTypeId = @ReconciliationTotalType 
				  WHERE  f.ReconciliationDateIdx =  @DateIdx 
				  AND f.FirstTransactionDateIdx = @FirstTransactionDateIdx
				  AND f.StoreIdx in (SELECT TOP 1 ds.StoreIdx FROM BI_Mart.RBIM.Dim_Store AS ds WHERE ds.StoreId=@StoreId AND ds.isCurrent=1)
	                     
			 
				  SELECT @LastTransactionTimeIdx= MAX(f.LastTransactionTimeIdx)
				  FROM [BI_Mart].[RBIM].[Fact_ReconciliationSystemTotalPerTender] f  
						 INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS tt ON 
							f.TotalTypeIdx = tt.TotalTypeIdx AND TotalTypeId = @ReconciliationTotalType 
				  WHERE  f.ReconciliationDateIdx = @DateIdx
				  AND @LastTransactionDateIdx=f.LastTransactionDateIdx 
				  AND f.StoreIdx in (SELECT TOP 1 ds.StoreIdx FROM BI_Mart.RBIM.Dim_Store AS ds WHERE ds.StoreId=@StoreId AND ds.isCurrent=1)
				  
			  END
			  
			 /* IF (@AccountingExportSetupVersion = 2)
				BEGIN
					EXEC [dbo].[usp_RBI_updateLadStatus]	@DateIdx = @DateIdx
			    END	
			 */ --{RS-42933}

			end try
			begin catch
				set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Accounting failed ¤') + error_message());
				exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId, @LogType=1; 
			end catch --#Region Slutt.
			
			begin try --Region for Utregninger og sjekker 
				declare @diffKontering as decimal (18 ,2) 	
				declare @diffBongOppgjor as decimal (18 ,2)
				declare @checkReconciliationAmount as decimal (18 ,2);
				declare @sjekkFritekst1 as int;
				DECLARE @checkTendersAmount as decimal (18 ,2) 	
				DECLARE @ListOfTotalTypeValuesInt TABLE (Value INT)
				DECLARE @ListOfTotalTypeValuesStr TABLE (Value varchar(255))
				declare @DebitCreditDiff as decimal (18,2);
				

				set @diffKontering = (	select 
											sum(isnull(DebitAmount,0)) - sum(isnull(CreditAmount,0)) as diff
										from [RBIE].AccountingExportSettlementLine
										where StoreId=@StoreId and znr=@znr)                                                            /***{was added in BI DWH solution}***/

					
				IF (@AccountingExportSetupVersion = 2) -- Will be used for additional comparision V1=V2?
				BEGIN
					SET @DebitCreditDiff = (select 
											sum(isnull(DebitAmountLCY,0)) - sum(isnull(CreditAmountLCY,0)) as diff
										from [CBIE].RBI_AccountingExportDataInterface
										where StoreId=@StoreId and ZNR=@znr)
				END						
				/*BEGIN Uses the right reconciliations totaling type for comparision and approvement*/		
								
				IF 	@ReconciliationTotalType = 2
				BEGIN	
				     ---V1----------	
					 --IF (ISNULL(@AccountingExportSetupVersion,1) = 1)
					 --BEGIN
						--set @checkReconciliationAmount = (	select sum(isnull(Amount,0))
						--							from [RBIE].Leg_TenderReconciliationPerDay kb 
						--							WHERE kb.StoreID=@StoreId and kb.PostedDate=@date
						--							and kb.TotalTypeId = 2 /*1-POS;2-Cashier;3-Day;4-Till*/
						--							)     
					
					 --END
					 ---V2----------
					 IF (@AccountingExportSetupVersion = 2)
						 BEGIN		
						 
											    
						 INSERT INTO @ListOfTotalTypeValuesInt (Value)
						 SELECT DISTINCT R.CashierUserIdx
						 FROM [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender R
					    		 INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON R.StoreIdx = S.StoreIdx
								 INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS TT ON TT.TotalTypeIdx = R.TotalTypeIdx AND TT.TotalTypeId = 2
						 WHERE S.StoreId=@StoreId AND R.ReconciliationDateIdx=@DateIdx					
							
						 SET @checkTendersAmount = (	
							SELECT 
							--SUM(R.Amount) 											
							SUM(CASE WHEN r.TransTypeIdx IN ('21304') THEN R.Amount*-1 ELSE R.Amount END) --AM 20210603
							FROM [BI_MART].RBIM.Fact_ReceiptTender AS R 
								  INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON
									 R.StoreIdx = S.StoreIdx	
								  INNER JOIN [BI_MART].RBIM.Dim_Tender AS T ON     --(RS-27681)
								     R.TenderIdx=T.TenderIdx                       
								  INNER JOIN [BI_MART].RBIM.Dim_ReceiptStatus AS RS ON --(RS-27681)
								     R.ReceiptstatusIdx=RS.ReceiptStatusIdx												
							WHERE
							S.StoreId=@StoreId   
							AND RS.ReceiptStatusId in (1,5) /*Only Normal and Post Voided Receipts statuses are included in verification*/  --(RS-27681) {RS-38572}
							AND T.TenderId not in ('26')  /*Exclude all Tenders that are not part of reconciliation*/   --(RS-27681)
							AND (R.ReceiptDateIdx >= @FirstTransactionDateIdx   and R.ReceiptTimeIdx>=@FirstTransactionTimeIdx)
							AND (R.ReceiptDateIdx <= @LastTransactionDateIdx   and R.ReceiptTimeIdx<=@LastTransactionTimeIdx) 
							AND  R.CashierUserIdx IN (SELECT Value FROM @ListOfTotalTypeValuesInt ) 
							)
									 
						set @checkReconciliationAmount = (	
								SELECT SUM(ISNULL(A.Amount,0))
								FROM  [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender AS A
								--LEFT JOIN [BI_STAGE].RBIS.ladFactReconciliationSystemPerTender AS LEG
									--ON A.RowIdx = LEG.FactRowIdx
								INNER JOIN [BI_MART].RBIM.Dim_Store AS D
									ON A.StoreIdx = D.StoreIdx AND D.StoreID=@StoreId
								INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS B
									ON A.TotalTypeIdx = B.TotalTypeIdx AND TotalTypeId = 2 
								WHERE A.ReconciliationDateIdx = @DateIdx
								AND A.TenderIdx NOT IN ('13') --AM 20210603
								)  
					END
				END
				
				ELSE
				 IF @ReconciliationTotalType = 1
					BEGIN	
						---V1----------	
						 --IF (ISNULL(@AccountingExportSetupVersion,1) = 1)
							-- BEGIN
							--  set @checkReconciliationAmount = (	select sum(isnull(Amount,0))
							--							FROM [RBIE].Leg_TenderReconciliationPerDay kb 
							--							WHERE kb.StoreID=@StoreId and kb.PostedDate=@date
							--							and kb.TotalTypeId = 1 /*1-POS;2-Cashier;3-Day;4-Till*/
							--							) 
							-- END
						 ---V2----------						
						 IF (@AccountingExportSetupVersion = 2)
							 BEGIN	
							 
							
					    
							 INSERT INTO @ListOfTotalTypeValuesInt (Value)
						    
							 SELECT DISTINCT C.CashRegisterId
							 FROM [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender R
							    	 INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON R.StoreIdx = S.StoreIdx
								     INNER JOIN [BI_MART].RBIM.Dim_CashRegister AS C ON C.CashRegisterIdx = R.CashRegisterIdx
								     INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS TT ON TT.TotalTypeIdx = R.TotalTypeIdx AND TT.TotalTypeId = 1
							 WHERE S.StoreId=@StoreId AND R.ReconciliationDateIdx=@DateIdx					
						
							 SET @checkTendersAmount = (	
								SELECT SUM(R.Amount) 											
								FROM [BI_MART].RBIM.Fact_ReceiptTender AS R 
									  INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON
										 R.StoreIdx = S.StoreIdx	
									  INNER JOIN [BI_MART].RBIM.Dim_Tender AS T ON     --(RS-27681)
								         R.TenderIdx=T.TenderIdx                       
									 INNER JOIN [BI_MART].RBIM.Dim_ReceiptStatus AS RS ON --(RS-27681)
								         R.ReceiptstatusIdx=RS.ReceiptStatusIdx										
								WHERE
								S.StoreId=@StoreId    
								AND RS.ReceiptStatusId in (1,5) /*Only Normal and Post Voided Receipts statuses are included in verification*/  --(RS-27681) {RS-38572}
							    AND T.TenderId not in ('26')  /*Exclude all Tenders that are not part of reconciliation*/   --(RS-27681)  
								AND (R.ReceiptDateIdx >= @FirstTransactionDateIdx  and R.ReceiptTimeIdx>=@FirstTransactionTimeIdx)
								AND (R.ReceiptDateIdx <= @LastTransactionDateIdx   and R.ReceiptTimeIdx<=@LastTransactionTimeIdx) 
								AND  R.CashRegisterNo IN (SELECT Value FROM @ListOfTotalTypeValuesInt ) 
								)
								 
								set @checkReconciliationAmount = (	
										SELECT SUM(ISNULL(A.Amount,0))
										FROM  [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender AS A
										--LEFT JOIN [BI_STAGE].RBIS.ladFactReconciliationSystemPerTender AS LEG
											--ON A.RowIdx = LEG.FactRowIdx
										INNER JOIN [BI_MART].RBIM.Dim_Store AS D
											ON A.StoreIdx = D.StoreIdx AND D.StoreID=@StoreId
										INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS B
											ON A.TotalTypeIdx = B.TotalTypeIdx AND TotalTypeId = 1 
										WHERE A.ReconciliationDateIdx = @DateIdx) 
							 END   
																					   /***not needed because having date in tenders reconciliation{was added in BI DWH solution}***/
					END
				
				ELSE 
				 IF @ReconciliationTotalType = 4
					BEGIN					 					
					 IF (@AccountingExportSetupVersion = 2)
					 BEGIN	
					 
					 					    
					    INSERT INTO @ListOfTotalTypeValuesStr (Value)
					    
					    SELECT DISTINCT R.TillId 
					    FROM [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender R
						     INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON R.StoreIdx = S.StoreIdx
						     INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS TT ON TT.TotalTypeIdx = R.TotalTypeIdx AND TT.TotalTypeId = 4 
						WHERE S.StoreId=@StoreId AND R.ReconciliationDateIdx=@DateIdx					
					
						SET @checkTendersAmount = (	
							SELECT SUM(R.Amount) 											
							FROM [BI_MART].RBIM.Fact_ReceiptTender AS R 
									INNER JOIN [BI_MART].RBIM.Fact_Receipt R2 on R2.receiptIdx = (select top 1 receiptidx from [BI_MART].rbim.Fact_Receipt where ReceiptHeadIdx = R.ReceiptHeadIdx)
									INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON
									 R.StoreIdx = S.StoreIdx	
									INNER JOIN	[BI_MART].RBIM.Dim_Tender AS T ON     --(RS-27681)
								     R.TenderIdx=T.TenderIdx                          
								    INNER JOIN [BI_MART].RBIM.Dim_ReceiptStatus AS RS ON --(RS-27681)
								     R.ReceiptstatusIdx=RS.ReceiptStatusIdx									
							WHERE
							S.StoreId=@StoreId   
							AND RS.ReceiptStatusId in (1,5) /*Only Normal and Post Voided Receipts statuses are included in verification*/  --(RS-27681) {RS-38572}
							AND T.TenderId not in ('26')  /*Exclude all Tenders that are not part of reconciliation*/   --(RS-27681)   
							AND (R.ReceiptDateIdx >= @FirstTransactionDateIdx  and R.ReceiptTimeIdx>=@FirstTransactionTimeIdx)
							AND (R.ReceiptDateIdx <= @LastTransactionDateIdx   and R.ReceiptTimeIdx<=@LastTransactionTimeIdx) 
							AND  R2.TillId IN (SELECT Value FROM @ListOfTotalTypeValuesStr ) 
							)
						
						set @checkReconciliationAmount = (	
								SELECT SUM(ISNULL(A.Amount,0))
								FROM  [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender AS A
								
								INNER JOIN [BI_MART].RBIM.Dim_Store AS D
									ON A.StoreIdx = D.StoreIdx AND D.StoreID=@StoreId
								INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS B
									ON A.TotalTypeIdx = B.TotalTypeIdx AND TotalTypeId = 4 
								WHERE A.ReconciliationDateIdx = @DateIdx) 
	             END           
				end	
				--- Total Type 6 (Store)
				ELSE IF @ReconciliationTotalType = 6
				BEGIN									
					 IF (@AccountingExportSetupVersion = 2)
					 BEGIN					 
					 					    
					  	SET @checkTendersAmount = (	
							SELECT SUM(R.Amount) 											
							FROM [BI_MART].RBIM.Fact_ReceiptTender AS R 							     
									INNER JOIN [BI_MART].RBIM.Dim_Store AS S ON
									 R.StoreIdx = S.StoreIdx	
									INNER JOIN	[BI_MART].RBIM.Dim_Tender AS T ON     --(RS-27681)
								     R.TenderIdx=T.TenderIdx                          
								    INNER JOIN [BI_MART].RBIM.Dim_ReceiptStatus AS RS ON --(RS-27681)
								     R.ReceiptstatusIdx=RS.ReceiptStatusIdx									
							WHERE
							S.StoreId=@StoreId   
							AND RS.ReceiptStatusId in (1,5) /*Only Normal and Post Voided Receipts statuses are included in verification*/  --(RS-27681) {RS-38572}
							AND T.TenderId not in ('26')  /*Exclude all Tenders that are not part of reconciliation*/   --(RS-27681)   
							AND (R.ReceiptDateIdx >= @FirstTransactionDateIdx  and R.ReceiptTimeIdx>=@FirstTransactionTimeIdx)
							AND (R.ReceiptDateIdx <= @LastTransactionDateIdx   and R.ReceiptTimeIdx<=@LastTransactionTimeIdx) 						
							)
						
						set @checkReconciliationAmount = (	
								SELECT SUM(ISNULL(A.Amount,0))
								FROM  [BI_MART].RBIM.Fact_ReconciliationSystemTotalPerTender AS A								
								INNER JOIN [BI_MART].RBIM.Dim_Store AS D
									ON A.StoreIdx = D.StoreIdx AND D.StoreID=@StoreId
								INNER JOIN [BI_Mart].[RBIM].[Dim_TotalType] AS B
									ON A.TotalTypeIdx = B.TotalTypeIdx AND TotalTypeId = 6 
								WHERE A.ReconciliationDateIdx = @DateIdx) 
					END           
				END	

				/*END Uses the right reconciliations totaling type for comparision and approvement*/					
------------------------------------------------------------------------------------------------------------------------------				
				 ---V1----------	
					 --IF (ISNULL(@AccountingExportSetupVersion,1) = 1)
					 --BEGIN
						-- set @diffBongOppgjor = ((select sum(isnull(PaidAmount,0))from [RBIE].Leg_ReceiptPerTender bb 
						--					inner join [RBIE].Leg_Receipt b on (bb.ReceiptIdx=b.ReceiptIdx 
						--						and b.ReceiptDateTime>=@FromDate 
						--						and b.ReceiptDateTime<@ToDate)
						--					WHERE bb.StoreId=@StoreId                /***{was added in BI DWH solution}***/                                             
						--						and bb.TenderId not in ('26')       /*Exclude all Tenders that are not part of reconciliation*/   --(RS-27681)            
						--				)
						--				- ISNULL(@checkReconciliationAmount,0)                                                                /***{was added in BI DWH solution}***/
						--				);	
					 --END
					 
				---V2----------						
					 IF (@AccountingExportSetupVersion = 2)
					 BEGIN		 
				
					    --§§§ sjekk om summen av betalingsmidler i bong og kassereroppgjør er lik					
						set @diffBongOppgjor = (
							ISNULL(@checkTendersAmount,0) - ISNULL(@checkReconciliationAmount,0)
						   );
						   
						set @LogMessage= 'Settlement sources: ReceiptTendersAmount=' +IIF(@checkTendersAmount IS NULL, 'NULL', CONVERT(VARCHAR, @checkTendersAmount)) +
							', ReconciledAmount=' + IIF(@checkReconciliationAmount IS NULL, 'NULL', CONVERT(VARCHAR, @checkReconciliationAmount));
						IF (ISNULL(@checkReconciliationAmount, 0) = 0 OR ISNULL(@checkTendersAmount, 0) = 0)
							SET @LogSeverity = 3
						ELSE
							SET @LogSeverity = 2
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId, @LogType=@LogSeverity;
				     END						
				
															
				/*
					--§§§ Logikk for å sjekke at alle konteringslinjer har "Fritekst1"
					-- grunnet at vi nå har linket fritekst1 feltet mot konteringskonto tabellen
					-- og hvis vi da har feil oppsett så sender vi blank fritekst1 og da igjen vil 
					-- oppgjør bli avvis på bongrampa. 
				*/
				set @sjekkFritekst1 = (select count(*) from [RBIE].AccountingExportSettlementLine where StoreID=@StoreId and znr = @znr and Dimension1 is null);	/***{was added in BI DWH solution}***/		

			end try
			begin catch
				set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Accounting failed¤') + error_message());
				exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId, @LogType=1; 
			end catch --#Region slutt.
			          
			if ((@diffKontering  = 0.00) and (@diffBongOppgjor = 0.00) and (@sjekkFritekst1 = 0))
				begin --Godkjenner oppgjør!
					begin try
						update [RBIE].AccountingExportSettlementHead set ApprovedDateTime = getdate() where StoreId=@StoreId and znr=@znr;  /***{was added in BI DWH solution}***/
						set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Settlement was approved.¤'));
						exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId;				
					end try
					begin catch
						set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Settlement failed. error message: ¤') + error_message());
						exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId, @LogType=1;                   
					end catch                  
				end				
			else 
				begin --Oppgjoer ikke godkjent. 
					if (@diffKontering  != 0.00)
						begin 				
							set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Settlement was not approved. (Debet - Kredit) Diff = ¤')+ cast(@diffKontering  as varchar(50)));
							exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId, @LogType=3;
						end
					else if (@diffBongOppgjor != 0.00) 
						begin 
							set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Settlement was not approved. Build and Treasurer Settlement is not equal. (Debet - Kredit) Diff = ¤')+ cast(@diffBongOppgjor as varchar(50)) + '. BONG - OPPGJOER');
							exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId, @LogType=3;
						end
					else if (@sjekkFritekst1 != 0)
						begin 
							declare @kontonr_mangler_fritekst1 as varchar(50);
							set @kontonr_mangler_fritekst1 = (select
							                                      case	
																	when max(DebitAccountNumber) is null then max(CreditAccountNumber)
																	else max(DebitAccountNumber)
																  end as Account
															  from [RBIE].AccountingExportSettlementLine
															  where StoreId=@StoreId                                   /***{was added in BI DWH solution}***/
															        and znr = @znr             
																	and Dimension1 is null)
							set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Settlement was not approved as account missing text1. Number =¤') + @kontonr_mangler_fritekst1 );
							exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId, @LogType=3;
						end
					else if (@checkReconciliationAmount is null)--Kasserer oppgjør mangler
						begin
							set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Settlement was not approved due to the cashier settlement missing¤'));
							exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId, @LogType=3;
						end					                      
					else
						begin
							set @LogMessage = (select dbo.ufn_RBI_InsertResource('¤Settlement was NOT approved. Reason unknown.¤'));
							exec [dbo].usp_RBI_AccountingExportLog @Message = @LogMessage, @StoreId=@StoreId, @LogType=3;                          
						end                      
				end	--Finner hvilken sjekk som feiler og logger til Super LOGG tabell
		end	--Ferdig med logikk for å godkjenne oppgjør.
	else
		begin --Oppgjoer allerede godkjent.
			set @LogMessage=(select dbo.ufn_RBI_InsertResource('¤Settelment already approved. ZNR = ¤')+cast(@znr as varchar(50))); 
			exec [dbo].usp_RBI_AccountingExportLog @Message=@LogMessage, @StoreId=@StoreId, @LogType=3;
		end	--Logger til Super LOGG tabell.	
		end

GO

