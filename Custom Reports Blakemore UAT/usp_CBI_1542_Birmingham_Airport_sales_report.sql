USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1542_Birmingham_Airport_sales_report]    Script Date: 13.11.2020 08:43:04 ******/
DROP PROCEDURE [dbo].[usp_CBI_1542_Birmingham_Airport_sales_report]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1542_Birmingham_Airport_sales_report]    Script Date: 13.11.2020 08:43:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1542_Birmingham_Airport_sales_report]
(   
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME
) 
AS  
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  

------------------------------------------------------------------------------------------------------
	IF (@DateFrom IS NULL)
	BEGIN
		SELECT TOP(0) 1
	END
	ELSE BEGIN		

		DECLARE @DateFromIdx integer
		DECLARE @DateToIdx integer
		
		SET @DateFromIdx = cast(convert(varchar(8), @DateFrom, 112) as integer)
		SET @DateToIdx = cast(convert(varchar(8), @DateTo, 112) as integer)

		
SELECT dd.FullDate AS Date , sum(ISNULL(asarpw.QuantityOfArticlesSold,0)) AS 'Articles Sold',
sum(ISNULL(asarpw.QuantityOfArticlesInReturn,0)) AS 'Articles Returned',
sum(ISNULL(asarpw.QuantityOfArticlesSold,0) + ISNULL(asarpw.QuantityOfArticlesInReturn,0)) AS RegularMovement,
sum(isnull(asarpw.SalesPriceExclVat,0)) AS 'Sales Price Excluding VAT',
sum(isnull(asarpw.ReturnAmountExclVat,0)) AS 'Return Amount Excluding VAT',
isnull(nullif(sum(isnull(asarpw.[SalesPrice],0)+isnull(asarpw.[ReturnAmount],0)),0)/nullif(sum(isnull(asarpw.[NumberOfArticlesSold],0)-isnull(asarpw.[NumberOfArticlesInReturn],0)),0),0) AS [Price] 
FROM RBIM.Agg_SalesAndReturnPerDay AS asarpw WITH (NOLOCK)
JOIN RBIM.Dim_Store AS ds ON asarpw.StoreIdx = ds.StoreIdx
JOIN RBIM.Dim_Date AS dd ON asarpw.ReceiptDateIdx = dd.DateIdx
JOIN RBIM.Dim_Article AS da ON asarpw.ArticleIdx = da.ArticleIdx 
WHERE dd.FullDate BETWEEN @DateFrom AND @DateTo AND ds.StoreId ='11202'
GROUP BY dd.FullDate





	END

END



GO

