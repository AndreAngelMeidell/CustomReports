USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_ReconciliationByPos]    Script Date: 07.02.2020 10:41:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   Procedure [dbo].[usp_CBI_ds1553_FinanceReport_ReconciliationByPos]
(
 @StoreId varchar(100) = null,
 @PeriodType as char(1), 
 @DateFrom as datetime,
 @DateTo as datetime,
 @YearToDate as integer, 
 @RelativePeriodType as char(5),
 @RelativePeriodStart as integer, 
 @RelativePeriodDuration as integer,
 @VoucherTenderSelectionId int,-- = 1,
 @CashTenderSelectionId int,--  = 2,
 @BankCardsTenderSelectionId int,-- = 3,
 @AccountCreditTenderSelectionId int,-- = 4,
 @MobileTenderSelectionId int, -- = 5
 @ReconciliationType int -- Added for task (RS-34467)
)
as 
begin

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF (@ReconciliationType <> 1)		-- Check if this procedure is needed for the report.
	BEGIN								-- If not, return empty resultset.		
		SELECT TOP (0)
		1
	END

	ELSE
	BEGIN

	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
	SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
	WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
	);
	SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		

	DECLARE @DateFromIdx int = (SELECT DateIdx FROM RBIM.Dim_Date WHERE FullDate = @DateFrom)	-- Added since 17.2 {RS-34467}
	DECLARE @DateToIdx int = (SELECT DateIdx FROM RBIM.Dim_Date WHERE FullDate = @DateTo)
	
		;with TenderSelection as (
		  select ts.TenderSelectionId,
				 tc.TenderIdx,
				 tc.SubTenderIdx,
				 tc.DefaultSign,
				 case TenderSelectionId
					  when @CashTenderSelectionId then 'Cash'
					  when @BankCardsTenderSelectionId then 'Bank Cards'
					  when @AccountCreditTenderSelectionId then 'Account Credit'
					  when @VoucherTenderSelectionId then 'Vouchers'
					  when @MobileTenderSelectionId then 'Mobile'			  			  
				 end as TenderSelectionName
		  from [RBIM].Cov_TenderSelection (nolock) tc 
			   inner join [RBIM].Dim_TenderSelection (nolock) ts on tc.TenderSelectionIdx=ts.TenderSelectionIdx  
		  where ts.TenderSelectionId in (@VoucherTenderSelectionId, @CashTenderSelectionId, @BankCardsTenderSelectionId, @AccountCreditTenderSelectionId, @MobileTenderSelectionId)
		),
		AccumulationTypeSelection as 
		( select a.AccumulationTypeIdx,
				 case when a.AccumulationId in ('7') then 'Bottle deposit'
					  when a.AccumulationId in ('13') then 'Expenses Outlays'
					  else 'Other'
				 end as AccumulationTypeSelectionName
		  from [RBIM].Dim_AccumulationType  (nolock)  a 
		),
		ReconciliationByTenders as 
		( select 'POS' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName AS StoreName,ds.StoreId, --{RS-36137}
				 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				 fc.ZNR, dc.CashRegisterId, dc.CashRegisterName, ts.TenderSelectionName, 
				 sum(fc.Amount*isnull(fc.Rate/nullif(fc.Unit,0),1)*ts.DefaultSign) as TenderAmount,
				 0 as HierarchyLevel,
				 ds.NumOfRegionLevels
		  from [RBIM].[Fact_ReconciliationSystemTotalPerTender] (nolock) fc
			   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   inner join [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
			   --inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReconciliationDateIdx = dd.DateIdx    
			   inner join [RBIM].[Dim_ReconciliationStatus]  (nolock) drs on fc.ReconciliationStatusIdx=drs.ReconciliationStatusIdx
			   inner join [RBIM].[Dim_CashRegister]  (nolock) dc on fc.CashRegisterIdx=dc.CashRegisterIdx
			   inner join TenderSelection ts on fc.TenderIdx = ts.TenderIdx 
		  where dt.TotalTypeId=1 /*dt.TotalTypeName='Pos totals'*/
				and ts.TenderSelectionName in ('Cash','Bank Cards','Account Credit','Vouchers','Mobile')
				--and drs.ReconciliationStatusId in (2,3,4) /*drs.ReconciliationStatusName in ('Approved','Deviation','Valid') */                    		
				 and ((@StoreId=ds.StoreId  and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null) --{RS-36137}
				 and fc.ReconciliationDateIdx >= @DateFromIdx 
				 and fc.ReconciliationDateIdx <= @DateToIdx
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
		  group by ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName,ds.StoreId,  --{RS-36137}
				   ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				   fc.ZNR,dc.CashRegisterId, dc.CashRegisterName, ts.TenderSelectionName, ds.NumOfRegionLevels
		),
		ReconciliationByAccumulations as
		( select 'POS' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName as StoreName,ds.StoreId,  --{RS-36137}
				 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				fc.ZNR, dc.CashRegisterId, dc.CashRegisterName, da.AccumulationTypeSelectionName,  
				 sum(fc.Amount) as AccumulationTypeAmount,
				0 as HierarchyLevel,
				ds.NumOfRegionLevels
		  from [RBIM].[Fact_ReconciliationSystemTotalPerAccumulationType]  (nolock) fc
			   inner join AccumulationTypeSelection da on fc.AccumulationTypeIdx = da.AccumulationTypeIdx
			   inner join [RBIM].[Dim_Store]  (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   --inner join [RBIM].[Dim_Date]  (nolock) dd on fc.ReconciliationDateIdx = dd.DateIdx    
			   inner join [RBIM].[Dim_CashRegister]  (nolock) dc on fc.CashRegisterIdx=dc.CashRegisterIdx
			   inner join [RBIM].[Dim_TotalType]  (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
		  where dt.TotalTypeId=1 /*dt.TotalTypeName='Pos totals'*/
				and da.AccumulationTypeSelectionName in ('Bottle deposit','Expenses Outlays') 		
				and ((@StoreId=ds.StoreId or @StoreId is null))
				and fc.ReconciliationDateIdx >= @DateFromIdx 
				and fc.ReconciliationDateIdx <= @DateToIdx
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
		  group by ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName,ds.StoreId,  --{RS-36137}
				   ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				   fc.ZNR, dc.CashRegisterId, dc.CashRegisterName, da.AccumulationTypeSelectionName, ds.NumOfRegionLevels
		),
		--- CIM StoreTranfer
		InterStores as 
		( select 'CIM' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName as StoreName,ds.StoreId,  --{RS-36137}
				 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				 NULL AS ZNR, dc.CashRegisterId, dc.CashRegisterName, 
				 sum(fc.Amount) as Amount,
				 sum(fc.CashFee) as CashFee,
				 sum(fc.Surcharge) as Surcharge,
				 0 as HierarchyLevel,
				 ds.NumOfRegionLevels
		  from [RBIM].[Agg_ReceiptTenderDaily] (nolock) fc
			   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   --inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReceiptDateIdx = dd.DateIdx    
			   inner join [RBIM].[Dim_CashRegister]  (nolock) dc on fc.CashRegisterNo=dc.CashRegisterIdx
			   inner join [RBIM].[Dim_Tender]  (nolock) t on fc.TenderIdx = t.TenderIdx 
		  where t.TenderId='26' --PurchaseOrder
    			  and ((@StoreId=ds.StoreId  and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null) --{RS-36137}
				  and fc.ReceiptDateIdx >= @DateFromIdx 
				  and fc.ReceiptDateIdx <= @DateToIdx
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
		  group by ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName,ds.StoreId,  --{RS-36137}
				   ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				   dc.CashRegisterId, dc.CashRegisterName,ds.NumOfRegionLevels
		)
		SELECT * FROM (
		select  pt.SourceType, 
				pt.Lev1RegionGroupDisplayId as Lev1RegionGroupDisplayId,
				pt.Lev2RegionGroupDisplayId as Lev2RegionGroupDisplayId,
				pt.Lev3RegionGroupDisplayId as Lev3RegionGroupDisplayId,
				pt.Lev4RegionGroupDisplayId as Lev4RegionGroupDisplayId,
				pt.Lev5RegionGroupDisplayId as Lev5RegionGroupDisplayId,
				pt.StoreName as StoreName,
				pt.StoreId as StoreId,
				pt.HierarchyLevel as HierarchyLevel,
				pt.NumOfRegionLevels as NumOfRegionLevels,
				pt.[ZNR]  as ZNR, 
				pt.CashRegisterId as CashRegisterId,
				pt.CashRegisterName as CashRegisterName,
				isnull(pt.[Amount],0)  as TotalAmountOfTransactions,
				0 as [Cash],
				0 as [BankCards],
				isnull(pt.[Amount],0)  as [AccountCredit], --And PurchaseOrder
				isnull(pt.[CashFee],0)  as CashFee,
				isnull(pt.[Surcharge],0)  as Surcharge,
				0 as [Vouchers],
				0 as [Mobile],
				0 as [BottleDeposit],
				0 as [ExpensesOutlays]
		FROM InterStores pt
		union all
		select 
				isnull(pt.SourceType,pa.SourceType) as SourceType,
				isnull(pt.Lev1RegionGroupDisplayId,pa.Lev1RegionGroupDisplayId) as Lev1RegionGroupDisplayId,
				isnull(pt.Lev2RegionGroupDisplayId,pa.Lev2RegionGroupDisplayId) as Lev2RegionGroupDisplayId,
				isnull(pt.Lev3RegionGroupDisplayId,pa.Lev3RegionGroupDisplayId) as Lev3RegionGroupDisplayId,
				isnull(pt.Lev4RegionGroupDisplayId,pa.Lev4RegionGroupDisplayId) as Lev4RegionGroupDisplayId,
				isnull(pt.Lev5RegionGroupDisplayId,pa.Lev5RegionGroupDisplayId) as Lev5RegionGroupDisplayId,
				isnull(pt.StoreName,pa.StoreName) as StoreName,
				isnull(pt.StoreId,pa.StoreId) as StoreId,
				isnull(pt.HierarchyLevel,pa.HierarchyLevel) as HierarchyLevel,
				isnull(pt.NumOfRegionLevels,pa.NumOfRegionLevels) as NumOfRegionLevels,
				CAST(isnull(pt.[ZNR],pa.[ZNR]) as varchar(50)) as ZNR, 
				isnull(pt.CashRegisterId,pa.CashRegisterId) as CashRegisterId,
				isnull(pt.CashRegisterName,pa.CashRegisterName) as CashRegisterName,
				(isnull(pt.[Cash],0)+isnull(pt.[Bank Cards],0)+isnull(pt.[Account Credit],0)+isnull(pt.[Vouchers],0)+isnull(pt.[Mobile],0)) as TotalAmountOfTransactions,
				isnull(pt.[Cash],0) as [Cash],
				isnull(pt.[Bank Cards],0) as [BankCards],
				isnull(pt.[Account Credit],0) as [AccountCredit],
				isnull(pt.[CashFee],0) as [CashFee],
				isnull(pt.[Surcharge],0) as [Surcharge],
				isnull(pt.[Vouchers],0) as [Vouchers],
				isnull(pt.[Mobile],0) as [Mobile],
				isnull(pa.[Bottle Deposit],0) as [BottleDeposit],
				isnull(pa.[Expenses Outlays],0) as [ExpensesOutlays]
		from 	ReconciliationByTenders t
				pivot ( sum(TenderAmount) for TenderSelectionName in 
						([Cash],				
						 [Bank Cards],			
						 [Account Credit],
						 [CashFee],
						 [Surcharge],		
						 [Vouchers],			
						 [Mobile])				
						) as pt

				full outer join 
				ReconciliationByAccumulations a  
				pivot ( sum(AccumulationTypeAmount) for AccumulationTypeSelectionName in
						([Bottle deposit],
						 [Expenses Outlays]) 
						) pa on pa.StoreId=pt.StoreId and pa.ZNR=pt.ZNR 

		--order by isnull(pt.[ZNR],pa.[ZNR]
	
		) x
		order by SourceType,ZNR

	END
End






GO

