USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueSGReport_data]    Script Date: 13.11.2020 08:43:55 ******/
DROP PROCEDURE [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueSGReport_data]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueSGReport_data]    Script Date: 13.11.2020 08:43:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1136_dsArticleSalesAndRevenueSGReport_data]
(   
   @StoreOrGroupNo AS VARCHAR(max),
	--@PeriodType AS VARCHAR(1), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	--@YearToDate AS INTEGER, 
	--@RelativePeriodType AS VARCHAR(5),
	--@RelativePeriodStart AS INTEGER, 
	--@RelativePeriodDuration AS INTEGER ,	
	@StoreGroupCategory AS INTEGER,
	@GroupBy VARCHAR(100) = 'Article', -- StoreGroup, Article, ArticleHierarchy
	@Filter VARCHAR(100) = null
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
DECLARE @GroupBycolums VARCHAR(255)
DECLARE @ListOfStores NVARCHAR(max) =''
DECLARE @DynamicColumns VARCHAR(255)
--Parameters definitions for -------------------------------------------------------------------------------------------
/*DECLARE @ParamDefinition NVARCHAR(max)
	SET @ParamDefinition = N'@inp_DateIdxBegin int, @inp_DateIdxEnd int'
*/          
------------------------------------------------------------------------------------------------------------------------
DECLARE @out_Agg CHAR(1); -- aggregation level to use 
DECLARE @DateIdxBegin INT;
DECLARE @DateIdxEnd INT;

--(N) - No specific period is requested so either Day(D) either Month(M) aggregation level will be retuned.
EXECUTE [dbo].[usp_RBI_GetBestAggSalesAndReturnToUse] 
   @inp_DateRangeBegin	    = @DateFrom
  ,@inp_DateRangeEnd		= @DateTo 
  ,@inp_PeriodGranularity   = 'M'  
  ,@out_DateIdxBegin        = @DateIdxBegin OUTPUT
  ,@out_DateIdxEnd          = @DateIdxEnd OUTPUT
  ,@out_Agg                 = @out_Agg OUTPUT  

/* Test parameters */
--print  @out_Agg 
--print  @DateIdxBegin 
--print  @DateIdxEnd 

------------------------------------------------------------------------------------------------------------------------
IF @out_Agg = 'D' 
 SET  @AggTableToUse='RBIM.Agg_SalesAndReturnPerDay' 
ELSE IF @out_Agg = 'M' 
 SET  @AggTableToUse='RBIM.Agg_SalesAndReturnPerMonth' 
          
------------------------------------------------------------------------------------------------------------------------
-- CTE contains stores that meets filtering requirements and flag IsCurrentStore=1
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
		WHERE (ds.Lev1ChainGroupNo != -1 OR ds.Lev2ChainGroupNo != -1 OR ds.Lev3ChainGroupNo != -1 OR ds.Lev4ChainGroupNo != -1 OR ds.Lev5ChainGroupNo != -1)
		  AND (@IncludeInReportsCurrentStoreOnly = 0 or IsCurrentStore = 1)
'
--to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)

SET @DynamicColumns     = 
	CASE @GroupBy 
			WHEN 'Article' THEN 'da.ArticleName AS Lev1Name,da.ArticleId AS Id'
			WHEN 'Lev1ArticleHierarchy' THEN  'da.Lev1ArticleHierarchyName AS Lev1Name ,da.Lev1ArticleHierarchyId AS Id'
			WHEN 'LeafArticleHierarchy' THEN  'da.LeafArticleHierarchyName AS Lev1Name ,da.LeafArticleHierarchyId AS Id' -- {RS-36556}
	END 

SET @GroupBycolums =
    CASE @GroupBy 
			WHEN 'Article' THEN 'da.ArticleName,da.ArticleId'
			WHEN 'Lev1ArticleHierarchy' THEN'da.Lev1ArticleHierarchyName,da.Lev1ArticleHierarchyId'
			WHEN 'LeafArticleHierarchy' THEN'da.LeafArticleHierarchyName,da.LeafArticleHierarchyId' --{RS-36556}
	END
			
SET @QueryString = @QueryString 
+	@ListOfStores 
+'SELECT '
+	@DynamicColumns
+',SUM(f.[NumberOfArticlesSold]-[NumberOfArticlesInReturn] ) AS Quantity -- Antall                           
	,SUM(f.[SalesAmount] + f.ReturnAmount) AS SalesRevenueInclVat	           -- Omsetning		             
	,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat ) AS SalesRevenue      -- Netto Omsetning   
	,SUM(f.[GrossProfit]) AS GrossProfit -- Brutto Kroner
	,SUM(f.[SalesPrice]+f.[ReturnAmount]) AS [Price] -- Pris                                                 
	,SUM(f.CostOfGoods) AS CostOfGoods               --[PurchaseAmount]  		
	,SUM(f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat) AS SalesRevenueVat     
	,MIN(UseDerivedNetPrice)+MIN(UseDerivedNetPrice)*(MIN(IsDerivedNetPriceUsedMin)+MAX(IsDerivedNetPriceUsedMax))   as Config	
  FROM ' + @AggTableToUse+ ' f '+
	'
	INNER JOIN #Stores ds on ds.storeidx = f.storeidx
	INNER JOIN rbim.Dim_Article da on da.ArticleIdx = f.ArticleIdx 
	WHERE	
	f.ReceiptDateIdx>='+CAST(@DateIdxBegin AS VARCHAR(10))+' AND  f.ReceiptDateIdx<='+CAST(@DateIdxEnd AS VARCHAR(10))+'
	AND da.ArticleIdx <> -1
  GROUP BY ' + @GroupBycolums
    
--- PRINT @QueryString 

-- Execute Resultset Query ----------------------------------------------------------------------------------------------------------------------------	
EXECUTE sp_executesql  @QueryString --, @ParamDefinition, @inp_DateIdxBegin = @DateIdxBegin , @inp_DateIdxEnd = @DateIdxEnd

END
END

GO

