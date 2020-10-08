USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1155_dsRevenueFiguresSubReport_NG_data]    Script Date: 25.09.2020 13:23:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1155_dsRevenueFiguresSubReport_NG_data]
(   
    @StoreId					varchar(100)
	,@PeriodType				varchar(1) 
	,@DateFrom					datetime 
	,@DateTo					datetime 
	,@YearToDate				integer 
	,@RelativePeriodType		char(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer 	
	,@ExcludeBottleDeposit		integer
	,@ExcludeThirdPartyArticles	integer
    ,@GtinFrom					varchar(50) = NULL
	,@GtinTo					varchar(50) = NULL		
	,@GroupBy					varchar(50) = 'Month' --Month Week WeekDay Supplier ArticleHierachy Article Department
	,@FilterBy					varchar(100) = ''
	,@ArticleIdFrom				varchar(50) = NULL
	,@ArticleIdTo				varchar(50) = NULL
	,@BrandIdFrom				varchar(50) = NULL
	,@BrandIdTo					varchar(50) = NULL
	,@ArticleHierarchyIdFrom	varchar(50) = NULL
	,@ArticleHierarchyIdTo		varchar(50) = NULL
	,@ArticleSelectionId		varchar(1000) = NULL 
	,@Departments				varchar(max) = NULL
	,@Monday					bit = 1		--By default Not Excluded
	,@Tuesday					bit = 1		--By default Not Excluded
	,@Wednesday					bit = 1		--By default Not Excluded
	,@Thursday					bit = 1		--By default Not Excluded
	,@Friday					bit = 1		--By default Not Excluded
	,@Saturday					bit = 1		--By default Not Excluded
	,@Sunday					bit = 1		--By default Not Excluded
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

	set @Departments = case when rtrim(ltrim(@Departments)) = '' then null else @Departments end;
	------------------------------------------------------------------------------------------------------

	;WITH ArticlesInSelection AS 
	(
	SELECT
		cas.ArticleIdx
	FROM
		RBIM.Dim_ArticleSelection das
	LEFT JOIN RBIM.Cov_ArticleSelection cas ON cas.ArticleSelectionIdx = das.ArticleSelectionIdx
	WHERE
		das.ArticleSelectionId = @ArticleSelectionId

	)
	, SelectedDepartments as
	(
	select
		ParameterValue
	from
		dbo.ufn_RBI_SplittParameterString(@Departments,',''')
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
		,isnull(nullif(oa.Value_Department,''),'Ukjent')		'Value_Department'
		,SUM(f.[NumberOfArticlesSold])-SUM(f.[NumberOfArticlesInReturn]) AS Quantity -- Antall                    -- RS-27090
		,SUM(f.[SalesAmount] + f.ReturnAmount) AS SalesRevenueInclVat	           -- Omsetning		              -- RS-26940
		,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat) AS  SalesRevenue --Netto Omsetning                   -- RS-26940
		,SUM(f.[GrossProfit]) AS GrossProfit -- Brutto Kroner,SUM(f.SalesAmountExclVat) AS [SalesAmountExclVat]   -- RS-26940 
		,SUM(f.[SalesPrice])+SUM(f.[ReturnAmount]) AS [Price] --Pris                                              -- RS-27090
		,SUM(f.[CostOfGoods]) AS CostOfGoods -- Innverdi                                                          -- RS-26940 -- RS-27090
		,SUM(f.[SalesVatAmount]) + SUM(f.[ReturnAmount]) - SUM(f.[ReturnAmountExclVat]) AS [SalesRevenueVat] -- MVA kroner    -- RS-27090
		,MIN(f.UseDerivedNetPrice)								as UseDerivedNetPrice
		,MIN(f.IsDerivedNetPriceUsedMin)                           as MINIsDerivedNetPriceUsed
		,MAX(f.IsDerivedNetPriceUsedMax)                           as MAXIsDerivedNetPriceUsed
		--,MIN(f.IsDerivedNetPriceUsed)                           as MINIsDerivedNetPriceUsed
		--,MAX(f.IsDerivedNetPriceUsed)                           as MAXIsDerivedNetPriceUsed
	FROM
		BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
	JOIN rbim.Dim_Date dd ON dd.DateIdx = f.ReceiptDateIdx 
	JOIN rbim.Dim_Article da ON da.ArticleIdx = f.ArticleIdx AND LEN(da.ArticleId) < 19
	JOIN rbim.Dim_Store ds ON ds.storeidx = f.storeidx
	--JOIN rbim.Cov_ArticleGtin cag ON cag.ArticleIdx = da.ArticleIdx
	LEFT JOIN RBIM.Dim_Gtin b ON b.GtinIdx = f.gtinIdx
	LEFT JOIN rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx
	left outer join RBIM.Out_ArticleExtraInfo oa on oa.ArticleId=da.ArticleId
	left outer join SelectedDepartments sd on sd.ParameterValue=isnull(nullif(oa.Value_Department,''),'Ukjent')
	WHERE 
		   /*Removing this because we do not use join with Cov_ArticleGtin. We use Dim_Gtin instead and this is not required to use those filters
			ISNULL(f.IsDefaultGtin,1) = 1
		   */
		-- filter on store
			@StoreId = ds.StoreId

		--  filter on period
		and (
			(@PeriodType='D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo)
			OR (@PeriodType='Y' AND dd.RelativeYTD = @YearToDate)
			OR (@PeriodType='R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
			OR (@PeriodType='R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
			OR (@PeriodType='R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
			OR (@PeriodType='R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
			OR (@PeriodType='R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart+@RelativePeriodDuration-1)
			)

		-- Filter on weekday    
		and	(	dd.DayNumberOfWeek = (case when @Monday=   1 then 1 else 0 end)
			or	dd.DayNumberOfWeek = (case when @Tuesday=  1 then 2 else 0 end)
			or	dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
			or	dd.DayNumberOfWeek = (case when @Thursday= 1 then 4 else 0 end)
			or	dd.DayNumberOfWeek = (case when @Friday=   1 then 5 else 0 end)
			or	dd.DayNumberOfWeek = (case when @Saturday= 1 then 6 else 0 end)
			or	dd.DayNumberOfWeek = (case when @Sunday=   1 then 7 else 0 end)
			)

		--AND da.ArticleIdx > -1 		-- needs to be included if you should exclude LADs etc.
		and ds.isCurrentStore = 1   	-- make sure you only get the 'current store' 
										-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 

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
		and (@ArticleSelectionId IS NULL OR da.ArticleIdx IN (SELECT * FROM ArticlesInSelection))						

		-- Filter on Departments
		and (@Departments is null or isnull(oa.ArticleId,'Ukjent')=sd.ParameterValue or (oa.ArticleId is not null and sd.ParameterValue is not null))
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
		,oa.Value_Department
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
		,MIN(UseDerivedNetPrice)+MIN(MINIsDerivedNetPriceUsed)+MAX(MAXIsDerivedNetPriceUsed)   as Config
	FROM
		SelectedSales
	WHERE
			(@GroupBy = 'ArticleHierarchy'	and	Lev1ArticleHierarchyName				= @FilterBy)
		or	(@GroupBy = 'Supplier'			and	SupplierName							= @FilterBy)
		or	(@GroupBy = 'WeekDay'			and	convert(varchar(10),FullDate)			= @FilterBy)
		or	(@GroupBy = 'Month'				and	convert(varchar(10),YearMonthNumber)	= @FilterBy)
		or	(@GroupBy = 'Week'				and	convert(varchar(10),YearWeekNumber)		= @FilterBy)
		or	(@GroupBy = 'Article'			and	@FilterBy in (ArticleName, ArticleId))
		or	(@GroupBy = 'Department'		and	Value_Department						= @FilterBy)
	GROUP BY
		ArticleName
		,gtin
	ORDER BY
		articleName
END


GO

