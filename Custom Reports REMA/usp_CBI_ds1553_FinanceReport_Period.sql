USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_Period]    Script Date: 07.02.2020 10:41:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE Procedure [dbo].[usp_CBI_ds1553_FinanceReport_Period]
(@FinanceReportMode as char(1),
 @FinancePeriodType as char(1),
 @StoreId varchar(100),
 @PeriodType as char(1), 
 @DateFrom as datetime,
 @DateTo as datetime,
 @YearToDate as integer, 
 @RelativePeriodType as char(5),
 @RelativePeriodStart as integer, 
 @RelativePeriodDuration as integer,
 @ReportDateFrom as datetime OUTPUT,
 @ReportDateTo as datetime OUTPUT
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
    set @ReportDateFrom = @DateFrom 
    set @ReportDateTo = @DateTo

	CREATE TABLE #tmpFinanceInfo
	(  CompanyNumber varchar(255),
	   CompanyName varchar(255),
	   Store varchar(255),
	   LocationNumber varchar(255),
	   EftSettlementTime datetime,
	   EftSettlementTransactionFirst datetime,
	   EftSettlementTransactionLast datetime,
	   PosIncludedInEftSettlement int,
	   ReconciliationTime datetime,
	   ReconciliationTransactionFirst datetime,
	   ReconciliationTransactionLast datetime,
	   PosIncludedInReconcilition int,
	   CashierIncludedInReconcilition int
	)

	INSERT INTO #tmpFinanceInfo	exec [dbo].[usp_RBI_ds0553_FinanceReport_Info] @FinanceReportMode, @StoreId, @PeriodType,  @DateFrom, @DateTo, @YearToDate, @RelativePeriodType, @RelativePeriodStart,  @RelativePeriodDuration

    if (@FinancePeriodType='R')
	   select @ReportDateFrom=ReconciliationTransactionFirst, @ReportDateTo=ReconciliationTransactionLast
	   from #tmpFinanceInfo

    if (@FinancePeriodType='E') 
	   select @ReportDateFrom=EftSettlementTransactionFirst, @ReportDateTo=EftSettlementTransactionLast
	   from #tmpFinanceInfo


    if (@FinancePeriodType is null) 
		select @ReportDateFrom = min(dd.FullDate),
			   @ReportDateTo = max(dd.FullDate) 
		from RBIM.Dim_Date (nolock) dd
		where	(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
							or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
							or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
							or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
							or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
							or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
							or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)

End
END




GO

