USE [RSItemESDb]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1550_TobaccoPriceList]    Script Date: 29.07.2019 12:06:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--test source
 
CREATE  PROCEDURE [dbo].[usp_CBI_1550_TobaccoPriceList]     
( @StoreId AS VARCHAR(100) )
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--SELECT A.ArticleNo,A.ArticleName,A.LabelText2, 4.99 AS SalesPrice 
--FROM  dbo.Articles AS A 
----LEFT JOIN dbo.ExtendedArticles AS EA ON EA.ArticleId = A.ArticleId --AND EA.StoreID = @StoreId
--WHERE A.ArticleHierarchyNo IN 
--(SELECT ah2.ArticleHierarchyNo FROM dbo.ArticleHierarchies AS AH2 WHERE AH2.ParentArticleHierarchyNo IN (
--SELECT AH.ArticleHierarchyNo FROM  dbo.ArticleHierarchies AS AH WHERE AH.ArticleHierarchyName LIKE '%tobacco%'))
--AND A.ArticleTypeNo=1 AND A.ArticleStatusNo=1
--ORDER BY A.ArticleName, A.LabelText2

SELECT A.ArticleNo,A.ArticleReceiptText AS ArticleName,A.LabelText2, ISNULL(NULLIF(EA.SalesPrice,0),9.99) AS SalesPrice
--'£ '+ '9.99' AS SalesPrice 
FROM  dbo.Articles AS A 
JOIN dbo.ExtendedArticles AS EA ON EA.ArticleId = A.ArticleId --AND EA.StoreID = @StoreId
WHERE A.ArticleHierarchyNo IN 
(SELECT ah2.ArticleHierarchyNo FROM dbo.ArticleHierarchies AS AH2 WHERE AH2.ParentArticleHierarchyNo IN (
SELECT AH.ArticleHierarchyNo FROM  dbo.ArticleHierarchies AS AH WHERE AH.ArticleHierarchyName LIKE '%tobacco%'))
AND A.ArticleTypeNo=1 AND A.ArticleStatusNo=1
AND EA.StoreID = '19035'
ORDER BY A.ArticleReceiptText, A.LabelText2



END  


GO

