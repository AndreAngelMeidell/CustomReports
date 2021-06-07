USE [BI_Mart]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1158_dsTopNSalesReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1158_dsTopNSalesReport_data]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1158_dsTopNSalesReport_data]
(   
    @StoreId AS VARCHAR(100), 
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME, 
	@SupplierId AS VARCHAR(100),		
	@ArticleGroupId AS VARCHAR(100),
	@OrderBy AS VARCHAR(50) = 'TopNetSales', --'TopQuantity','TopNetSales','TopGrossProfit', 'LowGrossProfit', 'LowNetSales'
	@Top INTEGER = 50
	
) 
AS  
BEGIN
  
------------------------------------------------------------------------------------------------------

SELECT TOP (@Top) *
FROM (
SELECT 
ArticleName
,Gtin
,SoldQuantity
,NetSales
,GrossProfit
FROM (
	SELECT
		da.ArticleName AS ArticleName 
		,CASE WHEN ISNULL(dg.GtinIdx,-1) < 0 THEN NULL ELSE dg.Gtin END AS Gtin          
		,SUM(f.[NumberOfArticlesSold]-f.[NumberOfArticlesInReturn]) AS SoldQuantity -- Antall
		,SUM(f.[SalesAmountExclVat] + f.ReturnAmountExclVat) AS NetSales --Netto Omsetning
		,SUM(f.[GrossProfit]) AS GrossProfit -- Brutto Kroner
	FROM RBIM.Agg_SalesAndReturnPerDay f
		JOIN rbim.Dim_Date dd ON dd.DateIdx = f.ReceiptDateIdx 
		JOIN rbim.Dim_Store ds ON ds.storeidx = f.storeidx
		JOIN rbim.Dim_Article da ON da.ArticleIdx = f.ArticleIdx
		JOIN rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx
		--JOIN rbim.Dim_Supplier dsup ON dsup.SupplierIdx = f.SupplierIdx               --RS-27090   The correlation name 'dsup' is specified multiple times in a FROM clause.
		JOIN RBIM.Dim_Gtin dg ON dg.GtinIdx = f.GtinIdx
		WHERE 
		--  filter on store
		@StoreId = ds.StoreId

		AND ds.isCurrentStore = 1   	-- make sure you only get the 'current store' 
										-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
		AND  dd.FullDate BETWEEN @DateFrom AND @DateTo
		--AND f.ArticleIdx > -1 
		AND da.Is3rdpartyArticle = 0
		AND (@SupplierId=dsup.SupplierId OR ISNULL(@SupplierId,'-1')='-1')
		AND (@ArticleGroupId IN (da.Lev1ArticleHierarchyId, da.Lev2ArticleHierarchyId, da.Lev3ArticleHierarchyId, da.Lev4ArticleHierarchyId, da.Lev5ArticleHierarchyId) 
					OR ISNULL(@ArticleGroupId,'-1')='-1')				  
		GROUP BY da.ArticleName,  dg.Gtin, dg.GtinIdx --, dsup.SupplierName
		) AS f
) AS f
ORDER BY 
CASE WHEN @OrderBy = 'TopQuantity' THEN f.SoldQuantity ELSE NULL END DESC,
CASE WHEN @OrderBy = 'TopNetSales' THEN f.NetSales ELSE NULL END DESC,
CASE WHEN @OrderBy = 'TopGrossProfit' THEN f.GrossProfit ELSE NULL END DESC,
CASE WHEN @OrderBy = 'LowGrossProfit' THEN f.GrossProfit ELSE NULL END ASC,
CASE WHEN @OrderBy = 'LowNetSales' THEN f.NetSales ELSE NULL END ASC
END