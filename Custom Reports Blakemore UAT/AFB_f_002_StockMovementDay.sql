USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[AFB_f_002_StockMovementDay]    Script Date: 13.11.2020 08:44:24 ******/
DROP PROCEDURE [dbo].[AFB_f_002_StockMovementDay]
GO

/****** Object:  StoredProcedure [dbo].[AFB_f_002_StockMovementDay]    Script Date: 13.11.2020 08:44:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Gavin Pearce
-- Create date: 20/09/2020
-- Description:	Export stock movements
-- =============================================
CREATE PROCEDURE [dbo].[AFB_f_002_StockMovementDay] 
-- Add the parameters for the stored procedure here
(@DateFrom AS DATE, 
 @DateTo AS   DATE
)
AS
    BEGIN
        -- SET NOCOUNT ON added to prevent extra result sets from
        -- interfering with SELECT statements.
        SET NOCOUNT ON;
        WITH CTE1(ArticleId, 
                  OrderingAlternativeId)
             AS (SELECT ArticleId, 
                        OrderingAlternativeId
                 FROM [BI_Kernel].[RBIK].[Lcp_ArticlePurchasePrice]
                 GROUP BY ArticleId, 
                          OrderingAlternativeId)
             SELECT CAST(g.GtinAsText AS VARCHAR) AS Gtin, 
                    a.ArticleId, 
                    a.ArticleName, 
                    app.OrderingAlternativeId AS SupplierArticleId, 
                    sp.SupplierId, 
                    sp.SupplierName, 
                    s.StoreId 'CustomerCode', 
                    s.StoreName 'CustomerName', 
                    dDate.FullDate AS 'AdjustmentDate', 
                    fsa.InAdjustmentQuantity - fsa.OutAdjustmentQuantity AS AdjustmentQuantity, 
                    (fsa.InAdjustmentNetCostAmount + fsa.InAdjustmentDepositNetPurchaseAmount - fsa.OutAdjustmentNetCostAmount - fsa.OutAdjustmentDepositNetPurchaseAmount) / ISNULL(NULLIF((fsa.InAdjustmentQuantity - fsa.OutAdjustmentQuantity), 0), 1) AS AdjustmentNetCostAmount, 
                    sat.StockAdjustmentTypeNo, 
                    sat.StockAdjustmentTypeName AS AdjustmentTypeName, 
                    r.ReasonNo, 
                    r.ReasonName, 
                    'RS to This Point, after remaining on the table' AS 'FieldList', 
                    fsa.*
             FROM [RBIM].[Agg_StockAdjustmentPerDay] fsa
                  LEFT JOIN [RBIM].[Dim_Store] s ON s.StoreIdx = fsa.StoreIdx
                                                    AND s.StoreIdx > 0
                  LEFT JOIN [RBIM].[Dim_Article] a ON a.ArticleIdx = fsa.ArticleIdx
                                                      AND a.ArticleIdx > 0
                  LEFT JOIN [RBIM].[Dim_Gtin] g ON g.GtinIdx = fsa.GtinIdx
                                                   AND g.GtinIdx > 0
                  LEFT JOIN [RBIM].[Dim_Supplier] sp ON sp.SupplierIdx = fsa.SupplierIdx
                                                        AND sp.SupplierIdx > 0
                  LEFT JOIN [RBIM].[Dim_StockAdjustmentType] sat ON sat.StockAdjustmentTypeIdx = fsa.StockAdjustmentTypeIdx
                  LEFT JOIN [RBIM].[Dim_ReasonCode] r ON r.ReasonCodeIdx = fsa.ReasonCodeIdx
                  INNER JOIN CTE1 app ON a.ArticleId = app.ArticleId
                  INNER JOIN [BI_Mart].[RBIM].[Dim_Date] dDate ON dDate.DateIdx = fsa.EndOfPeriodDateIdx
             WHERE dDate.FullDate >= CAST(@datefrom AS DATE)
                   AND dDate.FullDate <= CAST(@dateto AS DATE)
				   and s.StoreId in ('11809','10222');
    END;

GO

