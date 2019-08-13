use BI_Mart
go

if (object_id('dbo.usp_CBI_ds1752_OperationReport_KeyFigures') is not null)
	drop procedure dbo.usp_CBI_ds1752_OperationReport_KeyFigures
go

set ansi_nulls on
go

set quoted_identifier on
go


create procedure dbo.usp_CBI_ds1752_OperationReport_KeyFigures
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
			CashierId,
			CasierName,
			--SUM(SalesAmount) AS TotalRegTrans, --{RS-27230} 
			SUM(SalesAmount+ReturnAmount) AS TotalRegTrans, --{RS-27230} all returns and all sales, 3.rd sales included.
			--SUM(isnull(SalesAmount,0)) - SUM(ISNULL(Pos3rdPartySalesAmount,0)) AS RegisteredArticleSales, --{RS-27230} 
			SUM(isnull(SalesAmount,0)+isnull(ReturnAmount,0)) - SUM(ISNULL(Pos3rdPartySalesAmount,0)+ISNULL(Pos3rdPartyReturnAmount,0)) AS RegisteredArticleSales, --{RS-27230} all returns and all sales, 3.rd sales excluded.
			SUM(NumberOfCustomers) - SUM(NumberOfReceiptsWithOnly3rdPartySales) AS NumberOfCustomers, 
			--ISNULL(SUM(SalesAmount - Pos3rdPartySalesAmount) / NULLIF (SUM(NumberOfCustomers - NumberOfReceiptsWithOnly3rdPartySales), 0),0) AS AvgSalesPerCustomer, --{RS-27230} 
			ISNULL((SUM(SalesAmount+ReturnAmount) - SUM(Pos3rdPartySalesAmount+Pos3rdPartyReturnAmount)) / NULLIF (SUM(NumberOfCustomers - NumberOfReceiptsWithOnly3rdPartySales), 0),0) AS AvgSalesPerCustomer, --{RS-27230} 
			ISNULL(SUM(NumberOfScannedArticles - NumberOf3rdPartyScannedArticles) / NULLIF (SUM(NumberOfScannableArticles - NumberOf3rdPartyScannableArticles), 0),0) AS SkanningPercent, 
			--SUM(Pos3rdPartySalesAmount) AS [3rdPartySales], --{RS-27230} 
			SUM(Pos3rdPartySalesAmount+Pos3rdPartyReturnAmount) AS [3rdPartySales],--{RS-27230} all returns and all sales, only 3.rd sales included.
			SUM(NumberOfReceiptsWith3rdPartySales) AS NumberOf3rdPartyCustomers,
			--ISNULL(SUM(Pos3rdPartySalesAmount)/ NULLIF (SUM(NumberOfReceiptsWith3rdPartySales), 0),0) AS Avg3rdPartySalesPerCustomer,  --{RS-27230} 
			ISNULL(SUM(Pos3rdPartySalesAmount+Pos3rdPartyReturnAmount)/ NULLIF (SUM(NumberOfReceiptsWith3rdPartySales), 0),0) AS Avg3rdPartySalesPerCustomer, --{RS-27230} all returns and all sales, only 3.rd sales included.
			SUM(NumberOfScannedArticles - NumberOf3rdPartyScannedArticles) AS NumberOfScannedArticlesWithout3rdParty,                  
			SUM(NumberOfScannableArticles - NumberOf3rdPartyScannableArticles)  AS NumberOfScannableArticlesWithout3rdParty                       
		FROM
			(
			SELECT  
				su.UserNameID AS CashierId
				,su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName
				,SUM(f.SalesAmountExclVat) AS SalesAmount
				,SUM(f.ReturnAmountExclVat) AS ReturnAmount
				,SUM(f.NumberOfCustomers) AS NumberOfCustomers
				,0 AS Pos3rdPartySalesAmount
				,0 AS Pos3rdPartyReturnAmount  --{RS-27230} added
				,0 AS NumberOfReceiptsWith3rdPartySales
				,0 AS NumberOfScannedArticles
				,0 AS NumberOfScannableArticles
				,0 AS NumberOf3rdPartyScannedArticles
				,0 AS NumberOf3rdPartyScannableArticles
				,0 AS NumberOfReceiptsWithOnly3rdPartySales
			FROM
				RBIM.Agg_SalesAndReturnPerDay AS f 
			INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
			INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.SystemUserIdx
			inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
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
			SELECT   
				su.UserNameID AS CashierId
				,su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName
				,0 AS SalesAmount
				,0 AS ReturnAmount
				,0 AS NumberOfCustomers
				,SUM(f.Pos3rdPartySalesAmount) AS Pos3rdPartySalesAmount
				,SUM(f.Pos3rdPartyReturnAmount) AS Pos3rdPartyReturnAmount --{RS-27230} added
				,SUM(f.NumberOfReceiptsWith3rdPartySales) AS NumberOfReceiptsWith3rdPartySales
				,SUM(f.NumberOfScannedArticles) AS NumberOfScannedArticles
				,SUM(f.NumberOfScannableArticles) AS NumberOfScannableArticles
				,SUM(f.NumberOf3rdPartyScannedArticles) AS NumberOf3rdPartyScannedArticles
				,SUM(f.NumberOf3rdPartyScannableArticles) AS NumberOf3rdPartyScannableArticles
				,SUM(f.NumberOfReceiptsWithOnly3rdPartySales) AS NumberOfReceiptsWithOnly3rdPartySales
			FROM
				RBIM.Agg_CashierSalesAndReturnPerHour AS f 
			INNER JOIN  RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
			INNER JOIN  RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
			inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			WHERE     
				(
					@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
				OR @PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
				OR @PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR @PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR @PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR @PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR @PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1) AND (ds.IsCurrentStore = 1
				)
				GROUP BY
					su.UserNameID
					,su.FirstName
					,su.LastName
			) AS sub
		GROUP BY
			CashierId
			,CasierName
		)
		
	select * from SelectedSales
end

go
