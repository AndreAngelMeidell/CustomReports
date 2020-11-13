USE [RSItemESDb]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1601_ArticleNotInSortment]    Script Date: 13.11.2020 08:56:33 ******/
DROP PROCEDURE [dbo].[usp_CBI_1601_ArticleNotInSortment]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1601_ArticleNotInSortment]    Script Date: 13.11.2020 08:56:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


 
CREATE  PROCEDURE [dbo].[usp_CBI_1601_ArticleNotInSortment]     
( @StoreId AS VARCHAR(100) )
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--AFB-VRSSQL-CIM0 in Prod

SELECT 
DISTINCT
 ISNULL(a.ArticleId,'') AS ArticleId
,ISNULL(REPLACE(a.ArticleDescription,',','|'),'') AS  ArticleDescription
,ISNULL(a.ArticleStatusNo,'') AS ArticleStatusNo
FROM  dbo.Stores AS s (NOLOCK)
LEFT JOIN StoreWithPriceAndAssortmentProfiles apap (NOLOCK) ON apap.StoreID = s.StoreID
LEFT JOIN dbo.CurrentArticlePrices AS cap (NOLOCK) ON cap.PriceProfileNo = apap.PriceProfileNo
JOIN dbo.Articles AS a (NOLOCK) ON a.ArticleNo = cap.ArticleNo
JOIN dbo.ExtendedArticles AS ea ON ea.ArticleId = a.ArticleId AND ea.StoreID = s.StoreID
JOIN dbo.ArticleBarcodes AS ab (NOLOCK) ON ab.ArticleNo = a.ArticleNo
JOIN dbo.ArticleStatuses AS ast (NOLOCK) ON ast.ArticleStatusNo = a.ArticleStatusNo
JOIN dbo.SupplierArticles AS sa(NOLOCK) ON sa.SupplierArticleNo = a.DefaultSupplierArticleNo
JOIN dbo.Suppliers AS su ON su.SupplierNo = ea.SupplierNo 
LEFT JOIN dbo.CurrentAssortmentProfileArticles AS capa ON capa.ArticleNo = a.ArticleNo AND capa.AssortmentProfileNo = apap.AssortmentProfileNo
LEFT JOIN dbo.AssortmentProfileArticles AS apa ON apa.ArticleNo = a.ArticleNo AND apa.AssortmentProfileNo = apap.AssortmentProfileNo AND apa.AssortmentProfileArticleNo = capa.AssortmentProfileArticleNo 
LEFT JOIN dbo.OrderingAlternatives AS oa(NOLOCK) ON oa.SupplierArticleNo = sa.SupplierArticleNo
LEFT JOIN dbo.CurrentOrderingAlternativePrices AS coap(NOLOCK) ON coap.OrderingAlternativeNo = oa.OrderingAlternativeNo AND coap.PriceProfileNo = apap.PriceProfileNo --AND sa.DefaultOrderingAlternativeNo=coap.OrderingAlternativeNo
LEFT JOIN dbo.SalesUnitTypes AS sut(NOLOCK) ON sut.SalesUnitTypeNo = a.SalesUnitTypeNo
LEFT JOIN [AFB-VRSSQL-CIM0].VBDCM.dbo.AllArticles AS aa(NOLOCK) ON aa.ArticleID = a.ArticleId
LEFT JOIN [AFB-VRSSQL-CIM0].VBDCM.dbo.StoreArticleInfos SAI(NOLOCK) ON SAI.ArticleNo = aa.ArticleNo AND SAI.StoreNo = s.StoreID
WHERE s.StoreID=@StoreId
--WHERE s.StoreID=10222
AND apa.FromDate IS NULL
AND SAI.InStockQty>0
GROUP BY 
a.ArticleId
,a.ArticleDescription
,a.ArticleName
,a.ArticleStatusNo
,ab.Barcode
,su.SupplierId
,oa.OrderingAlternativeId
,oa.SalesUnitsInOrderPackage
,apa.AssortmentProfileArticleStatusNo
,apa.FromDate 
,apa.ToDate
,apa.DiscontinuedDate 
,SAI.InStockQty
,cap.SalesPrice
,coap.PurchasePrice
order by 1 

END  

GO

