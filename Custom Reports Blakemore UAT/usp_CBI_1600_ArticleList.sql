USE [RSItemESDb]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1600_ArticleList]    Script Date: 13.11.2020 08:56:20 ******/
DROP PROCEDURE [dbo].[usp_CBI_1600_ArticleList]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1600_ArticleList]    Script Date: 13.11.2020 08:56:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


 
CREATE  PROCEDURE [dbo].[usp_CBI_1600_ArticleList]     
( @StoreId AS VARCHAR(100) )
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--AFB-VRSSQL-CIM0 in Prod
--Spørringen er ikke helt lik som i UAT bruker her en del info i Extendedarticles dette er nå kommentert bort 05122019
--Endring 05122019 ny spørring pga altenativ ordrenr og priser

SELECT 
DISTINCT
 ISNULL(a.ArticleId,'') AS ArticleId
,ISNULL(REPLACE(a.ArticleDescription,',','|'),'') AS  ArticleDescription
,ISNULL(a.ArticleStatusNo,'') AS ArticleStatusNo
,ISNULL(ab.Barcode,'') AS  GTIN
,ISNULL(su.SupplierId,'') AS SupplierNo
,ISNULL(oa.OrderingAlternativeId,'') AS OrderingAlternativeId
,ISNULL(oa.SalesUnitsInOrderPackage,'') AS SalesUnitsInOrderPackage
,ISNULL(apa.AssortmentProfileArticleStatusNo,'') AS AssortmentProfileArticleStatusNo
,apa.FromDate AS AssortmentFromDate
,apa.ToDate AS AssortmentToDate
,apa.DiscontinuedDate AS  AssortmentExpireDate
,ISNULL(SAI.InStockQty,'') AS InStockQty
,MIN(ISNULL(ca.DefaultCampaignSalesPrice,cap.SalesPrice)) AS SalesPrice
,ISNULL(coap.PurchasePrice,0) AS PurchasePrice
,ISNULL(STRING_AGG(c.CampaignId,'| '),'') AS CampaignIds
,ISNULL(STRING_AGG(c.CampaignName,'| '),'') AS CampaignNames 
FROM  dbo.Stores AS s (NOLOCK)
JOIN StoreWithPriceAndAssortmentProfiles apap (NOLOCK) ON apap.StoreID = s.StoreID
JOIN dbo.CurrentArticlePrices AS cap (NOLOCK) ON cap.PriceProfileNo = apap.PriceProfileNo
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
LEFT JOIN dbo.CampaignArticles AS ca(NOLOCK) ON ca.ArticleNo = a.ArticleNo AND ca.CampaignArticleStatusNo=1 
AND ca.DefaultCampaignSalesPriceToDate>GETDATE() AND ca.DefaultCampaignSalesPriceFromDate<GETDATE() AND ca.DefaultCampaignArticlePriceNo=DefaultCampaignArticlePriceNo
AND ca.CampaignNo IN (SELECT csg.CampaignNo FROM  CampaignStoreGroups csg WHERE csg.PriceProfileNo = apap.PriceProfileNo AND ca.CampaignNo=csg.CampaignNo)
LEFT JOIN dbo.Campaigns AS c(NOLOCK) ON c.CampaignNo = ca.CampaignNo AND c.CampaignStatusNo=1
WHERE s.StoreID=@StoreId
--WHERE s.StoreID=10222
--AND a.ArticleId='1018266'
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
--,ca.DefaultCampaignSalesPrice
--,ca.DefaultCampaignSalesPriceToDate
--,ca.DefaultCampaignSalesPriceFromDate
,cap.SalesPrice
--,ea.NetCostPrice, ea.PurchasePrice
,coap.PurchasePrice
order by 1 


--SELECT 
-- ISNULL(a.ArticleId,'') AS ArticleId
--,ISNULL(REPLACE(a.ArticleDescription,',','|'),'') AS  ArticleDescription
--,ISNULL(a.ArticleStatusNo,'') AS ArticleStatusNo
--,ISNULL(ab.Barcode,'') AS  GTIN
--,ISNULL(su.SupplierId,'') AS SupplierNo
--,ISNULL(ea.OrderingAlternativeId,'') AS OrderingAlternativeId
--,ISNULL(ea.SalesUnitsInOrderPackage,'') AS SalesUnitsInOrderPackage
--,ISNULL(apa.AssortmentProfileArticleStatusNo,'') AS AssortmentProfileArticleStatusNo
--,apa.FromDate AS AssortmentFromDate
--,apa.ToDate AS AssortmentToDate
--,apa.DiscontinuedDate AS  AssortmentExpireDate
--,ISNULL(SAI.InStockQty,'') AS InStockQty
--,MIN(ISNULL(ca.DefaultCampaignSalesPrice,cap.SalesPrice)) AS SalesPrice
--,ISNULL(ea.PurchasePrice,ea.NetCostPrice) AS PurchasePrice
--,ISNULL(STRING_AGG(c.CampaignId,'| '),'') AS CampaignIds
--,ISNULL(STRING_AGG(c.CampaignName,'| '),'') AS CampaignNames
--FROM  dbo.Stores AS s (NOLOCK)
--JOIN StoreWithPriceAndAssortmentProfiles apap (NOLOCK) ON apap.StoreID = s.StoreID
--JOIN dbo.CurrentArticlePrices AS cap (NOLOCK) ON cap.PriceProfileNo = apap.PriceProfileNo
--JOIN dbo.Articles AS a (NOLOCK) ON a.ArticleNo = cap.ArticleNo
--JOIN dbo.ExtendedArticles AS ea ON ea.ArticleId = a.ArticleId AND ea.StoreID = s.StoreID
--JOIN dbo.ArticleBarcodes AS ab (NOLOCK) ON ab.ArticleNo = a.ArticleNo
--JOIN dbo.ArticleStatuses AS ast (NOLOCK) ON ast.ArticleStatusNo = a.ArticleStatusNo
--JOIN dbo.SupplierArticles AS sa(NOLOCK) ON sa.SupplierArticleNo = a.DefaultSupplierArticleNo
--JOIN dbo.Suppliers AS su ON su.SupplierNo = ea.SupplierNo 
--LEFT JOIN dbo.CurrentAssortmentProfileArticles AS capa ON capa.ArticleNo = a.ArticleNo AND capa.AssortmentProfileNo = apap.AssortmentProfileNo
--LEFT JOIN dbo.AssortmentProfileArticles AS apa ON apa.ArticleNo = a.ArticleNo AND apa.AssortmentProfileNo = apap.AssortmentProfileNo AND apa.AssortmentProfileArticleNo = capa.AssortmentProfileArticleNo 
----JOIN dbo.OrderingAlternatives AS oa(NOLOCK) ON oa.SupplierArticleNo = sa.SupplierArticleNo
----LEFT JOIN dbo.CurrentOrderingAlternativePrices AS coap(NOLOCK) ON coap.OrderingAlternativeNo = oa.OrderingAlternativeNo AND coap.PriceProfileNo = apap.PriceProfileNo AND sa.DefaultOrderingAlternativeNo=coap.OrderingAlternativeNo
----JOIN dbo.CurrentAssortmentProfileArticles AS capa(NOLOCK) ON capa.ArticleNo = a.ArticleNo AND capa.AssortmentProfileNo = apap.AssortmentProfileNo
----JOIN dbo.AssortmentProfileArticles AS APA(NOLOCK) ON APA.ArticleNo = a.ArticleNo AND APA.AssortmentProfileNo = apap.AssortmentProfileNo AND apa.AssortmentProfileArticleNo=capa.AssortmentProfileArticleNo
----LEFT JOIN dbo.AssortmentProfileStatuses AS aps(NOLOCK) ON apa.AssortmentProfileArticleStatusNo=aps.AssortmentProfileStatusNo
--LEFT JOIN dbo.SalesUnitTypes AS sut(NOLOCK) ON sut.SalesUnitTypeNo = a.SalesUnitTypeNo
--LEFT JOIN [AFB-VRSSQL-CIM0].VBDCM.dbo.AllArticles AS aa(NOLOCK) ON aa.ArticleID = a.ArticleId
--LEFT JOIN [AFB-VRSSQL-CIM0].VBDCM.dbo.StoreArticleInfos SAI(NOLOCK) ON SAI.ArticleNo = aa.ArticleNo AND SAI.StoreNo = s.StoreID
--LEFT JOIN dbo.CampaignArticles AS ca(NOLOCK) ON ca.ArticleNo = a.ArticleNo AND ca.CampaignArticleStatusNo=1
--LEFT JOIN dbo.Campaigns AS c(NOLOCK) ON c.CampaignNo = ca.CampaignNo
----WHERE s.StoreID=10222
--WHERE s.StoreID=@StoreId
----AND a.ArticleId BETWEEN '1000000' AND '1001000'
----AND a.ArticleId='97726330752'
--GROUP BY 
--a.ArticleId
--,a.ArticleDescription
--,a.ArticleName
--,a.ArticleStatusNo
--,ab.Barcode
--,su.SupplierId
--,ea.OrderingAlternativeId
--,ea.SalesUnitsInOrderPackage
--,apa.AssortmentProfileArticleStatusNo
--,apa.FromDate 
--,apa.ToDate
--,apa.DiscontinuedDate 
--,SAI.InStockQty
--,cap.SalesPrice
--,ea.NetCostPrice, ea.PurchasePrice
--order by 1 



END  

GO

