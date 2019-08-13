USE [BI_Mart]
GO

if (object_id('dbo.usp_CBI_ds1751_OperationReport_Returns') is not null)
	drop procedure dbo.usp_CBI_ds1751_OperationReport_Returns
go

set ansi_nulls on
go

set quoted_identifier on
go


create procedure dbo.usp_CBI_ds1751_OperationReport_Returns
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
			--,sum(SalesAmount)-SUM(Pos3rdPartySalesAmount) AS RegisteredArticlesSales  --{RS-27230} 
			,sum(SalesAmount+ReturnAmount)  AS SalesRevenueInclVat --{RS-27230} all returns vs all sales, 3.rd sales included.
			,sum(NumberOfReceiptsWithReturn) AS NumberOfReceiptsWithReturn
			,sum(NumberOfArticlesInReturn) AS NumberOfArticlesInReturn
			--,sum(ReturnAmount) AS ReturnAmount --{RS-27230}
			,sum(ReturnAmount)*-1 AS ReturnAmount --{RS-27230} positive value in report
			--,ISNULL((sum(ReturnAmount-Pos3rdPartyReturnAmount)) /NULLIF(sum(SalesAmount-Pos3rdPartySalesAmount),0),0) AS ReturnPctVsSales,  --{RS-27230}
			,ISNULL(sum(ReturnAmount)*-1/NULLIF(sum(SalesAmount),0),0) AS ReturnPctVsSales,  --{RS-27230} all returns vs all sales, 3.rd sales included; {RS-31241} Division by zero fixed
			 sum(NumberOfReceiptsWithGenericGtinInReturn) AS NumberOfReceiptsWithGenericGtinInReturn,
			 sum(NumberOfArticlesWithGenericGtinInReturn) AS NumberOfArticlesWithGenericGtinInReturn,
			 sum(GenericGtinReturnAmount) AS  GenericGtinReturnAmount,
			 0 as VeksleAntallAvbrudd,  /**/
			 0 as QuantityOfInteruptedCHS          /*not in 15.1???*/
		FROM
			(
			----------------------------------------------------------------------------------------------------------------
			SELECT
				  su.[UserNameID] AS CashierId,
				  su.FirstName+' '+ISNULL(su.LastName,'') AS CasierName, 
				  SUM(f.[SalesAmount]) AS [SalesAmount],
				  0 as Pos3rdPartySalesAmount,
				  SUM(f.[ReturnAmount]) AS [ReturnAmount],
				  0 AS Pos3rdPartyReturnAmount,
				  sum(NumberOfReceiptsWithReturn) as NumberOfReceiptsWithReturn,
				  sum(NumberOfArticlesInReturn) as NumberOfArticlesInReturn,
				  SUM(f.NumberOfReceiptsWithReturnPerSelectedArticle) AS NumberOfReceiptsWithReturnPerSelectedArticle,
				  0 NumberOfReceiptsWithGenericGtinInReturn,
				  0 NumberOfArticlesWithGenericGtinInReturn,
				  0 GenericGtinReturnAmount

			FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerDay] f
			join rbim.Dim_Date dd on dd.DateIdx = f.ReceiptDateIdx -- Mandatory
			inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			join rbim.Dim_User su on su.UserIdx = f.SystemUserIdx

			Where (
				(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
				or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
				or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				)
			--and da.ArticleIdx > -1 		-- needs to be included if you should exclude LADs etc.
											-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
			--and da.Is3rdPartyArticle=0 
			GROUP BY
			su.[UserNameID],su.FirstName,su.LastName 
			---------------------------------------------------------------------------------------
			UNION ALL

			SELECT
				  su.[UserNameID] AS CashierId,
				  su.FirstName+' '+ISNULL(su.LastName,'') AS CasierName, 
				  0 AS [SalesAmount],
				  sum(f.Pos3rdPartySalesAmount) AS Pos3rdPartySalesAmount,
				  0 AS [ReturnAmount],
				  sum(f.Pos3rdPartyReturnAmount) AS Pos3rdPartyReturnAmount,
				  0 as NumberOfReceiptsWithReturn,
				  0 as NumberOfArticlesInReturn,
				  0 AS NumberOfReceiptsWithReturnPerSelectedArticle,
				  SUM(NumberOfReceiptsWithGenericGtinInReturn) AS NumberOfReceiptsWithGenericGtinInReturn,
				  SUM(NumberOfArticlesWithGenericGtinInReturn) AS NumberOfArticlesWithGenericGtinInReturn,
				  SUM(GenericGtinReturnAmount) ASGenericGtinReturnAmount

			FROM [BI_Mart].[RBIM].[Agg_CashierSalesAndReturnPerHour] f
				 join rbim.Dim_Date dd on dd.DateIdx = f.ReceiptDateIdx -- Mandatory
				inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
				 join rbim.Dim_User su on su.UserIdx = f.CashierUserIdx

			Where (
				(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
				or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
				or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				)
			--and da.ArticleIdx > -1 		-- needs to be included if you should exclude LADs etc.
											-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
			GROUP BY
			su.[UserNameID],su.FirstName,su.LastName 

			)	sub
			GROUP BY
				 sub.CashierId
				,sub.CasierName
		)
		
	select * from SelectedSales
end

go
