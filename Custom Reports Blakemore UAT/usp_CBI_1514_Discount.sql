USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1514_Discount]    Script Date: 13.11.2020 08:43:44 ******/
DROP PROCEDURE [dbo].[usp_CBI_1514_Discount]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1514_Discount]    Script Date: 13.11.2020 08:43:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1514_Discount] 
(@StoreId AS VARCHAR(100),
@DateFrom AS DATE ,--= '2017-01-01'
@DateTo AS DATE 
)
AS
BEGIN
SET NOCOUNT ON


SELECT 
DS.StoreName, DS.StoreId
,ASARPD.CashRegisterNo,ASARPD.ReceiptDateIdx, DA.ArticleId, DG.Gtin, DA.ArticleName
,DA.Lev3ArticleHierarchyId AS HierNo, DA.Lev3ArticleHierarchyName AS HierName
,(ASARPD.NumberOfArticlesSold) AS Qty
,(ASARPD.SalesPrice) AS NormalSalesPrice
,(ASARPD.SalesAmount) AS SalesAmount
,(ASARPD.SalesPrice-ASARPD.SalesAmount) AS DiscountAmount
,DPT.PriceTypeName
,du.UserNameID
FROM  RBIM.Agg_SalesAndReturnPerDay AS ASARPD
JOIN RBIM.Dim_User AS du ON ASARPD.SystemUserIdx = du.UserIdx
JOIN RBIM.Dim_Date AS DD ON ASARPD.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS DA ON DA.ArticleIdx = ASARPD.ArticleIdx
JOIN RBIM.Cov_ArticleGtin AS CAG ON CAG.ArticleIdx = DA.ArticleIdx AND CAG.IsDefaultGtin=1
LEFT JOIN RBIM.Dim_Gtin AS DG ON DG.GtinIdx = CAG.GtinIdx 
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPD.StoreIdx
JOIN RBIM.Dim_PriceType AS DPT ON DPT.PriceTypeIdx = ASARPD.PriceTypeIdx
LEFT JOIN rbim.Dim_Supplier DSUP(NOLOCK) ON DSUP.SupplierIdx = ASARPD.SupplierIdx
WHERE 1=1
AND ASARPD.ArticleIdx>0 
AND dd.FullDate BETWEEN @DateFrom AND @DateTo
AND ASARPD.PriceTypeIdx IN (28)  --29 Manual price chageed to 28 - Price override
AND DS.StoreId=@StoreId
ORDER BY ASARPD.ReceiptDateIdx DESC



END 



GO

