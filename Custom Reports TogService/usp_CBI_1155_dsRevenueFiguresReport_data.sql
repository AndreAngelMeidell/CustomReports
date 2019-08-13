USE [BI_Mart]
GO

if (object_id('dbo.usp_CBI_1155_dsRevenueFiguresReport_data') is not null)
	drop procedure dbo.usp_CBI_1155_dsRevenueFiguresReport_data
go

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE dbo.usp_CBI_1155_dsRevenueFiguresReport_data
(   
	@StoreOrGroupNo				varchar(max)
	,@PeriodType				varchar(1) 
	,@DateFrom					datetime 
	,@DateTo					datetime 
	,@YearToDate				integer 
	,@RelativePeriodType		varchar(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer 	
	,@ExcludeBottleDeposit		integer
	,@ExcludeThirdPartyArticles	integer
	,@GtinFrom					varchar(50) = null
	,@GtinTo					varchar(50) = null		
	,@GroupBy					varchar(50) = 'Month' --Month Week WeekDay Supplier ArticleHierachy Article
	,@ArticleIdFrom				varchar(50) = null
	,@ArticleIdTo				varchar(50) = null
	,@BrandIdFrom				varchar(50) = null
	,@BrandIdTo					varchar(50) = null
	,@ArticleHierarchyIdFrom	varchar(50) = null
	,@ArticleHierarchyIdTo		varchar(50) = null
	,@ArticleSelectionId		varchar(1000) = null 
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

;WITH ArticlesInSelection as 
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
	select 
		 dd.[YearMonthNumber]
		,dd.[YearWeekNumber]
		,dsup.[SupplierName]
		,da.[Lev1ArticleHierarchyName]
		,da.[ArticleName]
		,isnull(g.Gtin, '') AS Gtin
		,dd.FullDate   
		,(f.[NumberOfArticlesSold]-f.[NumberOfArticlesInReturn]) AS Quantity -- Antall                -- RS-27090
		,(f.[SalesAmount] + f.[ReturnAmount]) AS SalesRevenueInclVat			-- Omsetning	      -- RS-26947
		,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS SalesRevenue	-- Netto Omsetning	      -- RS-26947
		,f.[GrossProfit] AS GrossProfit -- Brutto Kroner, SUM(f.SalesAmountExclVat) AS [SalesAmountExclVat] 
		,f.[SalesPrice]+f.[ReturnAmount] AS [Price] -- Pris                                          -- RS-27090
		--,(f.NetPurchasePriceDerived + f.NetPurchasePrice) AS [PurchaseAmount]-- Innverdi		      -- RS-26947
		,f.CostOfGoods AS CostOfGoods -- Innverdi										              -- RS-26947 RS-27090
		,f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat  AS [SalesRevenueVat] -- MVA kroner
		,f.IsDerivedNetPriceUsed
		,f.UseDerivedNetPrice
	from
		BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
	join rbim.Dim_Date dd on dd.DateIdx = f.ReceiptDateIdx 
	join rbim.Dim_Article da on da.ArticleIdx = f.ArticleIdx AND LEN(da.ArticleId) < 19
	join rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx
	left join RBIM.Dim_Gtin g ON g.GtinIdx = f.gtinIdx
	join Stores ds on ds.StoreIdx = f.StoreIdx
	where 
		--  filter on period
		(
		(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
		or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
		or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
		or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
		or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
		or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
		or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
		)
	--Filter on excluding third party articles
	and ((@ExcludeThirdPartyArticles = 1  AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR  @ExcludeThirdPartyArticles = 0) 

	--Filter on excluding bottle deposit articles
	and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)					
					
	--Filter on ArticleId	
	and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdFrom END AS BIGINT) 
	and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdTo END AS BIGINT) 
		
	--Filter on GTIN
	and (@GtinFrom IS NULL OR CAST(ISNULL(g.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(g.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	

	--Filter on BrandId
	and (@BrandIdFrom IS NULL OR ISNULL(da.BrandId,@BrandIdFrom) >= CAST(@BrandIdFrom AS Varchar(100)) and @BrandIdTo IS NULL OR ISNULL(da.BrandId,@BrandIdTo) <= CAST(@BrandIdTo AS Varchar(100)))

	--Filter on ArticleHierarchyId			
	and (@ArticleHierarchyIdFrom is null or isnull(da.Lev1ArticleHierarchyId,@ArticleHierarchyIdFrom) >= cast(@ArticleHierarchyIdFrom AS Varchar(100)) and @ArticleHierarchyIdTo IS NULL OR ISNULL(da.Lev1ArticleHierarchyId,@ArticleHierarchyIdTo) <= CAST(@ArticleHierarchyIdTo AS Varchar(100)))

	--Filter on ArticleSelection
	and (@ArticleSelectionId is null or da.ArticleIdx in (select * from ArticlesInSelection))				
	)

---------------------------------------------------------
	(
	SELECT 
		ArticleName						'GroupedBy'
		,NULL							'GroupedBy2'
		,CONVERT(VARCHAR(50),Gtin)		'Gtin'
		,SUM(Quantity)					'Quantity'
		,SUM(SalesRevenueInclVat)		'SalesRevenueInclVat'
		,SUM(SalesRevenue)				'SalesRevenue'
		,SUM(GrossProfit)				'GrossProfit' 
		,SUM(Price)						'Price'
		,SUM(CostOfGoods)				'CostOfGoods'
		,SUM(SalesRevenueVat)			'SalesRevenueVat'
		,MIN(UseDerivedNetPrice)		'UseDerivedNetPrice'
		,MIN(IsDerivedNetPriceUsed)		'MINIsDerivedNetPriceUsed'
		,MAX(IsDerivedNetPriceUsed)		'MAXIsDerivedNetPriceUsed'
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed)+MAX(IsDerivedNetPriceUsed)	'Config'
	FROM
		SelectedSales
	WHERE
		@GroupBy = 'Article'
	GROUP BY
		ArticleName
		,Gtin
	) 
UNION 
	(
	SELECT 
		NULL							'GroupedBy'
		,FullDate						'GroupedBy2'
		, ''							'Gtin'
		,SUM(Quantity)					'Quantity'
		,SUM(SalesRevenueInclVat)		'SalesRevenueInclVat'
		,SUM(SalesRevenue)				'SalesRevenue'
		,SUM(GrossProfit)               'GrossProfit' 
		,SUM(Price)                     'Price'
		,SUM(CostOfGoods)               'CostOfGoods'
		,SUM(SalesRevenueVat)           'SalesRevenueVat'
		,MIN(UseDerivedNetPrice)        'UseDerivedNetPrice'
		,MIN(IsDerivedNetPriceUsed)     'MINIsDerivedNetPriceUsed'
		,MAX(IsDerivedNetPriceUsed)     'MAXIsDerivedNetPriceUsed'
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed)+MAX(IsDerivedNetPriceUsed)	'Config'
		FROM SelectedSales
		WHERE @GroupBy = 'WeekDay'
		GROUP BY FullDate
	)
UNION
	(
	SELECT 
		CASE @GroupBy 
				WHEN 'Supplier' THEN SupplierName
				WHEN 'ArticleHierarchy' THEN Lev1ArticleHierarchyName
				WHEN 'Month' THEN CONVERT(VARCHAR(10),yearMonthNumber)
				WHEN 'Week' THEN CONVERT(VARCHAR(10),yearWeekNumber)
		END								'GroupedBy'
		,NULL                           'GroupedBy2'
		,''                             'Gtin'
		,SUM(Quantity)                  'Quantity'
		,SUM(SalesRevenueInclVat)       'SalesRevenueInclVat'
		,SUM(SalesRevenue)              'SalesRevenue'
		,SUM(GrossProfit)               'GrossProfit' 
		,SUM(Price)                     'Price'
		,SUM(CostOfGoods)               'CostOfGoods'
		,SUM(SalesRevenueVat)           'SalesRevenueVat'
		,MIN(UseDerivedNetPrice)        'UseDerivedNetPrice'
		,MIN(IsDerivedNetPriceUsed)     'MINIsDerivedNetPriceUsed'
		,MAX(IsDerivedNetPriceUsed)     'MAXIsDerivedNetPriceUsed'
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed) +MAX(IsDerivedNetPriceUsed)	'Config'
		FROM SelectedSales
		WHERE @GroupBy IN ('Supplier', 'ArticleHierarchy','Month','Week')
		GROUP BY CASE @GroupBy 
				WHEN 'Supplier' THEN SupplierName
				WHEN 'ArticleHierarchy' THEN Lev1ArticleHierarchyName
				WHEN 'Month' THEN CONVERT(VARCHAR(10),yearMonthNumber)
				WHEN 'Week' THEN CONVERT(VARCHAR(10),yearWeekNumber)
		END
	)
ORDER BY
	GroupedBy
	,GroupedBy2

-------------------------------------------------------------------------------------------------------
END


GO


