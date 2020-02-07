USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_EftSettlementBankCards]    Script Date: 07.02.2020 10:40:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   Procedure [dbo].[usp_CBI_ds1553_FinanceReport_EftSettlementBankCards]
(@FinanceReportMode as char(1), 
 @FinancePeriodType as char(1),
 @StoreId varchar(100),  --IsUsed
 @PeriodType as char(1), 
 @DateFrom as datetime, --IsUsed
 @DateTo as datetime,   --IsUsed
 @YearToDate as integer, 
 @RelativePeriodType as char(5),
 @RelativePeriodStart as integer, 
 @RelativePeriodDuration as integer,
 @BankCardsTenderSelectionId int --= 3  --IsUsed
)
AS
BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
END
ELSE BEGIN

		-- Create temp Fact_ReceiptTender table
		IF object_id('tempdb..#FRT') IS NOT NULL DROP TABLE #FRT
		Select top 1 [ReceiptTenderIdx],[CashRegisterNo],[ReceiptId],[StoreIdx],[ReceiptDateIdx],[ReceiptTimeIdx],[ReceiptStatusIdx],[TenderIdx],[CurrencyIdx],[SubTenderIdx],[Name],[InternalNodeNumber],[Amount],[Amount2],[CurrencyAmount],[Unit],[ExchangeRateToLocalCurrency],[EtlLoadedDate],[EtlChangedDate],[SourceIdx],[CustomerIdx],[CashierUserIdx],[CashFee],[Surcharge],[SurchargeName] into #FRT from BI_Mart.rbim.Fact_ReceiptTender
		truncate TABLE #FRT
		
		DECLARE @ReportDateFrom as datetime
		DECLARE @ReportDateTo as datetime
		DECLARE @ReportReconciliationDateFrom as datetime
		DECLARE @ReportReconciliationDateTo as datetime
		Declare @MultipleStoreIdx INT
		Declare @StoreIdx INT

		DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		

		--exec [dbo].[usp_RBI_ds0553_FinanceReport_Period] 'E'/*@FinanceReportMode*/, @FinancePeriodType, @StoreId, @PeriodType,  @DateFrom, @DateTo, @YearToDate, @RelativePeriodType, @RelativePeriodStart,  @RelativePeriodDuration, @ReportDateFrom OUTPUT, @ReportDateTo OUTPUT
		-- Get Start/End dates based on EFT(E) period(P)
		SELECT @ReportDateFrom=ReportDateFrom, @ReportDateTo=ReportDateTo from  [dbo].[ufn_RBI_GetFinanceReport_Period] ('E', 'P', @StoreId,NULL,NULL,@DateFrom,@DateTo) 
		-- Get Start/End dates based on Reconciliation(R) period(P)
		DECLARE @ReportDateFromIdx int = (SELECT TOP(1) DateIdx FROM RBIM.Dim_Date WHERE FullDate = CAST(@ReportDateFrom AS date) AND DimLevel= 0 )
		DECLARE @ReportTimeFromIdx int = (SELECT TOP(1) TimeIdx FROM RBIM.Dim_Time WHERE TimeDescription = CAST(LEFT(CAST(@ReportDateFrom AS time(0)), 5) AS CHAR(5)))

		DECLARE @ReportDateToIdx int = (SELECT TOP(1) DateIdx FROM RBIM.Dim_Date WHERE FullDate = CAST(@ReportDateTo AS date) AND DimLevel= 0 )
		DECLARE @ReportTimeToIdx int = (SELECT TOP(1) TimeIdx FROM RBIM.Dim_Time WHERE TimeDescription = CAST(LEFT(CAST(@ReportDateTo AS time(0)), 5) AS CHAR(5)))
		--- {RS-39056}

		SELECT @ReportReconciliationDateFrom=ReportDateFrom, @ReportReconciliationDateTo=ReportDateTo from  [dbo].[ufn_RBI_GetFinanceReport_Period] ('R', 'P', @StoreId,NULL,NULL,@DateFrom,@DateTo) 
		
		DECLARE @ReportReconciliationDateFromIdx int = (SELECT TOP(1) DateIdx FROM RBIM.Dim_Date WHERE FullDate = CAST(@ReportReconciliationDateFrom AS date) AND DimLevel= 0 )
		DECLARE @ReportReconciliationTimeFromIdx int = (SELECT TOP(1) TimeIdx FROM RBIM.Dim_Time WHERE TimeDescription = CAST(LEFT(CAST(@ReportReconciliationDateFrom AS time(0)), 5) AS CHAR(5)))

		DECLARE @ReportReconciliationDateToIdx int = (SELECT TOP(1) DateIdx FROM RBIM.Dim_Date WHERE FullDate = CAST(@ReportReconciliationDateTo AS date) AND DimLevel= 0 )
		DECLARE @ReportReconciliationTimeToIdx int = (SELECT TOP(1) TimeIdx FROM RBIM.Dim_Time WHERE TimeDescription = CAST(LEFT(CAST(@ReportReconciliationDateTo AS time(0)), 5) AS CHAR(5)))
		-----------------------------------------

		Set @MultipleStoreIdx = (select Count(Distinct StoreIdx) from BI_Mart.RBIM.Fact_ReceiptTender where ReceiptDateIdx BETWEEN @ReportDateFromIdx and @ReportDateToIdx)

		
		--Temp [Fact_ReceiptTender]
		If (@MultipleStoreIdx) = 1
			BEGIN
			
				set @StoreIdx = (select Distinct StoreIdx from BI_Mart.RBIM.Fact_ReceiptTender where ReceiptDateIdx BETWEEN @ReportDateFromIdx and @ReportDateToIdx)
				Insert into #FRT ([ReceiptTenderIdx],[CashRegisterNo],[ReceiptId],[StoreIdx],[ReceiptDateIdx],[ReceiptTimeIdx],[ReceiptStatusIdx],[TenderIdx],[CurrencyIdx],[SubTenderIdx],[Name],[InternalNodeNumber],[Amount],[Amount2],[CurrencyAmount],[Unit],[ExchangeRateToLocalCurrency],[EtlLoadedDate],[EtlChangedDate],[SourceIdx],[CustomerIdx],[CashierUserIdx],[CashFee],[Surcharge],[SurchargeName])
				Select
					[ReceiptTenderIdx],[CashRegisterNo],[ReceiptId],[StoreIdx],[ReceiptDateIdx],[ReceiptTimeIdx],[ReceiptStatusIdx],[TenderIdx],[CurrencyIdx],[SubTenderIdx],[Name],[InternalNodeNumber],[Amount],[Amount2],[CurrencyAmount],[Unit],[ExchangeRateToLocalCurrency],[EtlLoadedDate],[EtlChangedDate],[SourceIdx],[CustomerIdx],[CashierUserIdx],[CashFee],[Surcharge],[SurchargeName]
				FROM
					BI_Mart.rbim.Fact_ReceiptTender
				where
					ReceiptDateIdx BETWEEN @ReportDateFromIdx and @ReportDateToIdx
					and StoreIdx = @StoreIdx
			END

		ELSE
			BEGIN
				Insert into #FRT ([ReceiptTenderIdx],[CashRegisterNo],[ReceiptId],[StoreIdx],[ReceiptDateIdx],[ReceiptTimeIdx],[ReceiptStatusIdx],[TenderIdx],[CurrencyIdx],[SubTenderIdx],[Name],[InternalNodeNumber],[Amount],[Amount2],[CurrencyAmount],[Unit],[ExchangeRateToLocalCurrency],[EtlLoadedDate],[EtlChangedDate],[SourceIdx],[CustomerIdx],[CashierUserIdx],[CashFee],[Surcharge],[SurchargeName])
				Select
					FRT.[ReceiptTenderIdx],FRT.[CashRegisterNo],FRT.[ReceiptId],FRT.[StoreIdx],FRT.[ReceiptDateIdx],FRT.[ReceiptTimeIdx],FRT.[ReceiptStatusIdx],FRT.[TenderIdx],FRT.[CurrencyIdx],FRT.[SubTenderIdx],FRT.[Name],FRT.[InternalNodeNumber],FRT.[Amount],FRT.[Amount2],FRT.[CurrencyAmount],FRT.[Unit],FRT.[ExchangeRateToLocalCurrency],FRT.[EtlLoadedDate],FRT.[EtlChangedDate],FRT.[SourceIdx],FRT.[CustomerIdx],FRT.[CashierUserIdx],FRT.[CashFee],FRT.[Surcharge],FRT.[SurchargeName]
				FROM
					BI_Mart.rbim.Fact_ReceiptTender FRT
						inner JOIN
					BI_Mart.RBIM.Dim_Store DS on frt.StoreIdx = ds.StoreIdx
				where
					ReceiptDateIdx BETWEEN @ReportDateFromIdx and @ReportDateToIdx
					and DS.StoreId = @StoreId
			END



		-----------------------------------------
		DROP TABLE IF EXISTS #Stores;

		SELECT StoreIdx
		INTO #Stores 
		FROM RBIM.Dim_Store ds
		WHERE StoreId = @StoreId
		AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
		-----------------------------------------
		DROP TABLE IF EXISTS #TenderSelectionBackCards; 
		
		SELECT ts.TenderSelectionId,
				tc.TenderIdx,
				tc.SubTenderIdx,
				tc.DefaultSign,
				'Bank Cards' as TenderSelectionName
		INTO #TenderSelectionBackCards
		FROM [RBIM].Cov_TenderSelection (nolock) tc 
			INNER JOIN [RBIM].Dim_TenderSelection (nolock) ts on tc.TenderSelectionIdx=ts.TenderSelectionIdx  
		WHERE ts.TenderSelectionId = @BankCardsTenderSelectionId


		;WITH ReceiptTenderEFTPeriod as 
		(   SELECT    isnull(dst.SubTenderName,'N/A') as BankCardName
					 ,sum(1) as BankCardCount
					-- ,sum(fc.[Amount]*isnull(nullif(fc.ExchangeRateToLocalCurrency,0.0),1.0)*ts.DefaultSign) as BankCardAmount
					,sum(fc.[Amount]) as BankCardAmount  --{RS-37082}
			FROM #FRT (nolock) fc
				 --INNER JOIN [RBIM].[Dim_Store] (nolock)  ds on fc.StoreIdx = ds.StoreIdx  --{RS-39056}
				 --INNER JOIN [RBIM].[Dim_Date] (nolock)  dd on fc.ReceiptDateIdx = dd.DateIdx  
				 --INNER JOIN [RBIM].[Dim_Time] tt ON fc.ReceiptTimeIdx = tt.TimeIdx  
				 INNER JOIN #TenderSelectionBackCards ts on fc.TenderIdx = ts.TenderIdx 
				 INNER JOIN [RBIM].[Dim_SubTender] (nolock) dst on fc.SubTenderIdx = dst.SubTenderIdx 
				 INNER JOIN [RBIM].[Dim_ReceiptStatus] (nolock) drc on fc.ReceiptStatusIdx = drc.ReceiptStatusIdx				 
			WHERE
			--convert(datetime,cast(fc.[ReceiptDateIdx] as varchar) + ' '+cast(isnull(nullif(fc.[ReceiptTimeIdx],-2),0)/100 as varchar)+':'+cast(isnull(nullif(fc.[ReceiptTimeIdx],-2),0)%100 as varchar),120) between @ReportDateFrom and @ReportDateTo
			--CAST(dd.FULLDATE AS VARCHAR(50))+' '+CAST(tt.TimeDescription  AS VARCHAR(50)) between @ReportDateFrom and @ReportDateTo
		 --   AND (@StoreId=ds.StoreId or @StoreId is null)
			--AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
			 (((fc.ReceiptDateIdx = @ReportDateFromIdx AND fc.ReceiptTimeIdx >= @ReportTimeFromIdx) --{RS-39056}
			OR (fc.ReceiptDateIdx = @ReportDateToIdx AND fc.ReceiptTimeIdx <= @ReportTimeToIdx))
			OR (fc.ReceiptDateIdx > @ReportDateFromIdx AND fc.ReceiptDateIdx < @ReportDateToIdx))
			AND fc.StoreIdx IN (SELECT StoreIdx FROM #Stores)
			AND drc.ReceiptStatusId in (1,5)  /*Normal and Post Voided*/			
			GROUP BY dst.SubTenderId, isnull(dst.SubTenderName,'N/A')
		),

		ReceiptTenderReconciliationPeriod as 
		(   SELECT    isnull(dst.SubTenderName,'N/A') as BankCardName
					 ,sum(1) as BankCardCount
					 --,sum(fc.[Amount]*isnull(nullif(fc.ExchangeRateToLocalCurrency,0.00),1.00)*ts.DefaultSign) as BankCardAmount
					 ,sum(fc.[Amount]) as BankCardAmount --{RS-37082}
			FROM #FRT (nolock) fc
				 --INNER JOIN [RBIM].[Dim_Store] (nolock)  ds on fc.StoreIdx = ds.StoreIdx
				 --INNER JOIN [RBIM].[Dim_Date] (nolock)  dd on fc.ReceiptDateIdx = dd.DateIdx  
				 --INNER JOIN [RBIM].[Dim_Time] tt ON fc.ReceiptTimeIdx = tt.TimeIdx  
				 INNER JOIN #TenderSelectionBackCards ts on fc.TenderIdx = ts.TenderIdx 
				 INNER JOIN [RBIM].[Dim_SubTender] (nolock) dst on fc.SubTenderIdx = dst.SubTenderIdx 
				 INNER JOIN [RBIM].[Dim_ReceiptStatus] (nolock) drc on fc.ReceiptStatusIdx = drc.ReceiptStatusIdx
			WHERE 
			--convert(datetime,cast(fc.[ReceiptDateIdx] as varchar) + ' '+cast(isnull(nullif(fc.[ReceiptTimeIdx],-2),0)/100 as varchar)+':'+cast(isnull(nullif(fc.[ReceiptTimeIdx],-2),0)%100 as varchar),120) between @ReportDateFrom and @ReportDateTo
				--CAST(dd.FULLDATE AS VARCHAR(50))+' '+CAST(tt.TimeDescription  AS VARCHAR(50)) between @ReportReconciliationDateFrom  and @ReportReconciliationDateTo
				-- AND (@StoreId=ds.StoreId or @StoreId is null)				
                -- AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
			 (((fc.ReceiptDateIdx = @ReportReconciliationDateFromIdx AND fc.ReceiptTimeIdx >= @ReportReconciliationTimeFromIdx) --{RS-39056}
			OR (fc.ReceiptDateIdx = @ReportReconciliationDateToIdx AND fc.ReceiptTimeIdx <= @ReportReconciliationTimeToIdx))
			OR (fc.ReceiptDateIdx > @ReportReconciliationDateFromIdx AND fc.ReceiptDateIdx < @ReportReconciliationDateToIdx))
			AND fc.StoreIdx IN (SELECT StoreIdx FROM #Stores) --{RS-39056}
				 AND drc.ReceiptStatusId in (1,5)  /*Normal and Post Voided*/			
			GROUP BY dst.SubTenderId, isnull(dst.SubTenderName,'N/A')
		),

		/*---------BEGIN RS-30161 recreated--------------------------------------------*/
		EftSettlements AS (
		SELECT
			 ISNULL(dst.SubTenderName,'N/A') AS BankCardName
			,SUM(NumberOfTransactions)		 AS BankCardCount
			,SUM(TransferedAmount)	         AS BankCardAmount
		FROM RBIM.Fact_EftSettlement (NOLOCK) fc
			--JOIN RBIM.Dim_Store ds ON ds.StoreIdx = fc.StoreIdx	
			JOIN RBIM.Dim_SubTender dst ON dst.SubTenderIdx = fc.SubTenderIdx
			INNER JOIN #TenderSelectionBackCards ts on fc.TenderIdx = ts.TenderIdx 
			INNER JOIN [RBIM].[Dim_EftSettlementType] est  on est.[EftSettlementTypeIdx]=fc.[EftSettlementTypeIdx] --{RS-33385}
	    WHERE --(@StoreId=ds.StoreId or @StoreId is null)   /*bracket was added (RS-29730)*/
				fc.StoreIdx IN (SELECT StoreIdx FROM #Stores) --{RS-39056}	
		 AND ( @ReportDateFrom <= EftPeriodStartDateTime AND @ReportDateTo  >=  EftPeriodEndDateTime)  
			--AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
         AND est.EftSettlementTypeId = 1 --in(1/*Bank*//*,2 --Mobile,3 --ReserveBank*/) --{RS-33385}
		GROUP BY dst.SubTenderId, ISNULL(dst.SubTenderName,'N/A')
		HAVING SUM(NumberOfTransactions) <>0 OR SUM(TransferedAmount) <>0	
		)
		/*----------END RS-30161 recreated------------------------------------------------*/

		SELECT  coalesce(e.BankCardName,rt.BankCardName,rp.BankCardName) as BankCardName
			   ,SUM(e.BankCardCount )as RegisteredByBankCount
			   ,SUM(e.BankCardAmount )as RegisteredByBankAmount
			   ,SUM(rt.BankCardCount) as RegisteredByPosReceiptCount   --EFT period
			   ,SUM(rt.BankCardAmount) as RegisteredByPosReceiptAmount --EFT period
			   ,SUM(rp.BankCardCount ) as RegisteredByPosReceiptCount2 --Reconciliation period
			   ,SUM(rp.BankCardAmount )as RegisteredByPosReceiptAmount2 --
		FROM EftSettlements e  -- we join by name since the same card might have several issuers
			 FULL outer join ReceiptTenderEFTPeriod rt on e.BankCardName = rt.BankCardName
			 FULL outer join ReceiptTenderReconciliationPeriod rp on e.BankCardName = rp.BankCardName
			 GROUP BY coalesce(e.BankCardName,rt.BankCardName,rp.BankCardName) 
		ORDER BY coalesce(e.BankCardName,rt.BankCardName,rp.BankCardName)
  END
END



GO

