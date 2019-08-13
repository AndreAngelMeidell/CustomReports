USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1510_KeyFiguresYesterday_MostSold_Date]    Script Date: 15.01.2019 14:34:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER PROCEDURE [dbo].[usp_CBI_1510_KeyFiguresYesterday_MostSold_Date] 
(@DateTo AS DATE)

AS 
BEGIN
SET NOCOUNT ON;

--3 av 3 Most Sold Yesterday
--TRN_KeyFigures_Most Sold Articles Yesterday OK
DECLARE @DateFromIdx DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @DateFrom INT  = CAST(CONVERT(VARCHAR(8),@DateFromIdx, 112) AS INTEGER)   -- Added for performance optimization 

SELECT TOP 100 DA.ArticleId, DA.ArticleName, SUM(f.NumberOfArticlesSold-f.NumberOfArticlesInReturn) AS NumberOfArticlesSold, SUM(f.SalesAmount) AS SalesAmount
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	INNER JOIN RBIM.Dim_Store st (NOLOCK) ON f.StoreIdx = st.StoreIdx
	INNER JOIN RBIM.Dim_Date d (NOLOCK) ON d.DateIdx = f.ReceiptDateIdx
	INNER JOIN RBIM.Dim_Article AS DA (NOLOCK) ON DA.ArticleIdx = f.ArticleIdx
WHERE f.ReceiptDateIdx=@DateFrom 
AND DA.ArticleIdx>1
GROUP BY DA.ArticleId, DA.ArticleName
ORDER BY NumberOfArticlesSold DESC

END 



GO

