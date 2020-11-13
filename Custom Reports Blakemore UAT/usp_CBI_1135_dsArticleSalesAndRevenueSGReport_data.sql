USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]    Script Date: 13.11.2020 08:44:10 ******/
DROP PROCEDURE [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]    Script Date: 13.11.2020 08:44:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [dbo].[usp_CBI_1135_dsArticleSalesAndRevenueSGReport_data]
(   
    @StoreOrGroupNo AS VARCHAR(MAX),
	--@PeriodType AS VARCHAR(1), --(RS-27896)
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@StoreGroupCategory AS INTEGER,
	@GroupBy VARCHAR(MAX) = 'Article', -- StoreGroup, Article, ArticleHierarchy
	@Filter VARCHAR(MAX) = NULL,
	@Monday AS SMALLINT = 1,
	@Tuesday AS SMALLINT = 1,
	@Wednesday AS SMALLINT = 1,
	@Thursday AS SMALLINT = 1,
	@Friday AS SMALLINT = 1,
	@Saturday AS SMALLINT = 1,
	@Sunday AS SMALLINT = 1,
	@Department AS VARCHAR(MAX),
	@Manufacturer AS VARCHAR(MAX),
	@ArticleSelectionId AS VARCHAR(MAX),
	@ArticleHierarchies AS VARCHAR(MAX) ,
	@ExcludeDownPricing AS BIT = 0,
--	@Lev1toLev4ArticleHierarchyId AS VARCHAR(MAX) = NULL, --{RS-35269}
	@SalesUnitTypeName AS VARCHAR(MAX)


) 
AS  
BEGIN
  
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial report load improvement
END
ELSE BEGIN
------------------------------------------------------------------------------------------------------------------------
DECLARE @QueryString  NVARCHAR(max) =''
DECLARE @AggTableToUse VARCHAR(255) 
DECLARE @GroupBycolums VARCHAR(max)
DECLARE @ListOfStores NVARCHAR(max) =''
DECLARE @StoreGroupHierarchyDynamicColumns VARCHAR(500)
DECLARE @StoreGroupHierarchyGroupByColumns VARCHAR(500)
DECLARE @DynamicColumns VARCHAR(max)
DECLARE @SalesUnitTypeFilter VARCHAR(MAX) = ''
DECLARE @OrderBy VARCHAR(MAX) = 'Lev1Name'
DECLARE @SalesUnitColumns VARCHAR(MAX) = ''
DECLARE @GroupBySalesUnitType VARCHAR(MAX) = ''

IF (@GroupBy = 'StoreGroup')
BEGIN
	SET @OrderBy= 'Store, Lev5Name, Lev4Name, Lev3Name, Lev2Name, Lev1Name '
END

--Parameters definitions for -------------------------------------------------------------------------------------------
DECLARE @ParamDefinition NVARCHAR(max)
    SET @ParamDefinition = N'@inp_StoreOrGroupNo varchar(max), @inp_Filter VARCHAR(100), @inp_Monday SMALLINT, @inp_Tuesday SMALLINT, @inp_Wednesday SMALLINT, @inp_Thursday SMALLINT, @inp_Friday SMALLINT, @inp_Saturday SMALLINT, @inp_Sunday SMALLINT, @inp_Department VARCHAR(MAX), @inp_Manufacturer VARCHAR(MAX), @inp_ExcludeDownPricing BIT, @inp_ArticleHierarchies VARCHAR(MAX), @inp_ArticleSelectionId VARCHAR(MAX),  @SalesUnitTypeName VARCHAR(MAX)'
  --SET @ParamDefinition = N'@inp_DateIdxBegin int, @inp_DateIdxEnd int'
      
------------------------------------------------------------------------------------------------------------------------
DECLARE @out_Agg CHAR(1); -- aggregation level to use 
DECLARE @DateIdxBegin INT;
DECLARE @DateIdxEnd INT;

--(N) - No specific period is requested so either Day(D) either Month(M) aggregation level will be returned.
EXECUTE [dbo].[usp_RBI_GetBestAggSalesAndReturnToUse] 
   @inp_DateRangeBegin	    = @DateFrom
  ,@inp_DateRangeEnd		= @DateTo 
  ,@inp_PeriodGranularity   = 'D'  
  ,@out_DateIdxBegin        = @DateIdxBegin OUTPUT
  ,@out_DateIdxEnd          = @DateIdxEnd OUTPUT
  ,@out_Agg                 = @out_Agg OUTPUT  

/* Test parameters */
--print  @out_Agg 
--print  @DateIdxBegin 
--print  @DateIdxEnd 
------------------------------------------------------------------------------------------------------------------------
--------IF @out_Agg = 'D' 
 SET  @AggTableToUse='RBIM.Agg_SalesAndReturnPerDay' 
--------ELSE IF @out_Agg = 'M' 
--------SET  @AggTableToUse='RBIM.Agg_SalesAndReturnPerMonth' 

------------------------------------------------------------------------------------------------------------------------
/*DECLARE @GroupByHierarchy VARCHAR(100)
SET @GroupByHierarchy = CASE @StoreGroupCategory WHEN 1 THEN 'Store'
													WHEN 2 THEN 'RegionHierarchy'
													WHEN 3 THEN 'LegalHierarchy'
													WHEN 11 THEN 'ChainHierarchy'
													WHEN 12 THEN 'DistrictHierarchy' END*/
	SET @Department = NULLIF(REPLACE(@Department,'[]',''),'')
	SET @Manufacturer = NULLIF(REPLACE(@Manufacturer,'[]',''),'')
	SET @ArticleSelectionId = NULLIF(REPLACE(@ArticleSelectionId,'[]',''),'')
	SET @ArticleHierarchies = NULLIF(REPLACE(@ArticleHierarchies,'[]',''),'')
	SET @ExcludeDownPricing = ISNULL(@ExcludeDownPricing,0)
------------------------------------------------------------------------------------------------------------------------
-- CTE contains stores that meets filtering requirements and flag IsCurrentStore=1
---{RS-36137}
SET  @ListOfStores  ='
		DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = ''IncludeInReportsCurrentStoreOnly''
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1);

		CREATE TABLE #Stores(StoreIdx int)
		INSERT INTO  #Stores
		SELECT DISTINCT ds.StoreIdx	
		FROM RBIM.Dim_Store ds
		LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@inp_StoreOrGroupNo,'','')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
       WHERE n.ParameterValue IS NOT NULL and (@IncludeInReportsCurrentStoreOnly= 0 or IsCurrentStore = 1)'
---{RS-36137}

SET @StoreGroupHierarchyDynamicColumns =
CASE @StoreGroupCategory
	WHEN  2 THEN 'NULLIF(ds.Lev1RegionGroupName,'''')    AS Lev1Name, NULLIF(ds.Lev2RegionGroupName,'''')     AS Lev2Name, NULLIF(ds.Lev3RegionGroupName,'''')     AS Lev3Name, NULLIF(ds.Lev4RegionGroupName,'''')     AS Lev4Name, NULLIF(ds.Lev5RegionGroupName,'''')     AS Lev5Name, ds.NumOfRegionLevels AS NumOfLevels' 
	WHEN  3 THEN 'NULLIF(ds.Lev1ChainGroupName,'''')     AS Lev1Name, NULLIF(ds.Lev2ChainGroupName,'''')      AS Lev2Name, NULLIF(ds.Lev3ChainGroupName,'''')      AS Lev3Name, NULLIF(ds.Lev4ChainGroupName,'''')      AS Lev4Name, NULLIF(ds.Lev5ChainGroupName,'''')      AS Lev5Name, ds.NumOfRegionLevels AS NumOfLevels' 
	WHEN 11 THEN 'NULLIF(ds.Lev1LegalGroupName,'''')     AS Lev1Name, NULLIF(ds.Lev2LegalGroupName,'''') 	  AS Lev2Name, NULLIF(ds.Lev3LegalGroupName,'''')      AS Lev3Name, NULLIF(ds.Lev4LegalGroupName,'''')      AS Lev4Name, NULLIF(ds.Lev5LegalGroupName,'''')      AS Lev5Name, ds.NumOfRegionLevels AS NumOfLevels' 
	WHEN 12 THEN 'NULLIF(ds.Lev1DistrictGroupName,'''')  AS Lev1Name, NULLIF(ds.Lev2DistrictGroupName,'''')   AS Lev2Name, NULLIF(ds.Lev3DistrictGroupName,'''')   AS Lev3Name, NULLIF(ds.Lev4DistrictGroupName,'''')   AS Lev4Name, NULLIF(ds.Lev5DistrictGroupName,'''')   AS Lev5Name, ds.NumOfRegionLevels AS NumOfLevels' 
	WHEN  1 THEN 'NULL AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,0 AS NumOfLevels'
END

---{RS-36137}
SET @StoreGroupHierarchyGroupByColumns =
CASE @StoreGroupCategory
	WHEN  2 THEN 'ds.Lev1RegionGroupName,ds.Lev2RegionGroupName,ds.Lev3RegionGroupName,ds.Lev4RegionGroupName,ds.Lev5RegionGroupName,ds.NumOfRegionLevels,ds.CurrentStoreName,ds.StoreId' 
	WHEN  3 THEN 'ds.Lev1ChainGroupName,ds.Lev2ChainGroupName,ds.Lev3ChainGroupName,ds.Lev4ChainGroupName,ds.Lev5ChainGroupName,ds.NumOfRegionLevels,ds.CurrentStoreName,ds.StoreId' 
	WHEN 11 THEN 'ds.Lev1LegalGroupName,ds.Lev2LegalGroupName,ds.Lev3LegalGroupName,ds.Lev4LegalGroupName,ds.Lev5LegalGroupName,ds.NumOfRegionLevels,ds.CurrentStoreName,ds.StoreId' 
	WHEN 12 THEN 'ds.Lev1DistrictGroupName, ds.Lev2DistrictGroupName, ds.Lev3DistrictGroupName, ds.Lev4DistrictGroupName, ds.Lev5DistrictGroupName, ds.NumOfRegionLevels,ds.CurrentStoreName,ds.StoreId' 
	WHEN  1 THEN 'ds.CurrentStoreName,ds.StoreId'
END


----- {RS-37396}
SET @SalesUnitTypeName = RTRIM(LTRIM(@SalesUnitTypeName))

IF (@SalesUnitTypeName IS NOT NULL AND @SalesUnitTypeName <> 'NULL' AND @SalesUnitTypeName <>'') -- {RS-39514}
BEGIN	
	SET @SalesUnitTypeFilter =  'AND (da.SalesUnitTypeId in (SELECT value FROM string_split(@SalesUnitTypeName,'','')))' -- {RS-39514}

	SET @SalesUnitColumns  = 
	'
	,SUM(f.[MeasuredSalesUnitsSold]-f.[MeasuredSalesUnitsInReturn]) AS MeasuredQuantity
	,(da.[SalesUnitTypeName]) AS SalesUnitTypeName 
	'

	SET @GroupBySalesUnitType = ', da.[SalesUnitTypeName] '
END
----- {RS-37396}

SET @DynamicColumns     = 
	CASE @GroupBy 
	        WHEN 'StoreGroup' THEN @StoreGroupHierarchyDynamicColumns +',ds.CurrentStoreName as Store,ds.StoreId, NULL AS Id'
			WHEN 'Article' THEN 'ISNULL(da.ArticleName,'''') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,da.ArticleId + ''-'' + da.ArticleName AS Id'
			WHEN 'Lev1ArticleHierarchy' THEN  'ISNULL(da.Lev1ArticleHierarchyName,'''') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,da.Lev1ArticleHierarchyId + ''-'' + da.Lev1ArticleHierarchyName AS Id'
			WHEN 'Lev2ArticleHierarchy' THEN  'ISNULL(da.Lev2ArticleHierarchyName,'''') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,da.Lev2ArticleHierarchyId + ''-'' + da.Lev2ArticleHierarchyName AS Id'
			WHEN 'Lev3ArticleHierarchy' THEN  'ISNULL(da.Lev3ArticleHierarchyName,'''') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,da.Lev3ArticleHierarchyId + ''-'' + da.Lev3ArticleHierarchyName AS Id'
			WHEN 'Lev4ArticleHierarchy' THEN  'ISNULL(da.Lev4ArticleHierarchyName,'''') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,da.Lev4ArticleHierarchyId + ''-'' + da.Lev4ArticleHierarchyName AS Id'
			WHEN 'LeafArticleHierarchy' THEN  'ISNULL(CASE 
				  WHEN NumOfHierarchyLevels = 1 THEN ISNULL(da.Lev1ArticleHierarchyName,'''') 
				  WHEN NumOfHierarchyLevels = 2 THEN ISNULL(da.Lev2ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 3 THEN ISNULL(da.Lev3ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 4 THEN ISNULL(da.Lev4ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 5 THEN ISNULL(da.Lev5ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 6 THEN ISNULL(da.Lev6ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 7 THEN ISNULL(da.Lev7ArticleHierarchyName,'''')
				  END,''None'') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,
				  ISNULL(CASE 
				  WHEN NumOfHierarchyLevels = 1 THEN ISNULL(da.Lev1ArticleHierarchyId,'''') + ''-'' + da.Lev1ArticleHierarchyName 
				  WHEN NumOfHierarchyLevels = 2 THEN ISNULL(da.Lev2ArticleHierarchyId,'''') + ''-'' + da.Lev2ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 3 THEN ISNULL(da.Lev3ArticleHierarchyId,'''') + ''-'' + da.Lev3ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 4 THEN ISNULL(da.Lev4ArticleHierarchyId,'''') + ''-'' + da.Lev4ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 5 THEN ISNULL(da.Lev5ArticleHierarchyId,'''') + ''-'' + da.Lev5ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 6 THEN ISNULL(da.Lev6ArticleHierarchyId,'''') + ''-'' + da.Lev6ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 7 THEN ISNULL(da.Lev7ArticleHierarchyId,'''') + ''-'' + da.Lev7ArticleHierarchyName
				  END,''None'') AS Id'		
			WHEN 'Department' THEN 'ISNULL(ex.Value_Department,'''')+'' ''+ ISNULL(ex.Value_DepartmentName,'''') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,ISNULL(ex.Value_Department,'''') AS Id'
			WHEN 'Manufacturer' THEN 'ISNULL(NULLIF(da.DefaultManufacturerId,''''),''-1'') +'' - '' +ISNULL(NULLIF(da.DefaultManufacturerName,''''),''None'') AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,ISNULL(NULLIF(da.DefaultManufacturerId,''''),''-1'') +'' - '' +ISNULL(NULLIF(da.DefaultManufacturerName,''''),''None'') AS Id'
			WHEN 'WeekDay' THEN 'dd.DayNameOfWeek AS Lev1Name,NULL AS Lev2Name,NULL AS Lev3Name,NULL AS Lev4Name,NULL AS Lev5Name,NULL AS NumOfLevels,NULL AS Store,NULL AS StoreId ,dd.DayNameOfWeek AS Id'
	END 

SET @GroupBycolums =
    CASE @GroupBy 
	        WHEN 'StoreGroup' THEN @StoreGroupHierarchyGroupByColumns 
			WHEN 'Article' THEN 'da.ArticleName, da.ArticleId'
			WHEN 'Lev1ArticleHierarchy' THEN 'da.Lev1ArticleHierarchyName,da.Lev1ArticleHierarchyId'
			WHEN 'Lev2ArticleHierarchy' THEN 'da.Lev2ArticleHierarchyName,da.Lev2ArticleHierarchyId'
			WHEN 'Lev3ArticleHierarchy' THEN 'da.Lev3ArticleHierarchyName,da.Lev3ArticleHierarchyId'
			WHEN 'Lev4ArticleHierarchy' THEN 'da.Lev4ArticleHierarchyName,da.Lev4ArticleHierarchyId'
			WHEN 'LeafArticleHierarchy' THEN '(CASE 
				  WHEN NumOfHierarchyLevels = 1 THEN ISNULL(da.Lev1ArticleHierarchyName,'''') 
				  WHEN NumOfHierarchyLevels = 2 THEN ISNULL(da.Lev2ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 3 THEN ISNULL(da.Lev3ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 4 THEN ISNULL(da.Lev4ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 5 THEN ISNULL(da.Lev5ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 6 THEN ISNULL(da.Lev6ArticleHierarchyName,'''')
				  WHEN NumOfHierarchyLevels = 7 THEN ISNULL(da.Lev7ArticleHierarchyName,'''')
				  END),(CASE 
				  WHEN NumOfHierarchyLevels = 1 THEN ISNULL(da.Lev1ArticleHierarchyId,'''') + ''-'' + da.Lev1ArticleHierarchyName 
				  WHEN NumOfHierarchyLevels = 2 THEN ISNULL(da.Lev2ArticleHierarchyId,'''') + ''-'' + da.Lev2ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 3 THEN ISNULL(da.Lev3ArticleHierarchyId,'''') + ''-'' + da.Lev3ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 4 THEN ISNULL(da.Lev4ArticleHierarchyId,'''') + ''-'' + da.Lev4ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 5 THEN ISNULL(da.Lev5ArticleHierarchyId,'''') + ''-'' + da.Lev5ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 6 THEN ISNULL(da.Lev6ArticleHierarchyId,'''') + ''-'' + da.Lev6ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 7 THEN ISNULL(da.Lev7ArticleHierarchyId,'''') + ''-'' + da.Lev7ArticleHierarchyName
				  END),NumOfHierarchyLevels'			
			WHEN 'Department' THEN 'ex.Value_Department, ex.Value_DepartmentName'
			WHEN 'Manufacturer' THEN 'da.DefaultManufacturerId,da.DefaultManufacturerName'
			WHEN 'WeekDay' THEN 'dd.DayNameOfWeek'

	END

--***************************************************************************************************************************
--****************************************************************************************************************************

SET @QueryString = @QueryString 
+	@ListOfStores 
+'SELECT '
+	@DynamicColumns
+'
,SUM(f.[NumberOfArticlesSold]-f.[NumberOfArticlesInReturn]) AS Quantity -- Antall 
'+@SalesUnitColumns+'
,SUM(f.[SalesAmount] + f.ReturnAmount) AS SalesRevenueInclVat	        -- Omsetning		             
,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat) AS SalesRevenue    -- Netto Omsetning  
,SUM(f.[GrossProfit]) AS GrossProfit -- Brutto Kroner
,SUM(f.[SalesPrice]+f.[ReturnAmount]) AS [Price] -- Pris  -- RS-27090 not a price this is just for price calculation per article
,SUM(f.[CostOfGoods]) AS CostOfGoods                                
,SUM(f.[SalesVatAmount] + f.[ReturnAmount] - f.[ReturnAmountExclVat]) AS SalesRevenueVat   
,MIN(f.UseDerivedNetPrice)+MIN(f.UseDerivedNetPrice)*(MIN(f.IsDerivedNetPriceUsedMin)+MAX(f.IsDerivedNetPriceUsedMax)) AS Config
FROM ' + @AggTableToUse+ ' f '+
'	JOIN rbim.Dim_Article da on da.ArticleIdx = f.ArticleIdx 
    JOIN rbim.Dim_Date dd on dd.DateIdx = f.ReceiptDateIdx 
	LEFT JOIN rbim.Dim_PriceType pt on pt.PriceTypeIdx = f.PriceTypeIdx
	LEFT JOIN rbim.Out_ArticleExtraInfo ex on ex.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
	JOIN #Stores tmpds on tmpds.storeidx = f.storeidx'
	+(CASE  @GroupBy WHEN 'StoreGroup' THEN  ' JOIN rbim.Dim_Store ds on ds.StoreIdx = tmpds.StoreIdx' ELSE ' ' END)+ 
' WHERE 
    f.ReceiptDateIdx>='+CAST(@DateIdxBegin AS VARCHAR(10))+' AND  f.ReceiptDateIdx<='+CAST(@DateIdxEnd AS VARCHAR(10))+'
	AND dd.Dateidx not in (-1,-2,-3,-4) AND dd.DimLevel = 0
	'+@SalesUnitTypeFilter+'
	AND (dd.DayNumberOfWeek   = (case when @inp_Monday=   1 then 1 else 0 end)
		OR dd.DayNumberOfWeek = (case when @inp_Tuesday=  1 then 2 else 0 end)
		OR dd.DayNumberOfWeek = (case when @inp_Wednesday=1 then 3 else 0 end)
		OR dd.DayNumberOfWeek = (case when @inp_Thursday= 1 then 4 else 0 end)
		OR dd.DayNumberOfWeek = (case when @inp_Friday=   1 then 5 else 0 end)
		OR dd.DayNumberOfWeek = (case when @inp_Saturday= 1 then 6 else 0 end)
		OR dd.DayNumberOfWeek = (case when @inp_Sunday=   1 then 7 else 0 end))
    AND (@inp_Department IS NULL OR (@inp_Department IS NOT NULL AND ex.Value_Department IN (select value from STRING_SPLIT(@inp_Department,'',''))))
    AND (@inp_Manufacturer IS NULL OR (@inp_Manufacturer IS NOT NULL AND ISNULL(NULLIF(da.DefaultManufacturerId,''''),''-1'') IN (select value from STRING_SPLIT(@inp_Manufacturer,'',''))))
    AND ((@inp_ExcludeDownPricing = 1  AND pt.PriceTypeNo = 5) OR  @inp_ExcludeDownPricing = 0) 
	AND (@inp_ArticleHierarchies IS NULL OR (@inp_ArticleHierarchies IS NOT NULL AND (CASE WHEN NumOfHierarchyLevels = 1 THEN Lev1ArticleHierarchyId ELSE '''' END +
		CASE WHEN NumOfHierarchyLevels = 2 THEN Lev2ArticleHierarchyId ELSE '''' END +
		CASE WHEN NumOfHierarchyLevels = 3 THEN Lev3ArticleHierarchyId ELSE '''' END +
		CASE WHEN NumOfHierarchyLevels = 4 THEN Lev4ArticleHierarchyId ELSE '''' END +
		CASE WHEN NumOfHierarchyLevels = 5 THEN Lev5ArticleHierarchyId ELSE '''' END +
		CASE WHEN NumOfHierarchyLevels = 6 THEN Lev6ArticleHierarchyId ELSE '''' END +
		CASE WHEN NumOfHierarchyLevels = 7 THEN Lev7ArticleHierarchyId ELSE '''' END) IN (select value from STRING_SPLIT(@inp_ArticleHierarchies,'',''))))
    AND (@inp_ArticleSelectionId IS NULL OR da.ArticleId IN (select value from STRING_SPLIT(@inp_ArticleSelectionId,'','')))
	AND (@inp_Filter IS NULL OR 
	@inp_Filter IN 
	(
	da.Lev1ArticleHierarchyId + ''-'' + da.Lev1ArticleHierarchyName, 
	da.Lev2ArticleHierarchyId + ''-'' + da.Lev2ArticleHierarchyName, 
	da.Lev3ArticleHierarchyId + ''-'' + da.Lev3ArticleHierarchyName, 
	da.Lev3ArticleHierarchyId + ''-'' + da.Lev4ArticleHierarchyName, 
	ISNULL(CASE 
				  WHEN NumOfHierarchyLevels = 1 THEN ISNULL(da.Lev1ArticleHierarchyId,'''') + ''-'' + da.Lev1ArticleHierarchyName 
				  WHEN NumOfHierarchyLevels = 2 THEN ISNULL(da.Lev2ArticleHierarchyId,'''') + ''-'' + da.Lev2ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 3 THEN ISNULL(da.Lev3ArticleHierarchyId,'''') + ''-'' + da.Lev3ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 4 THEN ISNULL(da.Lev4ArticleHierarchyId,'''') + ''-'' + da.Lev4ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 5 THEN ISNULL(da.Lev5ArticleHierarchyId,'''') + ''-'' + da.Lev5ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 6 THEN ISNULL(da.Lev6ArticleHierarchyId,'''') + ''-'' + da.Lev6ArticleHierarchyName
				  WHEN NumOfHierarchyLevels = 7 THEN ISNULL(da.Lev7ArticleHierarchyId,'''') + ''-'' + da.Lev7ArticleHierarchyName
				  END,''None''),	
	da.ArticleId + ''-'' + da.ArticleName, 
	dd.DayNameOfWeek, ex.Value_Department, 
	ISNULL(NULLIF(da.DefaultManufacturerId,''''),''-1'') +'' - '' +ISNULL(NULLIF(da.DefaultManufacturerName,''''),''None'')
	))
	AND da.ArticleIdx <> -1
GROUP BY ' + @GroupBycolums + ''+@GroupBySalesUnitType+'
HAVING (SUM(f.[SalesAmount] + f.ReturnAmount) != 0 OR SUM(f.[NumberOfArticlesSold]-f.[NumberOfArticlesInReturn]) != 0)		--{RS-40089} Changed AND to OR
ORDER BY '+@OrderBy+''

--select @QueryString
-- Execute Resultset Query ----------------------------------------------------------------------------------------------------------------------------	
EXECUTE sp_executesql @QueryString, 
                      @ParamDefinition, 
					  @inp_StoreOrGroupNo=@StoreOrGroupNo, 
					  @inp_Monday=@Monday, 
					  @inp_Tuesday=@Tuesday, 
					  @inp_Wednesday=@Wednesday, 
					  @inp_Thursday=@Thursday, 
					  @inp_Friday=@Friday, 
					  @inp_Saturday=@Saturday, 
					  @inp_Sunday=@Sunday, 
					  @inp_Department = @Department, 
					  @inp_Manufacturer = @Manufacturer, 
					  @inp_ExcludeDownPricing = @ExcludeDownPricing, 
					  @inp_ArticleHierarchies = @ArticleHierarchies, 
					  @inp_ArticleSelectionId = @ArticleSelectionId, 
					  @inp_Filter = @Filter,
					  @SalesUnitTypeName = @SalesUnitTypeName 
 --, @ParamDefinition, @inp_DateIdxBegin = @DateIdxBegin , @inp_DateIdxEnd = @DateIdxEnd
END
END



GO

