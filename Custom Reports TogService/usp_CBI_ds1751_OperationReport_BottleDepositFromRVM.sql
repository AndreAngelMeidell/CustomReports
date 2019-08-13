USE [BI_Mart]
GO

if (object_id('dbo.usp_CBI_ds1751_OperationReport_BottleDepositFromRVM') is not null)
	drop procedure dbo.usp_CBI_ds1751_OperationReport_BottleDepositFromRVM
go

set ansi_nulls on
go

set quoted_identifier on
go



create procedure dbo.usp_CBI_ds1751_OperationReport_BottleDepositFromRVM
	(
	@PeriodType					char(1)
	,@DateFrom					datetime
	,@DateTo					datetime
	,@YearToDate				integer
	,@RelativePeriodType		char(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer
	,@StoreOrGroupNo			varchar(max)
	)
as
begin
	;with Stores as
		(
		select
			distinct ds.*
		from
			RBIM.Dim_Store ds
		left join ( select ParameterValue from dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  on n.ParameterValue in (
								ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
								ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
								ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
								ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
								ds.StoreId) 
		where
				n.ParameterValue is not null
			and ds.IsCurrentStore=1		--to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)
		) 
	,SelectedSales as
		(
		SELECT  
			SUM(DepositReturnAmountUsedForLottery) AS DepositReturnAmountUsedForLottery,
			SUM(GainsLess1000)  AS GainsLess1000,
			SUM(GainsAbove1000)  AS GainsAbove1000,
			SUM(UnclaimedGainsLess90days) AS UnclaimedGainsLess90days,
			SUM(UnclaimedGainsAbove90days)  AS UnclaimedGainsAbove90days
		FROM
			(
			----------------------------------------------------------------------------------------------------------------
			SELECT
				CASE  tt.TransTypeId WHEN 90306 THEN r.TotalAmount ELSE 0 END AS DepositReturnAmountUsedForLottery,
				CASE  tt.TransTypeId WHEN 90305 THEN (CASE WHEN   r.TotalAmount <  1000  THEN  r.TotalAmount ELSE 0 END) ELSE 0 END AS GainsLess1000,
				CASE  tt.TransTypeId WHEN 90305 THEN (CASE WHEN   r.TotalAmount >= 1000  THEN  r.TotalAmount ELSE 0 END) ELSE 0 END AS GainsAbove1000,
				0 AS UnclaimedGainsLess90days,
				0 AS UnclaimedGainsAbove90days
			FROM
				[RBIM].[Fact_RvmReceipt] r
			JOIN rbim.Dim_Date dd on dd.DateIdx = r.DateIdx -- Mandatory
			inner join Stores ds on ds.StoreIdx = r.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			left JOIN [BI_Mart].[RBIM].Dim_TransType tt on tt.TransTypeIdx = r.TransTypeIdx
			Where 
					(
						(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
					or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
					or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
					or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
					or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
					or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
					or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
					)
				and r.TotalAmount > 0
			---------------------------------------------------------------------------------------
			UNION ALL
			SELECT 
				0 AS DepositReturnAmountUsedForLottery,
				0 AS GainsLess1000,
				0 AS GainsAbove1000,
				CASE WHEN DATEDIFF(DD,dd.FullDate,@DateFrom)<90 THEN r.TotalAmount ELSE 0 END  AS UnclaimedGainsLess90days,
				CASE WHEN DATEDIFF(DD,dd.FullDate,@DateFrom)>=90 THEN r.TotalAmount ELSE 0 END  AS UnclaimedGainsAbove90days

			FROM
				RBIM.Fact_RvmReceipt r (NOLOCK)
			JOIN rbim.Dim_Date dd on dd.DateIdx = r.DateIdx -- Mandatory
			inner join Stores ds on ds.StoreIdx = r.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			LEFT JOIN [BI_Mart].[RBIM].Dim_TransType tt on tt.TransTypeIdx = r.TransTypeIdx
			WHERE 
					r.TransTypeIdx in (90305)
				AND (r.TotalAmount > 0 and r.TotalAmount <1000)
				AND [dbo].[ufn_RBI_IsRedeemed](r.RVMReceiptIdx,r.DateIdx,@DateTo)= 0 /*not redeemed*/
			)	sub
		)
		
	select * from SelectedSales
end

go
