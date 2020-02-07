USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_Info]    Script Date: 07.02.2020 10:41:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   Procedure [dbo].[usp_CBI_ds1553_FinanceReport_Info]
(@FinanceReportMode as char(1),
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

	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
	SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
	WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
	);
	SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		
	if object_id(N'tempdb.dbo.#dim_time', N'U') is not null drop table #dim_time;
	create table #dim_time(TimeIdx smallint, FormattedTime char(8));
	insert into #dim_time
	select
		t.TimeIdx,
		case when (t.TimeIdx < 0 or t.TimeDescription is null) then '00:00:00' else t.TimeDescription + ':00' end as FormattedTime
	from
		rbim.Dim_Time t (nolock)
	create unique clustered  index tmp_idx_time on #dim_time(TimeIdx);

	if object_id(N'tempdb.dbo.#dim_date', N'U') is not null drop table #dim_date;
	create table #dim_date(DateIdx int, FormattedDate char(8));
	insert into #dim_date
	select
		d.DateIdx,
		case when (d.DateIdx < 0 or d.FullDate is null) then '19000101' else convert(char(8), d.DateIdx) end as FormattedDate
	from
		rbim.Dim_Date d (nolock)
	create unique clustered index tmp_idx_date on #dim_date(DateIdx);

	;with EftSettlementInfo as (
			select CompanyNumber,
				   CompanyName,
				   Store,
				   LocationNumber,
				   EftSettlementTime,
				   EftSettlementTransactionFirst,
				   EftSettlementTransactionLast,
				   PosIncludedInEftSettlement
			from (
					select ds.Lev1LegalGroupDisplayId as CompanyNumber,
						   ds.Lev1LegalGroupName as CompanyName,
						   case when @StoreId is null then null else ds.CurrentStoreName end as Store,				--{RS-36137}
						   case when @StoreId is null then null else ds.GlobalLocationNo end as LocationNumber,
						   max(convert(datetime, dt.FormattedDate + ' ' + tm.FormattedTime)) as EftSettlementTime, 
						   min(EftPeriodStartDateTime) as EftSettlementTransactionFirst,
						   max(EftPeriodEndDateTime) as EftSettlementTransactionLast,
						   count(distinct (ds.StoreId + ':' + cast(dc.CashRegisterId as varchar))) as PosIncludedInEftSettlement
					from  [RBIM].[Fact_EftSettlement] (nolock) fc 
						  inner join [RBIM].[Dim_Date]  (nolock) dd on  replace(cast(cast(
																 (case when datediff(n,cast(fc.EftPeriodEndDateTime as date),fc.EftPeriodEndDateTime) < 
																			 datediff(n,fc.EftPeriodStartDateTime, dateadd(day, 1, cast(fc.EftPeriodStartDateTime as date))) 
																			 and fc.EftPeriodStartDateTime<>'1900-01-01 00:00:00.0'
																	   then fc.EftPeriodStartDateTime 
																	   else fc.EftPeriodEndDateTime
																   end) as date) as varchar),'-','')
															   = dd.DateIdx    
						  inner join [RBIM].[Dim_Store]  (nolock) ds on fc.StoreIdx = ds.StoreIdx
						  inner join [RBIM].[Dim_CashRegister] (nolock) dc on fc.CashRegisterIdx = dc.CashRegisterIdx
						  left join #dim_time tm on tm.TimeIdx = fc.ReceiptTimeIdx
						  left join #dim_date dt on dt.DateIdx = fc.ReceiptDateIdx
					where ((@StoreId=ds.StoreId and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null)--{RS-36137}
						  and ((@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
								or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1))
					group by ds.Lev1LegalGroupDisplayId, ds.Lev1LegalGroupName, case when @StoreId is null then null else ds.CurrentStoreName end, case when @StoreId is null then null else ds.GlobalLocationNo end --{RS-36137}
				 ) rec
	),
	ReconciliationInfo as ( 
			select CompanyNumber,
				   CompanyName,
				   Store,
				   LocationNumber,
				   ReconciliationTime,
				   ReconciliationTransactionFirst,
				   ReconciliationTransactionLast,
				   PosIncludedInReconcilition,
				   CashierIncludedInReconcilition
			from (
					select   ds.Lev1LegalGroupDisplayId as CompanyNumber,
							 ds.Lev1LegalGroupName as CompanyName,
							 case when @StoreId is null then null else ds.CurrentStoreName end as Store, --{RS-36137}
							 case when @StoreId is null then null else ds.GlobalLocationNo end as LocationNumber,				     
							 max(convert(datetime, dmr.FormattedDate + ' ' + tmr.FormattedTime)) as ReconciliationTime, 
							 min(convert(datetime, dft.FormattedDate + ' ' + tft.FormattedTime)) as ReconciliationTransactionFirst,
							 max(convert(datetime, dlt.FormattedDate + ' ' + tlt.FormattedTime)) as ReconciliationTransactionLast,
							 count(distinct (ds.StoreId + ':' + cast(dc.CashRegisterId as varchar))) as PosIncludedInReconcilition,
							 count(distinct (ds.StoreId + ':' + du.LoginName)) as CashierIncludedInReconcilition
					  from [RBIM].[Fact_ReconciliationSystemTotalPerTender] (nolock) fc
						   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
						   inner join [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
						   inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReconciliationDateIdx = dd.DateIdx    
						   inner join [RBIM].[Dim_ReconciliationStatus]  (nolock) drs on fc.ReconciliationStatusIdx=drs.ReconciliationStatusIdx
						   inner join [RBIM].[Dim_CashRegister] (nolock) dc on fc.CashRegisterIdx = dc.CashRegisterIdx
						   inner join [RBIM].[Dim_User] (nolock) du on fc.CashierUserIdx = du.UserIdx
						   left join #dim_time tmr on tmr.TimeIdx=fc.ReconciliationTimeIdx
						   left join #dim_date dmr on dmr.DateIdx=fc.ReconciliationDateIdx
						   left join #dim_time tft on tft.TimeIdx=fc.FirstTransactionTimeIdx
						   left join #dim_date dft on dft.DateIdx=fc.FirstTransactionDateIdx
						   left join #dim_time tlt on tlt.TimeIdx=fc.LastTransactionTimeIdx
						   left join #dim_date dlt on dlt.DateIdx=fc.LastTransactionDateIdx
					  where ((dt.TotalTypeId=1 /*'POS totals'*/ and @FinanceReportMode='P')
							  or (dt.TotalTypeId=2 /*'Operator totals'*/ and @FinanceReportMode='C'))
							--and drs.ReconciliationStatusId in (1,2,4)    -- drs.ReconciliationStatusName in ('Active','Approved','Deviation','Valid')                                  		
							and ((@StoreId=ds.StoreId and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null)--{RS-36137}
							and ((@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
								  or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1))
					   group by ds.Lev1LegalGroupDisplayId, ds.Lev1LegalGroupName, case when @StoreId is null then null else ds.CurrentStoreName end, case when @StoreId is null then null else ds.GlobalLocationNo end --{RS-36137}
				   ) rec
	)
	select 
		   isnull(eft.CompanyNumber,rec.CompanyNumber) as CompanyNumber,
		   isnull(eft.CompanyName,rec.CompanyName) as CompanyName,
		   isnull(eft.Store,rec.Store) as Store,
		   isnull(eft.LocationNumber,rec.LocationNumber) as LocationNumber,
		   eft.EftSettlementTime,
		   eft.EftSettlementTransactionFirst,
		   eft.EftSettlementTransactionLast,
		   eft.PosIncludedInEftSettlement,
		   rec.ReconciliationTime,
		   rec.ReconciliationTransactionFirst,
		   rec.ReconciliationTransactionLast,
		   rec.PosIncludedInReconcilition,
		   rec.CashierIncludedInReconcilition
	from EftSettlementInfo eft
		 full outer join ReconciliationInfo rec on 1=1
		 full outer join (values(1)) emptyset(one) on 1=1 
End





GO

