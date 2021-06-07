USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_ExpensesOutlays]    Script Date: 07.02.2020 10:40:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   Procedure [dbo].[usp_CBI_ds1553_FinanceReport_ExpensesOutlays]
(@FinanceReportMode as char(1),
 @FinancePeriodType as char(1),
 @StoreId varchar(100),
 @PeriodType as char(1), 
 @DateFrom as datetime,
 @DateTo as datetime,
 @YearToDate as integer, 
 @RelativePeriodType as char(5),
 @RelativePeriodStart as integer, 
 @RelativePeriodDuration as integer
)
as 
begin
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

		declare @ReportDateFrom as datetime
		declare @ReportDateTo as datetime
		Declare @MultipleStoreIdx INT
		Declare @StoreIdx INT

		DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		

		exec [dbo].[usp_RBI_ds0553_FinanceReport_Period] @FinanceReportMode, @FinancePeriodType, @StoreId, @PeriodType,  @DateFrom, @DateTo, @YearToDate, @RelativePeriodType, @RelativePeriodStart,  @RelativePeriodDuration, @ReportDateFrom OUTPUT, @ReportDateTo 
OUTPUT
		----------------------------------------- --{RS-39056}
		DECLARE @ReportDateFromIdx int = (SELECT TOP(1) DateIdx FROM RBIM.Dim_Date WHERE FullDate = CAST(@ReportDateFrom AS date) AND DimLevel= 0 )
		DECLARE @ReportTimeFromIdx int = (SELECT TOP(1) TimeIdx FROM RBIM.Dim_Time WHERE TimeDescription = CAST(LEFT(CAST(@ReportDateFrom AS time(0)), 5) AS CHAR(5)))

		DECLARE @ReportDateToIdx int = (SELECT TOP(1) DateIdx FROM RBIM.Dim_Date WHERE FullDate = CAST(@ReportDateTo AS date) AND DimLevel= 0 )
		DECLARE @ReportTimeToIdx int = (SELECT TOP(1) TimeIdx FROM RBIM.Dim_Time WHERE TimeDescription = CAST(LEFT(CAST(@ReportDateTo AS time(0)), 5) AS CHAR(5)))

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
		;with PaidOutByUsers as
		( select  du.[LoginName] as CashierLogin
		         ,(du.FirstName+' '+du.LastName) as CashierName          
				 ,count(*) as [Count]
				 --,sum(fc.[Amount]*isnull(nullif(fc.ExchangeRateToLocalCurrency,0.0),1.0)) as [Amount]
				 ,sum(fc.[Amount]) as [Amount]  --{RS-37082}
		  FROM #FRT (nolock) fc
			   inner join [RBIM].[Brg_ReceiptTenderTransType] (nolock) btt on fc.ReceiptTenderIdx=btt.ReceiptTenderIdx
 			   inner join [RBIM].[Dim_TransType] (nolock) dtt on btt.TransTypeIdx=dtt.TransTypeIdx
			   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReceiptDateIdx = dd.DateIdx    
			   inner join [RBIM].[Dim_User] (nolock) du on fc.CashierUserIdx=du.UserIdx     -- CashierUserIdx is absent
			   inner join [RBIM].[Dim_ReceiptStatus] (nolock) dr on dr.ReceiptStatusIdx=fc.ReceiptStatusIdx
		  where 
				(( (fc.ReceiptDateIdx = @ReportDateFromIdx	 AND fc.ReceiptTimeIdx >= @ReportTimeFromIdx) 
				OR (fc.ReceiptDateIdx = @ReportDateToIdx	 AND fc.ReceiptTimeIdx <= @ReportTimeToIdx))
				OR (fc.ReceiptDateIdx > @ReportDateFromIdx	 AND fc.ReceiptDateIdx <  @ReportDateToIdx))
		  		--convert(datetime,cast(fc.[ReceiptDateIdx] as varchar) + ' '+cast(isnull(nullif(fc.[ReceiptTimeIdx],-2),0)/100 as varchar)+':'+cast(isnull(nullif(fc.[ReceiptTimeIdx],-2),0)%100 as varchar),120) between @ReportDateFrom and @ReportDateTo
		        and dtt.TransTypeId in (21303,   -- Payout (cash back related to ie. warranty)
										21304	 -- Cash payout amount defined by the reason code
										)
                and ((@StoreId=ds.StoreId or @StoreId is null))
			    and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
				and dr.ReceiptStatusId in (1,5) /*Normal and Post Voided*/				  
		  group by [LoginName], du.FirstName, du.LastName
		)
		select  [CashierLogin] 
		       ,[CashierName] 
			   ,[Count]
			   ,[Amount]
		from PaidOutByUsers
		order by [CashierName]
END
End



GO

