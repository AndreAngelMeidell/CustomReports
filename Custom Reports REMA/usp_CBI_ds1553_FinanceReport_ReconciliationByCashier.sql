USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_ReconciliationByCashier]    Script Date: 07.02.2020 10:41:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   Procedure [dbo].[usp_CBI_ds1553_FinanceReport_ReconciliationByCashier]
(
 @StoreId varchar(100) = null,
 @PeriodType as char(1), 
 @DateFrom as datetime,
 @DateTo as datetime,
 @YearToDate as integer, 
 @RelativePeriodType as char(5),
 @RelativePeriodStart as integer, 
 @RelativePeriodDuration as integer,
 @VoucherTenderSelectionId int, --= 1,
 @CashTenderSelectionId int, --= 2,
 @BankCardsTenderSelectionId int, --= 3,
 @AccountCreditTenderSelectionId int, --= 4,
 @MobileTenderSelectionId int, --= 5
 @ReconciliationType int -- Added for task (RS-34467)
)
as 
begin

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial report load improvement
END
ELSE BEGIN

	IF (@ReconciliationType <> 2)		-- Check if this procedure is needed for the report.
	BEGIN								-- If not, return empty resultset.		
		SELECT TOP (0)
		1
	END

	ELSE
	BEGIN

	DECLARE @DateFromIdx int = (SELECT DateIdx FROM BI_Mart.RBIM.Dim_Date WHERE FullDate = @DateFrom)	-- Added since 17.2 {RS-34467}
	DECLARE @DateToIdx int = (SELECT DateIdx FROM BI_Mart.RBIM.Dim_Date WHERE FullDate = @DateTo)

	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
	SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
	WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
	);
	SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
	-----------------------------------------	
	DROP TABLE IF EXISTS #TenderSelection;   --{RS-39056}

	select ts.TenderSelectionId, --whether it's money, voucher, bank card, creadit, or mobile payment tender
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
	INTO #TenderSelection
	from [RBIM].Cov_TenderSelection (nolock) tc 
			   inner join [RBIM].Dim_TenderSelection (nolock) ts on tc.TenderSelectionIdx=ts.TenderSelectionIdx  
	where ts.TenderSelectionId in (@VoucherTenderSelectionId, @CashTenderSelectionId, @BankCardsTenderSelectionId, @AccountCreditTenderSelectionId, @MobileTenderSelectionId)
	-----------------------------------------
		--;with TenderSelection as (
		--  select ts.TenderSelectionId, --whether it's money, voucher, bank card, creadit, or mobile payment tender
		--		 tc.TenderIdx,
		--		 tc.SubTenderIdx,
		--		 tc.DefaultSign,
		--		 case TenderSelectionId
		--			  when @CashTenderSelectionId then 'Cash'
		--			  when @BankCardsTenderSelectionId then 'Bank Cards'
		--			  when @AccountCreditTenderSelectionId then 'Account Credit'
		--			  when @VoucherTenderSelectionId then 'Vouchers'
		--			  when @MobileTenderSelectionId then 'Mobile'			  			  
		--		 end as TenderSelectionName
		--  from [RBIM].Cov_TenderSelection (nolock) tc 
		--	   inner join [RBIM].Dim_TenderSelection (nolock) ts on tc.TenderSelectionIdx=ts.TenderSelectionIdx  
		--  where ts.TenderSelectionId in (@VoucherTenderSelectionId, @CashTenderSelectionId, @BankCardsTenderSelectionId, @AccountCreditTenderSelectionId, @MobileTenderSelectionId)
		--),
		;WITH AccumulationTypeSelection as 
		( select a.AccumulationTypeIdx,
				 case when a.AccumulationId in ('7') then 'Bottle deposit'
					  when a.AccumulationId in ('13') then 'Expenses Outlays'
					  else 'Other'
				 end as AccumulationTypeSelectionName
		  from [RBIM].Dim_AccumulationType (nolock) a 
		),
		ReconciliationByTenders as 
		(	select  'POS' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName AS StoreName,ds.StoreId, --{RS-36137}
				   ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				   0 as HierarchyLevel,
				   ds.NumOfRegionLevels,
				   fc.ZNR, 
				   du.[LoginName] as CashierLogin, 
   				   (du.[FirstName] + du.[LastName]) as CashierName,
				   ts.TenderSelectionName, 
				 --  sum(fc.Amount*isnull(fc.Rate/nullif(fc.Unit,0),1)*ts.DefaultSign) as TenderAmount  --{RS-37082}
				 sum(fc.Amount) as TenderAmount --{RS-37082}
			from [RBIM].[Fact_ReconciliationSystemTotalPerTender] (nolock) fc
				   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
				   inner join [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
 				   --inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReconciliationDateIdx = dd.DateIdx
				   inner join [RBIM].[Dim_ReconciliationStatus] (nolock) drs on fc.ReconciliationStatusIdx=drs.ReconciliationStatusIdx
				   inner join [RBIM].[Dim_User]  (nolock)  du on fc.CashierUserIdx=du.UserIdx
				   inner join #TenderSelection ts on fc.TenderIdx = ts.TenderIdx						--{RS-39056}
			where dt.TotalTypeId=2 /*dt.TotalTypeName='Operator totals'*/
				  and ((@StoreId=ds.StoreId  and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null) --{RS-36137}
				  and fc.ReconciliationDateIdx >= @DateFromIdx 
				  and fc.ReconciliationDateIdx <= @DateToIdx
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
			group by ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName,ds.StoreId, --{RS-36137}
					 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,	ds.NumOfRegionLevels,
					 fc.ZNR, ts.TenderSelectionName, du.[LoginName] , du.[FirstName], du.[LastName]
		),
		ReconciliationByAccumulations as
		( select  'POS' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName AS StoreName,ds.StoreId,  --{RS-36137}
				 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				 0 as HierarchyLevel,
				 ds.NumOfRegionLevels,
				 fc.ZNR, 
				 du.[LoginName] as CashierLogin, 
 				 (du.[FirstName] + du.[LastName]) as CashierName,
				 da.AccumulationTypeSelectionName,  sum(fc.Amount) as AccumulationTypeAmount
		  from [RBIM].[Fact_ReconciliationSystemTotalPerAccumulationType] (nolock) fc
			   inner join AccumulationTypeSelection da on fc.AccumulationTypeIdx = da.AccumulationTypeIdx
			   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   --inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReconciliationDateIdx = dd.DateIdx
			   inner join [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
			   inner join [RBIM].[Dim_User]  (nolock) du on fc.CashierUserIdx=du.UserIdx
		  where dt.TotalTypeId=2 /*dt.TotalTypeName='Operator totals'*/
				and da.AccumulationTypeSelectionName in ('Bottle deposit','Expenses Outlays')  
				and ((@StoreId=ds.StoreId  and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null) --{RS-36137}
				and fc.ReconciliationDateIdx >= @DateFromIdx 
				and fc.ReconciliationDateIdx <= @DateToIdx
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
		  group by ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName,ds.StoreId,  --{RS-36137}
				   ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo, ds.NumOfRegionLevels,
				   fc.ZNR, da.AccumulationTypeSelectionName, du.LoginName, du.[FirstName], du.[LastName]
		),
		ReconciliationCashCountings as 
		( select  'POS' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName AS StoreName,ds.StoreId,  --{RS-36137}
				 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				 0 as HierarchyLevel,
				 ds.NumOfRegionLevels,
				 du.[LoginName] as CashierLogin, 
 				 (du.[FirstName] + du.[LastName]) as CashierName,
				 fc.ZNR, 
				 fc.TenderIdx, 
				 fc.CurrencyIdx, 
				 (fc.Amount*isnull(fc.Rate/nullif(cast(fc.Unit as decimal(19,5)),0),1)*ts.DefaultSign) as CountedCashAmount, --{RS-37082}
				 --fc.Amount  as CountedCashAmount -- {RS-37082}
				 row_number() over (partition by fc.StoreIdx, fc.ZNR, fc.TenderIdx, fc.CurrencyIdx order by CountNo desc) as ReverseCountNo  --{RS-37082}
		  from [RBIM].[Fact_ReconciliationCountingPerTender] (nolock) fc
			   inner join [RBIM].[Fact_ReconciliationSystemTotalPerTender] (nolock) rec on fc.[StoreIdx]=rec.[StoreIdx] and fc.[ZNR]=rec.[ZNR] and fc.[TotalTypeIdx]=rec.[TotalTypeIdx] --{RS-37082}
			   inner join 	
					(SELECT DISTINCT [StoreIdx],[ZNR],[TotalTypeIdx],ReconciliationDateIdx
					 FROM [RBIM].Fact_ReconciliationSystemTotalPerTender rec
					 WHERE 
						 rec.ReconciliationDateIdx >= @DateFromIdx
						 and rec.ReconciliationDateIdx <= @DateToIdx
					) rSys
					 ON rSys.[StoreIdx]=fc.[StoreIdx] and rSys.[ZNR]=fc.[ZNR] and rSys.[TotalTypeIdx]=fc.[TotalTypeIdx]	 --{RS-37082}
			   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   inner join [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
			   --inner join [RBIM].[Dim_Date] (nolock) dd on rec.ReconciliationDateIdx = dd.DateIdx    
			   inner join [RBIM].[Dim_ReconciliationStatus] (nolock) drs on fc.ReconciliationStatusIdx=drs.ReconciliationStatusIdx
			   inner join [RBIM].[Dim_User]  (nolock) du on fc.CountedByUserIdx=du.UserIdx
			   inner join #TenderSelection ts on fc.TenderIdx = ts.TenderIdx											 --{RS-39056}
		  where dt.TotalTypeId=2 /*dt.TotalTypeName='Operator totals'*/
				and ts.TenderSelectionName = 'Cash'
				and ((@StoreId=ds.StoreId  and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null) --{RS-36137}
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
		),
		ReconciliationLastCashCountings as 
		( select  'POS' AS SourceType, Lev1RegionGroupDisplayId,Lev2RegionGroupDisplayId,Lev3RegionGroupDisplayId,Lev4RegionGroupDisplayId,Lev5RegionGroupDisplayId, StoreName, 
				 Lev1RegionGroupNo,Lev2RegionGroupNo,Lev3RegionGroupNo,Lev4RegionGroupNo,Lev5RegionGroupNo, CashierLogin, CashierName, NumOfRegionLevels, HierarchyLevel,
				 StoreId, ZNR, 
				 sum(CountedCashAmount) as CountedCashAmount
		  from ReconciliationCashCountings
		  where ReverseCountNo=1 -- {RS-37082}
		  group by StoreId, ZNR, Lev1RegionGroupDisplayId,Lev2RegionGroupDisplayId,Lev3RegionGroupDisplayId,Lev4RegionGroupDisplayId,Lev5RegionGroupDisplayId, StoreName, 
				 Lev1RegionGroupNo,Lev2RegionGroupNo,Lev3RegionGroupNo,Lev4RegionGroupNo,Lev5RegionGroupNo, NumOfRegionLevels, HierarchyLevel, CashierLogin, CashierName
		),

			--- CIM inter-Store
		InterStores as 
		( select  'CIM' AS SourceType, ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName AS StoreName,ds.StoreId, 
				 ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				  NULL AS ZNR,  du.[LoginName] as CashierLogin, 
 				 (du.[FirstName] + du.[LastName]) as CashierName, 
				 sum(fc.Amount/**ts.DefaultSign*/) as Amount,
				 sum(fc.CashFee) as CashFee,
				 sum(fc.Surcharge) as Surcharge,
				 0 as HierarchyLevel,
				 ds.NumOfRegionLevels
		  from [RBIM].[Agg_ReceiptTenderDaily] (nolock) fc
			   inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
			   --inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReceiptDateIdx = dd.DateIdx    
			   inner join [RBIM].[Dim_CashRegister]  (nolock) dc on fc.CashRegisterNo=dc.CashRegisterIdx
			   inner join [RBIM].[Dim_User]  (nolock) du on fc.[CashierUserIdx]=du.UserIdx
			   inner join [RBIM].[Dim_Tender]  (nolock) t on fc.TenderIdx = t.TenderIdx 
		  where t.TenderId='26' --PurchaseOrder
    			and ((@StoreId=ds.StoreId  and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) or @StoreId is null) --{RS-36137}
				and fc.ReceiptDateIdx >= @DateFromIdx 
				and fc.ReceiptDateIdx <= @DateToIdx
					  --or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)) -- Removed since 17.2 {RS-34467}
		  group by ds.Lev1RegionGroupDisplayId,ds.Lev2RegionGroupDisplayId,ds.Lev3RegionGroupDisplayId,ds.Lev4RegionGroupDisplayId,ds.Lev5RegionGroupDisplayId, ds.CurrentStoreName,ds.StoreId, 
				   ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
				   du.[LoginName] , (du.[FirstName] + du.[LastName]),ds.NumOfRegionLevels
			
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
				pt.CashierLogin as CashierLogin,
				pt.CashierName as CashierName,
				isnull(pt.[Amount],0)  as TotalAmountOfTransactions,
				0 as [Cash],
				0 as [BankCards],
				isnull(pt.[Amount],0)  as [AccountCredit],
				isnull(pt.[CashFee],0) as [CashFee],
				ISNULL(pt.[Surcharge],0) as [Surcharge],
				0 as [Vouchers],
				0 as [Mobile],
				0 as [BottleDeposit],
				0 as CashDiffByCounting,
				0 as [ExpensesOutlays]
		FROM InterStores pt
		union all


		select  isnull(pt.SourceType,isnull(pa.SourceType,pc.SourceType)) as SourceType,
				isnull(pt.Lev1RegionGroupDisplayId,isnull(pa.Lev1RegionGroupDisplayId,pc.Lev1RegionGroupDisplayId)) as Lev1RegionGroupDisplayId,
				isnull(pt.Lev2RegionGroupDisplayId,isnull(pa.Lev2RegionGroupDisplayId,pc.Lev2RegionGroupDisplayId)) as Lev2RegionGroupDisplayId,
				isnull(pt.Lev3RegionGroupDisplayId,isnull(pa.Lev3RegionGroupDisplayId,pc.Lev3RegionGroupDisplayId)) as Lev3RegionGroupDisplayId,
				isnull(pt.Lev4RegionGroupDisplayId,isnull(pa.Lev4RegionGroupDisplayId,pc.Lev4RegionGroupDisplayId)) as Lev4RegionGroupDisplayId,
				isnull(pt.Lev5RegionGroupDisplayId,isnull(pa.Lev5RegionGroupDisplayId,pc.Lev5RegionGroupDisplayId)) as Lev5RegionGroupDisplayId,
				isnull(pt.StoreName,isnull(pt.StoreName,pc.StoreName)) as StoreName,
				isnull(pt.StoreId,isnull(pa.StoreId,pc.StoreId)) as StoreId,
				isnull(pt.HierarchyLevel,isnull(pa.HierarchyLevel,pc.HierarchyLevel)) as HierarchyLevel,
				isnull(pt.NumOfRegionLevels,isnull(pa.NumOfRegionLevels,pc.NumOfRegionLevels)) as NumOfRegionLevels,
				isnull(pt.[ZNR],isnull(pa.[ZNR],pc.ZNR)) as ZNR, 
				isnull(pt.[CashierLogin],isnull(pa.[CashierLogin],pc.CashierLogin)) as CashierLogin, 
				isnull(pt.[CashierName],isnull(pa.[CashierName],pc.CashierName)) as CashierName, 		
				(isnull(pt.[Cash],0)+isnull(pt.[Bank Cards],0)+isnull(pt.[Account Credit],0)+isnull(pt.[Vouchers],0)+isnull(pt.[Mobile],0)) as TotalAmountOfTransactions,
				isnull(pt.[Cash],0) as [Cash],
				isnull(pt.[Bank Cards],0) as [BankCards],
				isnull(pt.[Account Credit],0) as [AccountCredit],
				isnull(pt.[CashFee],0) as [CashFee],
				isnull(pt.[Surcharge],0) as [Surcharge],
				isnull(pt.[Vouchers],0) as [Vouchers],
				isnull(pt.[Mobile],0) as [Mobile],
				isnull(pa.[Bottle deposit],0) as [BottleDeposit],
				(isnull(pt.[Cash],0) - isnull(pc.[CountedCashAmount],0)) as CashDiffByCounting,
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

				full outer join ReconciliationLastCashCountings	pc on pc.StoreId=pt.StoreId and pc.ZNR=pt.ZNR
	   /* order by isnull(pt.[ZNR],isnull(pa.[ZNR],pc.ZNR))*/

		)x
		order by SourceType,ZNR
	END
END
End




GO

