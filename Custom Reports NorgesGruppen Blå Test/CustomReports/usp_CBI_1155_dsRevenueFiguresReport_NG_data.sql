USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1155_dsRevenueFiguresReport_NG_data]    Script Date: 27.09.2020 11:58:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1155_dsRevenueFiguresReport_NG_data]
(   
    @StoreId					varchar(100)
	,@PeriodType				varchar(1) 
	,@DateFrom					datetime 
	,@DateTo					datetime 
	,@YearToDate				integer 
	,@RelativePeriodType		varchar(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer 	
	,@ExcludeBottleDeposit		integer
	,@ExcludeThirdPartyArticles	integer
    ,@GtinFrom					varchar(50) = NULL
	,@GtinTo					varchar(50) = NULL		
	,@GroupBy					varchar(50) = 'Month' --Month Week WeekDay Supplier ArticleHierachy Article Department Day
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
		,da.[Lev1ArticleHierarchyName]
		,da.[ArticleName]
		,ISNULL(g.Gtin, '') AS Gtin
		,dd.FullDate 
		,isnull(nullif(oa.Value_Department,''),'Ukjent')		'Value_Department'
		,dd.DayNumberOfWeek
		,dd.DayNameOfWeek
		,(f.[NumberOfArticlesSold]-f.[NumberOfArticlesInReturn]) AS Quantity -- Antall                -- RS-27090
		,(f.[SalesAmount] + f.[ReturnAmount]) AS SalesRevenueInclVat			-- Omsetning	      -- RS-26947
		,(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS SalesRevenue	-- Netto Omsetning	      -- RS-26947
		, f.[GrossProfit] AS GrossProfit -- Brutto Kroner, SUM(f.SalesAmountExclVat) AS [SalesAmountExclVat] 
		, f.[SalesPrice]+f.[ReturnAmount] AS [Price] -- Pris                                          -- RS-27090
		--,(f.NetPurchasePriceDerived + f.NetPurchasePrice) AS [PurchaseAmount]-- Innverdi		      -- RS-26947
		,f.CostOfGoods AS CostOfGoods -- Innverdi										              -- RS-26947 RS-27090
		,f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat  AS [SalesRevenueVat] -- MVA kroner
		--,f.IsDerivedNetPriceUsed
		,0 AS IsDerivedNetPriceUsed
		,f.UseDerivedNetPrice
	FROM
		BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
	JOIN rbim.Dim_Date dd on dd.DateIdx = f.ReceiptDateIdx 
	JOIN rbim.Dim_Article da on da.ArticleIdx = f.ArticleIdx AND LEN(da.ArticleId) < 19
	JOIN rbim.Dim_Store ds on ds.storeidx = f.storeidx
	JOIN rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx
	--LEFT JOIN rbim.Cov_ArticleGtin cag ON cag.ArticleIdx = da.ArticleIdx
	LEFT JOIN RBIM.Dim_Gtin g ON g.GtinIdx = f.gtinIdx
	left outer join RBIM.Out_ArticleExtraInfo oa on oa.ArticleId=da.ArticleId
	left outer join SelectedDepartments sd on sd.ParameterValue=isnull(nullif(oa.Value_Department,''),'Ukjent')
	WHERE 
		/*Removing this because we do not use join with Cov_ArticleGtin. We use Dim_Gtin instead and this is not required to use those filters
		  ISNULL(f.IsDefaultGtin,1) = 1
		  AND ISNULL(g.isCurrent, 1) = 1  
		*/
		-- Filter on store
			@StoreId = ds.StoreId
		--  Filter on period
		AND (
			(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
			or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
			or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
			or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
			or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
			or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
			or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
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

		--and da.ArticleIdx > -1 		-- needs to be included if you should exclude LADs etc.
		and ds.isCurrentStore = 1   	-- make sure you only get the 'current store' 
										-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 

		-- Filter on excluding third party articles
		and ((@ExcludeThirdPartyArticles = 1  AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR  @ExcludeThirdPartyArticles = 0) 

		-- Filter on excluding bottle deposit articles
		and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)					
						
		-- Filter on ArticleId	
		and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdFrom END AS BIGINT) 
		and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdTo END AS BIGINT) 
			
		-- Filter on GTIN
		and (@GtinFrom IS NULL OR CAST(ISNULL(g.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(g.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	

		-- Filter on BrandId
		and (@BrandIdFrom IS NULL OR ISNULL(da.BrandId,@BrandIdFrom) >= CAST(@BrandIdFrom AS Varchar(100)) and @BrandIdTo IS NULL OR ISNULL(da.BrandId,@BrandIdTo) <= CAST(@BrandIdTo AS Varchar(100)))

		-- Filter on ArticleHierarchyId			
		and (@ArticleHierarchyIdFrom IS NULL OR ISNULL(da.Lev1ArticleHierarchyId,@ArticleHierarchyIdFrom) >= CAST(@ArticleHierarchyIdFrom AS Varchar(100)) and @ArticleHierarchyIdTo IS NULL OR ISNULL(da.Lev1ArticleHierarchyId,@ArticleHierarchyIdTo) <= CAST(@ArticleHierarchyIdTo AS Varchar(100)))

		-- Filter on ArticleSelection
		AND (@ArticleSelectionId IS NULL OR da.ArticleIdx IN (SELECT * FROM ArticlesInSelection))

		-- Filter on Departments
		and (@Departments is null or isnull(oa.ArticleId,'Ukjent')=sd.ParameterValue or (oa.ArticleId is not null and sd.ParameterValue is not null))
	)

	---------------------------------------------------------
	(
	SELECT 
		NULL																			as DayNrGroupedBy
		,ArticleName																	as GroupedBy
		,NULL																			as GroupedBy2
		,CONVERT(VARCHAR(50),Gtin)														as Gtin
		,SUM(Quantity)																	as Quantity 
		,SUM(SalesRevenueInclVat)														as SalesRevenueInclVat	-- RS-26947
		,SUM(SalesRevenue)																as SalesRevenue			-- RS-26947
		,SUM(GrossProfit)																as GrossProfit 
		,SUM(Price)																		as [Price]
		,SUM(CostOfGoods)																as CostOfGoods			-- RS-26947 RS-27090
		,SUM(SalesRevenueVat)															as SalesRevenueVat
		,MIN(UseDerivedNetPrice)														as UseDerivedNetPrice
		,MIN(IsDerivedNetPriceUsed)														as MINIsDerivedNetPriceUsed
		,MAX(IsDerivedNetPriceUsed)														as MAXIsDerivedNetPriceUsed
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed)+MAX(IsDerivedNetPriceUsed)	as Config
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
		NULL																			as DayNrGroupedBy
		,NULL																			as GroupedBy
		,FullDate																		as GroupedBy2
		, ''																			as Gtin
		,SUM(Quantity)																	as Quantity 
		,SUM(SalesRevenueInclVat)														as SalesRevenueInclVat	-- RS-26947
		,SUM(SalesRevenue) 																as SalesRevenue			-- RS-26947
		,SUM(GrossProfit)																as GrossProfit 
		,SUM(Price)																		as [Price]
		,SUM(CostOfGoods)																as CostOfGoods			-- RS-26947 RS-27090
		,SUM(SalesRevenueVat)															as SalesRevenueVat 
		,MIN(UseDerivedNetPrice)														as UseDerivedNetPrice
		,MIN(IsDerivedNetPriceUsed)														as MINIsDerivedNetPriceUsed
		,MAX(IsDerivedNetPriceUsed)														as MAXIsDerivedNetPriceUsed
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed)+MAX(IsDerivedNetPriceUsed)	as Config
		FROM
			SelectedSales
		WHERE
			@GroupBy = 'WeekDay'
		GROUP BY
			FullDate
	)
	UNION
	(
	SELECT 
		DayNumberOfWeek																	as DayNrGroupedBy
		,DayNameOfWeek																	as GroupedBy
		,NULL																			as GroupedBy2
		,''																				as Gtin
		,SUM(Quantity)																	as Quantity 
		,SUM(SalesRevenueInclVat)														as SalesRevenueInclVat	-- RS-26947
		,SUM(SalesRevenue)																as SalesRevenue			-- RS-26947
		,SUM(GrossProfit)																as GrossProfit 
		,SUM(Price)																		as [Price]
		,SUM(CostOfGoods)																as CostOfGoods			-- RS-26947
		,SUM(SalesRevenueVat)															as SalesRevenueVat
		,MIN(UseDerivedNetPrice)														as UseDerivedNetPrice
		,MIN(IsDerivedNetPriceUsed)														as MINIsDerivedNetPriceUsed
		,MAX(IsDerivedNetPriceUsed)														as MAXIsDerivedNetPriceUsed
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed)+MAX(IsDerivedNetPriceUsed)	as Config
	FROM
		SelectedSales
	WHERE
		@GroupBy = 'Day'
	GROUP BY
		DayNumberOfWeek	
		,DayNameOfWeek	
	)
	UNION
	(
	SELECT 
		NULL																			as DayNrGroupedBy
		,CASE @GroupBy 
			WHEN 'Supplier'			THEN SupplierName
			WHEN 'ArticleHierarchy' THEN Lev1ArticleHierarchyName
			WHEN 'Month'			THEN CONVERT(VARCHAR(10),yearMonthNumber)
			WHEN 'Week'				THEN CONVERT(VARCHAR(10),yearWeekNumber)
			WHEN 'Department'		THEN Value_Department
		END																				as GroupedBy
		,NULL																			as GroupedBy2
		,''																				as Gtin
		,SUM(Quantity)																	as Quantity 
		,SUM(SalesRevenueInclVat)														as SalesRevenueInclVat	-- RS-26947
		,SUM(SalesRevenue)																as SalesRevenue			-- RS-26947
		,SUM(GrossProfit)																as GrossProfit 
		,SUM(Price)																		as [Price]
		,SUM(CostOfGoods)																as CostOfGoods			-- RS-26947
		,SUM(SalesRevenueVat)															as SalesRevenueVat
		,MIN(UseDerivedNetPrice)														as UseDerivedNetPrice
		,MIN(IsDerivedNetPriceUsed)														as MINIsDerivedNetPriceUsed
		,MAX(IsDerivedNetPriceUsed)														as MAXIsDerivedNetPriceUsed
		,MIN(UseDerivedNetPrice)+MIN(IsDerivedNetPriceUsed)+MAX(IsDerivedNetPriceUsed)	as Config
	FROM
		SelectedSales
	WHERE
		@GroupBy IN ('Supplier','ArticleHierarchy','Month','Week','Department')
	GROUP BY
		CASE @GroupBy 
			WHEN 'Supplier'			THEN SupplierName
			WHEN 'ArticleHierarchy'	THEN Lev1ArticleHierarchyName
			WHEN 'Month'			THEN CONVERT(VARCHAR(10),yearMonthNumber)
			WHEN 'Week'				THEN CONVERT(VARCHAR(10),yearWeekNumber)
			WHEN 'Department'		THEN Value_Department
		END
	)
	ORDER BY
		DayNrGroupedBy
		,GroupedBy
		,GroupedBy2
	-------------------------------------------------------------------------------------------------------
END


GO

