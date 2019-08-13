USE BI_Mart
GO

if (object_id('dbo.usp_CBI_ds1752_OperationReport_BottleDeposit') is not null)
	drop procedure dbo.usp_CBI_ds1752_OperationReport_BottleDeposit
go


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.usp_CBI_ds1752_OperationReport_BottleDeposit
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
			sub.CashierId
			,sub.CasierName
			,sum(SalesAmount)						'SalesAmount'
			,sum(BottleDepositSalesAmount)			'BottleDepositSalesAmount'
			,sum(BottleDepositSalePctVsRegSales)	'BottleDepositSalePctVsRegSales'
			,sum(BottleDepositReturnAmount)			'BottleDepositReturnAmount'
			,sum(BottleDepositManualReturnQty)		'BottleDepositManualReturnQty'
			,sum(BottleDepositManualReturnAmount)	'BottleDepositManualReturnAmount'
			,sum(LotteryReceiptRedeemed)			'LotteryReceiptRedeemed'
		FROM
			(
				SELECT     
					su.UserNameID										'CashierId'
					,su.FirstName + ' ' + ISNULL(su.LastName, '')		'CasierName'
					,sum(f.SalesAmountExclVat+f.ReturnAmountExclVat)	'SalesAmount'
					,0													'BottleDepositSalesAmount'
					,0													'BottleDepositSalePctVsRegSales'
					,0													'BottleDepositReturnAmount'
					,0													'BottleDepositManualReturnQty'
					,0													'BottleDepositManualReturnAmount'
					,0													'LotteryReceiptRedeemed'
				FROM
					RBIM.Agg_SalesAndReturnPerDay AS f 
				INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
				inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
				INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.SystemUserIdx
				WHERE 
					(
						@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
					OR	@PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
					OR	@PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR	@PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR	@PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR	@PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR	@PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					) 
				GROUP BY
					su.UserNameID
					,su.FirstName
					,su.LastName
				UNION ALL
				(
				SELECT
					a.CashierId															'CashierId'
					,a.CasierName														'CasierName'
					,0																	'SalesAmount'
					,a.BottleDepositSalesAmount + ISNULL(b.BottleDepositReturnAmt, 0)	'BottleDepositSalesAmount'
					,ISNULL((a.BottleDepositSalesAmount + ISNULL(b.BottleDepositReturnAmt, 0)) / NULLIF((a.SalesAmount + a.ReturnAmount),0),0)	'BottleDepositSalePctVsRegSales'
					,a.BottleDepositReturnAmount										'BottleDepositReturnAmount'
					,a.BottleDepositManualReturnQty										'BottleDepositManualReturnQty'
					,a.BottleDepositManualReturnAmount									'BottleDepositManualReturnAmount'
					,0																	'LotteryReceiptRedeemed'
				FROM
					(
					SELECT
						ISNULL(su.UserNameID,'')								'CashierId'
						,su.FirstName + ' ' + ISNULL(su.LastName, '')			'CasierName'
						,SUM(f.SalesAmount)										'SalesAmount'
						,SUM(f.ReturnAmount)									'ReturnAmount'
						,SUM(f.BottleDepositSalesAmount)						'BottleDepositSalesAmount'
						,SUM(f.BottleDepositReturnAmount)						'BottleDepositReturnAmount'
						,SUM(f.NumberOfReceiptsWithBottleDepositManualReturn)	'BottleDepositManualReturnQty'
						,SUM(f.BottleDepositManualReturnAmount)					'BottleDepositManualReturnAmount'
					FROM
						RBIM.Agg_CashierSalesAndReturnPerHour AS f
					INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx
					inner join Stores ds on ds.StoreIdx = f.StoreIdx
					INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
					WHERE 
						(
							@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
						OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
						OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
						OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
						OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
						OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
						)
					GROUP BY
						su.UserNameID
						,su.FirstName
						,su.LastName
					) a
				LEFT JOIN
					(
					SELECT
						ISNULL(su.UserNameID,'')						'CashierId'
						,su.FirstName + ' ' + ISNULL(su.LastName, '')	'CasierName'
						,SUM(CASE	WHEN a.ArticleTypeId = 130 THEN
										agg.ReturnAmount
									ELSE 0 END)							'BottleDepositReturnAmt'
					FROM
						RBIM.Agg_SalesAndReturnPerHour AS agg (NOLOCK)
					INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = agg.ReceiptDateIdx
					inner join Stores ds on ds.StoreIdx = agg.StoreIdx
					INNER JOIN RBIM.Dim_Article AS a (NOLOCK) ON a.ArticleIdx = agg.ArticleIdx
					INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = agg.SystemUserIdx
					WHERE 
							a.ArticleTypeId = 130
						AND agg.ReturnAmount != 0
						AND (
								@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo 
							OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
							OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
							OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
							OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
							OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
							OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
							)
					GROUP BY
						su.UserNameID
						,su.FirstName
						,su.LastName
					) b ON a.CashierId = b.CashierId AND a.CasierName = b.CasierName
				)
			UNION ALL
			SELECT
				ISNULL(su.UserNameID,'')						'CashierId'
				,su.FirstName + ' ' + ISNULL(su.LastName, '')	'CasierName'
				,0 												'SalesAmount'
				,0												'BottleDepositSalesAmount'
				,0												'BottleDepositSalePctVsRegSales'
				,0												'BottleDepositReturnAmount'
				,0												'BottleDepositManualReturnQty'
				,0												'BottleDepositManualReturnAmount'
				,SUM(f.TotalAmount)								'LotteryReceiptRedeemed'
			FROM
				RBIM.Agg_RvmReceiptPerDay AS f
			INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.DateIdx
			inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
			INNER JOIN RBIM.Dim_TransType AS tt ON tt.TransTypeIdx = f.TransTypeIdx
			WHERE
					(
						@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
					OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
					OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
					)
				AND (tt.TransTypeId = 90307)
			GROUP BY
				su.UserNameID
				,su.FirstName
				,su.LastName
			) AS sub
		group by
			sub.CashierId
			,sub.CasierName		
		)

	select * from SelectedSales
end




GO
