USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1663_Spaceman_Data_Basis]    Script Date: 13.11.2020 08:41:44 ******/
DROP PROCEDURE [dbo].[usp_CBI_1663_Spaceman_Data_Basis]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1663_Spaceman_Data_Basis]    Script Date: 13.11.2020 08:41:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1663_Spaceman_Data_Basis]
----------------------------------------------------------
AS 
BEGIN 
SELECT cast(getdate() AS date) AS CalculationDate, ds.StoreId, 
ds.Lev1AssortmentProfileDisplayId, da.ArticleId,
convert(decimal(16,2),isnull(sum(isnull(asarpw.SalesPrice,0) + isnull(asarpw.ReturnAmount,0))/ nullif(sum(isnull(asarpw.QuantityOfArticlesSold,0) + isnull(asarpw.QuantityOfArticlesInReturn,0)),0),0)) AS Price, convert(decimal(16,2),isnull(sum(ISNULL(asarpw.CostOfGoodsSold,0))/nullif(sum(isnull(asarpw.QuantityOfArticlesSold,0) + isnull(asarpw.QuantityOfArticlesInReturn,0)),0),0)) AS Cost, 
sum(ISNULL(asarpw.QuantityOfArticlesSold,0) + ISNULL(asarpw.QuantityOfArticlesInReturn,0)) AS RegularMovement,
convert(decimal(16,0), isnull(nullif(asarpw.SalesVatAmount,0)/nullif(asarpw.SalesAmountExclVat,0),0)*100) AS VatRate,
convert(decimal(16,2), isnull(sum(asarpw.SalesPrice* asarpw.QuantityOfArticlesSold) - sum(asarpw.SalesAmount)/nullif(sum(isnull(asarpw.QuantityOfArticlesSold,0) + isnull(asarpw.QuantityOfArticlesInReturn,0)),0),0)) AS 'Marked down value',
NULL AS 'Planogram ID'
FROM RBIM.Agg_SalesAndReturnPerDay AS asarpw WITH (NOLOCK)
JOIN RBIM.Dim_Store AS ds ON asarpw.StoreIdx = ds.StoreIdx
JOIN RBIM.Dim_Date AS dd ON asarpw.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS da ON asarpw.ArticleIdx = da.ArticleIdx 
WHERE dd.RelativeWeek BETWEEN -13 AND   -1 
GROUP BY ds.StoreId, ds.Lev1AssortmentProfileDisplayId, da.ArticleId, isnull(nullif(asarpw.SalesVatAmount,0)/nullif(asarpw.SalesAmountExclVat,0),0)*100

END
GO

