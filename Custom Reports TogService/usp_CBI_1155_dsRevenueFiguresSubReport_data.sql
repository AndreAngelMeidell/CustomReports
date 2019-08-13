USE BI_Mart
GO

if (object_id('dbo.usp_CBI_1155_dsRevenueFiguresSubReport_data') is not null)
	drop procedure dbo.usp_CBI_1155_dsRevenueFiguresSubReport_data
go


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE dbo.usp_CBI_1155_dsRevenueFiguresSubReport_data
(   
	@StoreOrGroupNo				varchar(max)
	,@PeriodType				char(1) 
	,@DateFrom					datetime 
	,@DateTo					datetime 
	,@YearToDate				integer 
	,@RelativePeriodType		char(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer 	
	,@ExcludeBottleDeposit		integer
	,@ExcludeThirdPartyArticles	integer
    ,@GtinFrom					varchar(50)
	,@GtinTo					varchar(50)		
	,@GroupBy					varchar(50) = 'Month' --Month Week WeekDay Supplier ArticleHierachy Article
	,@FilterBy					varchar(100) = ''
	,@ArticleIdFrom				varchar(50) = NULL
	,@ArticleIdTo				varchar(50) = NULL
	,@BrandIdFrom				varchar(50) = NULL
	,@BrandIdTo					varchar(50) = NULL
	,@ArticleHierarchyIdFrom	varchar(50) = NULL
	,@ArticleHierarchyIdTo		varchar(50) = NULL
	,@ArticleSelectionId		varchar(1000) = NULL
) 
AS  
BEGIN

SET @ArticleIdFrom = CASE WHEN RTRIM(LTRIM(@ArticleIdFrom)) = '' THEN NULL ELSE @ArticleIdFrom END;
SET @ArticleIdTo = CASE WHEN RTRIM(LTRIM(@ArticleIdTo)) = '' THEN NULL ELSE @ArticleIdTo END;
SET @GtinFrom = CASE WHEN RTRIM(LTRIM(@GtinFrom)) = '' THEN NULL ELSE @GtinFrom END;
SET @GtinTo = CASE WHEN RTRIM(LTRIM(@GtinTo)) = '' THEN NULL ELSE @GtinTo END;   
SET @BrandIdFrom = CASE WHEN RTRIM(LTRIM(@BrandIdFrom)) = '' THEN NULL ELSE @BrandIdFrom END;
SET @BrandIdTo = CASE WHEN RTRIM(LTRIM(@BrandIdTo)) = '' THEN NULL ELSE @BrandIdTo END;
SET @ArticleHierarchyIdFrom = CASE WHEN RTRIM(LTRIM(@ArticleHierarchyIdFrom)) = '' THEN NULL ELSE @ArticleHierarchyIdFrom END;
SET @ArticleHierarchyIdTo = CASE WHEN RTRIM(LTRIM(@ArticleHierarchyIdTo)) = '' THEN NULL ELSE @ArticleHierarchyIdTo END;    
------------------------------------------------------------------------------------------------------

;WITH ArticlesInSelection AS 
	(
	select
		cas.ArticleIdx
	from
		RBIM.Dim_ArticleSelection das
	left join RBIM.Cov_ArticleSelection cas on cas.ArticleSelectionIdx = das.ArticleSelectionIdx
	where
		das.ArticleSelectionId = @ArticleSelectionId
	)
,Stores as
	(
	select
		distinct ds.*	--(RS-27332)
	from
		RBIM.Dim_Store ds
	left join ( select ParameterValue from [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  on n.ParameterValue in (
							ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
							ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
							ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
							ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
							ds.StoreId) 
	where
			n.ParameterValue is not null
		and ds.IsCurrentStore=1		--to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)
	) 
, SelectedSales as
	(
	SELECT 
		 dd.[YearMonthNumber]
		,dd.[YearWeekNumber]
		,dsup.[SupplierName]
		,ISNULL(b.Gtin, '') AS Gtin
		,da.[Lev1ArticleHierarchyName]
		,da.[ArticleName]
		,da.[ArticleId]
		,dd.FullDate
		,SUM(f.[NumberOfArticlesSold])-SUM(f.[NumberOfArticlesInReturn]) AS Quantity -- Antall                    -- RS-27090
		,SUM(f.[SalesAmount] + f.ReturnAmount) AS SalesRevenueInclVat	           -- Omsetning		              -- RS-26940
		,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat) AS  SalesRevenue --Netto Omsetning                   -- RS-26940
		,SUM(f.[GrossProfit]) AS GrossProfit -- Brutto Kroner,SUM(f.SalesAmountExclVat) AS [SalesAmountExclVat]   -- RS-26940 
		,SUM(f.[SalesPrice])+SUM(f.[ReturnAmount]) AS [Price] --Pris                                              -- RS-27090
		,SUM(f.[CostOfGoods]) AS CostOfGoods -- Innverdi                                                          -- RS-26940 -- RS-27090
		,SUM(f.[SalesVatAmount]) + SUM(f.[ReturnAmount]) - SUM(f.[ReturnAmountExclVat]) AS [SalesRevenueVat] -- MVA kroner    -- RS-27090
		,MIN(f.UseDerivedNetPrice)								as UseDerivedNetPrice
		,MIN(f.IsDerivedNetPriceUsed)                           as MINIsDerivedNetPriceUsed
		,MAX(f.IsDerivedNetPriceUsed)                           as MAXIsDerivedNetPriceUsed
	FROM
		BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
	join rbim.Dim_Date dd ON dd.DateIdx = f.ReceiptDateIdx 
	join rbim.Dim_Article da ON da.ArticleIdx = f.ArticleIdx AND LEN(da.ArticleId) < 19
	--join rbim.Cov_ArticleGtin cag ON cag.ArticleIdx = da.ArticleIdx
	left join RBIM.Dim_Gtin b ON b.GtinIdx = f.gtinIdx
	left join rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx
	join Stores ds on ds.StoreIdx = f.StoreIdx
	where 
	   /*Removing this because we do not use join with Cov_ArticleGtin. We use Dim_Gtin instead and this is not required to use those filters
		ISNULL(f.IsDefaultGtin,1) = 1
	   */

		--  filter on period
		(
		(@PeriodType='D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo)
		OR (@PeriodType='Y' AND dd.RelativeYTD = @YearToDate)
		OR (@PeriodType='R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
		OR (@PeriodType='R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
		OR (@PeriodType='R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
		OR (@PeriodType='R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
		OR (@PeriodType='R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
		)

	--Filter on excluding third party articles
	and ((@ExcludeThirdPartyArticles = 1  AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR  @ExcludeThirdPartyArticles = 0) 

	--Filter on excluding bottle deposit articles
	and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)				

	--Filter on ArticleId	
	and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdFrom END AS BIGINT) 
	and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdTo END AS BIGINT) 
		
	--Filter on GTIN
	and (@GtinFrom IS NULL OR CAST(ISNULL(B.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(B.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	

	--Filter on BrandId
	and (@BrandIdFrom IS NULL OR ISNULL(da.BrandId,@BrandIdFrom) >= CAST(@BrandIdFrom AS Varchar(100)) and @BrandIdTo IS NULL OR ISNULL(da.BrandId,@BrandIdTo) <= CAST(@BrandIdTo AS Varchar(100)))

	--Filter on ArticleHierarchyId			
	and (@ArticleHierarchyIdFrom IS NULL OR ISNULL(da.Lev1ArticleHierarchyId,@ArticleHierarchyIdFrom) >= CAST(@ArticleHierarchyIdFrom AS Varchar(100)) and @ArticleHierarchyIdTo IS NULL OR ISNULL(da.Lev1ArticleHierarchyId,@ArticleHierarchyIdTo) <= CAST(@ArticleHierarchyIdTo AS Varchar(100)))

	--Filter on ArticleSelection
	AND (@ArticleSelectionId IS NULL OR da.ArticleIdx IN (SELECT * FROM ArticlesInSelection))						
			
	GROUP BY
	 dd.[YearMonthNumber]
	,dd.[YearWeekNumber]
	,dd.[DayNameOfWeek]
	,dd.[DayNumberOfWeek]
	,dsup.[SupplierName]
	,da.[Lev1ArticleHierarchyName]
	,da.[ArticleName]
	,da.[ArticleId]
	,dd.FullDate
	,b.gtin
	)
-------------------------------------------------------------------------------------------------------
SELECT 
ArticleName
,Gtin
,SUM(Quantity) AS Quantity 
,SUM(SalesRevenueInclVat) AS SalesRevenueInclVat
,SUM(SalesRevenue) AS  SalesRevenue 
,SUM(GrossProfit) AS GrossProfit 
,SUM(Price) AS Price
,SUM(CostOfGoods) AS CostOfGoods
,SUM(SalesRevenueVat) AS SalesRevenueVat
			,MIN(UseDerivedNetPrice)+	    MIN(MINIsDerivedNetPriceUsed) +MAX(MAXIsDerivedNetPriceUsed)   as Config
FROM SelectedSales
WHERE(@GroupBy = 'ArticleHierarchy' AND  Lev1ArticleHierarchyName = @FilterBy)
OR (@GroupBy = 'Supplier' AND  SupplierName = @FilterBy)
OR (@GroupBy = 'WeekDay' AND  CONVERT(VARCHAR(10),FullDate) = @FilterBy)
OR (@GroupBy = 'Month' AND CONVERT(VARCHAR(10),YearMonthNumber) = @FilterBy)
OR (@GroupBy = 'Week' AND CONVERT(VARCHAR(10),YearWeekNumber) = @FilterBy)
OR (@GroupBy = 'Article' AND @FilterBy IN (ArticleName, ArticleId))
GROUP BY ArticleName, gtin
ORDER BY articleName

END


GO


