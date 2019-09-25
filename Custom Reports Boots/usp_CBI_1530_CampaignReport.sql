USE [RSItemESDb]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1530_CampaignReport]    Script Date: 25.09.2019 14:08:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1530_CampaignReport]
(   
	@DateFrom AS DATE, 
	@DateTo AS DATE
	
) 
AS
BEGIN


; WITH Agg_Store AS (
SELECT DISTINCT
 C.CampaignId
,STRING_AGG(cast(SG.StoreGroupName AS varchar(MAX)), ', ') AS Agg_StoreName
FROM  dbo.Campaigns								AS C 
LEFT JOIN dbo.CampaignStoreGroups				AS CSG ON CSG.CampaignNo = C.CampaignNo AND CSG.CampaignStoreGroupStatusNo=1
LEFT JOIN dbo.StoreGroups						AS SG ON SG.StoreGroupNo = CSG.StoreGroupNo
--WHERE C.CampaignNo=2
GROUP BY C.CampaignId
)
--SELECT * FROM Agg_Store

--DCD Kombinasjon
SELECT 
 C.CampaignId
,C.CampaignName
,C.CampaignDescription
,CS.CampaignStatusName
,C.FromDate
,C.ToDate
,(CASE WHEN ISNULL(C.IsMemberPromotion,0)=0 THEN 'No' ELSE 'Yes' END) AS 'Just for Members'
,(CASE WHEN ISNULL(C.IsAllStoreGroupsSelected,0)=0 THEN 'No' ELSE 'Yes' END) AS 'All Stores'
--,STRING_AGG(SG.StoreGroupName, ', ') AS Stores
--,CAST(AggS.Agg_StoreName AS VARCHAR(MAX)) AS 'Selected stores'
,AggS.Agg_StoreName AS 'Selected stores'
,'No' AS PromotionPrice
--,(CASE WHEN ISNULL(MAX(ca.DefaultCampaignSalesPrice),0)<MAX(APCB.SalesPrice)  THEN 'Yes' ELSE 'No' END) AS PromotionPrice -- 1 linje skulle vært nei.
,aa.ArticleId
,aa.ArticleName
,AB.Barcode AS 'GTIN'
,s.SupplierId
,S.SupplierName
--,B.BrandId
--,B.BrandName 20190629 endringer
,ISNULL(b2.BrandName,B.BrandName) AS BrandName
,MAX(APCB.SalesPrice) AS 'Ordinary sales price'
,NULL AS 'Campaign sales price' --,MAX(AP.SalesPrice) AS 'Campaign sales price' vil ha blank pris på MM
,CDCT.CampaignDiscountCombinationTypeName
,CDC.CampaignDiscountCombinationId
,CDC.CampaignDiscountCombinationName
,DB_IWR.DynamicFieldValue AS 'IsWholeRange'
,DB_PIDM.DynamicFieldValue AS 'PictureInDM'
,DB_CM.DynamicFieldValue AS 'CategoryManager'
,ISNULL(aa.UnitOfMeasurementAmount,0) AS 'MeasurementAmount'
,uni.UnitOfMeasureName AS  'Measurement'
--,SUT.SalesUnitTypeName AS 'Measurement'
,ADF.DynamicFieldValue AS 'SAC'
,DB_ESV.DynamicFieldValue AS 'EstimatedSalesVolume'
,AH3.ArticleHierarchyName AS 'Category'
,AH4.ArticleHierarchyName AS 'Sub-category'
,DB_IWR.DynamicFieldValue AS 'Location'
FROM  dbo.Campaigns AS C
JOIN dbo.CampaignDiscountCombinations AS CDC ON CDC.CampaignNo = C.CampaignNo
JOIN Agg_Store as AggS ON AggS.CampaignId = c.CampaignId
LEFT JOIN dbo.CampaignStatuses					AS CS ON CS.CampaignStatusNo = C.CampaignStatusNo
LEFT JOIN dbo.CampaignArticles					AS CA ON CA.CampaignNo = C.CampaignNo AND CA.CampaignArticleStatusNo=1 AND 1=0
--LEFT JOIN dbo.CampaignDiscountCombinations	AS CDC ON CDC.CampaignNo = C.CampaignNo
LEFT JOIN dbo.CampaignDiscountElements			AS CDE ON CDE.CampaignDiscountCombinationNo = CDC.CampaignDiscountCombinationNo
LEFT JOIN dbo.CampaignDiscountElementItems		AS CDEI ON CDEI.CampaignDiscountElementNo = CDE.CampaignDiscountElementNo
LEFT JOIN dbo.CampaignDiscountCombinationTypes	AS CDCT ON CDCT.CampaignDiscountCombinationTypeNo = CDC.CampaignDiscountCombinationTypeNo
LEFT JOIN dbo.Articles							AS aa ON (aa.ArticleNo = CDEI.ArticleNo OR aa.ArticleHierarchyNo=CDEI.ArticleHierarchyNo)
--LEFT JOIN dbo.Articles						AS aa ON (aa.ArticleNo = CA.ArticleNo OR aa.ArticleHierarchyNo=CDEI.ArticleHierarchyNo)
LEFT JOIN dbo.UnitOfMeasures					AS UNI ON UNI.UnitOfMeasureNo = aa.UnitOfMeasureNo
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_IWR ON DB_IWR.CampaignArticleNo = CA.CampaignArticleNo AND DB_IWR.DynamicFieldDefinitionId='IsWholeRange' --AND 1=0
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_PIDM ON DB_PIDM.CampaignArticleNo = CA.CampaignArticleNo AND DB_PIDM.DynamicFieldDefinitionId='PictureInDM'  --AND 1=0
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_ESV ON DB_ESV.CampaignArticleNo = CA.CampaignArticleNo AND DB_ESV.DynamicFieldDefinitionId='EstimatedSalesVolume' -- AND 1=0
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_L ON DB_L.CampaignArticleNo = CA.CampaignArticleNo AND DB_L.DynamicFieldDefinitionId='Location'  --AND 1=0
LEFT JOIN dbo.CampaignDynamicFields				AS DB_CM ON DB_CM.CampaignNo = c.CampaignNo AND DB_CM.DynamicFieldDefinitionId='CategoryManager' -- AND 1=0
LEFT JOIN dbo.ArticlePrices						AS AP ON AP.articleno = AA.ArticleNo AND ap.ArticlePriceStatusNo=1 --AND 1=0
LEFT JOIN dbo.CampaignArticlePrices				AS CAP ON CAP.articlePriceNo = AP.ArticlePriceNo AND CAP.CampaignArticleNo = CA.CampaignArticleNo AND CAP.CampaignArticlePriceStatusNo=1-- AND 1=0
LEFT JOIN dbo.ArticlePriceCalculationBases		AS APCB ON AA.ArticleNo=APCB.articleno AND APCB.PriceProfileNo = CAP.PriceProfileNo --AND APCB.PriceProfileNo=1 AND AP.ArticlePriceNo=cap.ArticlePriceNo --AND 1=0
LEFT JOIN dbo.ArticleBarcodes					AS AB ON AB.ArticleBarcodeNo = AA.DefaultArticleBarcodeNo
LEFT JOIN dbo.SupplierArticles					AS SA ON SA.ArticleNo = aa.ArticleNo AND Aa.DefaultSupplierArticleNo=SA.SupplierArticleNo
--LEFT JOIN dbo.Suppliers						AS S ON S.SupplierNo = SA.SupplierNo 20190629 Endringer
LEFT JOIN dbo.Suppliers							AS S ON S.SupplierNo = SA.ManufacturerSupplierNo
LEFT JOIN dbo.Brands							AS B ON B.BrandNo = aa.BrandNo
LEFT JOIN dbo.Brands							AS B2 ON B2.BrandNo = B.ParentBrandNo
LEFT JOIN dbo.SalesUnitTypes					AS SUT ON SUT.SalesUnitTypeNo = aa.SalesUnitTypeNo
LEFT JOIN dbo.ArticleDynamicFields				AS ADF ON ADF.ArticleNo = aa.ArticleNo AND ADF.DynamicFieldDefinitionId='SAC'
LEFT JOIN dbo.ArticleHierarchies				AS AH4 ON AH4.ArticleHierarchyNo = aa.ArticleHierarchyNo AND ah4.ArticleHierarchyLevelNo=4
LEFT JOIN dbo.ArticleHierarchies				AS AH3 ON ah3.ArticleHierarchyLevelNo=3 AND AH3.ArticleHierarchyNo = AH4.ParentArticleHierarchyNo 
WHERE C.FromDate BETWEEN @DateFrom AND @DateTo
AND C.CampaignStatusNo<9
GROUP BY 
C.CampaignId
,AggS.Agg_StoreName
,C.CampaignName
,C.CampaignDescription
,CS.CampaignStatusName
,C.FromDate
,C.ToDate
,C.IsMemberPromotion
,C.IsAllStoreGroupsSelected
,aa.ArticleId
,aa.ArticleName
--,AP.SalesPrice
,AB.Barcode
,CDCT.CampaignDiscountCombinationTypeName
,CDC.CampaignDiscountCombinationId
,CDC.CampaignDiscountCombinationName
,s.SupplierId
,S.SupplierName
--,B.BrandId
--,B.BrandName 20190629 endringer
,ISNULL(b2.BrandName,B.BrandName)
,aa.UnitOfMeasurementAmount
,uni.UnitOfMeasureName
,ADF.DynamicFieldValue
,AH3.ArticleHierarchyName
,AH4.ArticleHierarchyName
,DB_IWR.DynamicFieldValue
,DB_PIDM.DynamicFieldValue
,DB_CM.DynamicFieldValue
,DB_ESV.DynamicFieldValue
,DB_IWR.DynamicFieldValue



UNION all

--CA kamp vare
SELECT 
 C.CampaignId
,C.CampaignName
,C.CampaignDescription
,CS.CampaignStatusName
,C.FromDate
,C.ToDate
,(CASE WHEN ISNULL(C.IsMemberPromotion,0)=0 THEN 'No' ELSE 'Yes' END) AS 'Just for Members'
,(CASE WHEN ISNULL(C.IsAllStoreGroupsSelected,0)=0 THEN 'No' ELSE 'Yes' END) AS 'All Stores'
--,STRING_AGG(SG.StoreGroupName, ', ') AS Stores
--,CAST(AggS.Agg_StoreName AS VARCHAR(1000)) AS 'Selected stores'
,AggS.Agg_StoreName AS 'Selected stores'
,'Yes' AS PromotionPrice
--,(CASE WHEN ISNULL(MAX(ca.DefaultCampaignSalesPrice),0)<MAX(APCB.SalesPrice)  THEN 'Yes' ELSE 'No' END) AS PromotionPrice -- 1 linje skulle vært nei.
,aa.ArticleId
,aa.ArticleName
,AB.Barcode AS 'GTIN'
,s.SupplierId
,S.SupplierName
--,B.BrandId
--,B.BrandName 20190629 endringer
,ISNULL(b2.BrandName,B.BrandName) AS BrandName
,MAX(APCB.SalesPrice) AS 'Ordinary sales price'
,MAX(ca.DefaultCampaignSalesPrice) AS 'Campaign sales price'
,CDCT.CampaignDiscountCombinationTypeName
,CDC.CampaignDiscountCombinationId
,CDC.CampaignDiscountCombinationName
,DB_IWR.DynamicFieldValue AS 'IsWholeRange'
,DB_PIDM.DynamicFieldValue AS 'PictureInDM'
,DB_CM.DynamicFieldValue AS 'CategoryManager'
,ISNULL(aa.UnitOfMeasurementAmount,0) AS 'MeasurementAmount'
,uni.UnitOfMeasureName AS  'Measurement'
--,SUT.SalesUnitTypeName AS 'Measurement'
,ADF.DynamicFieldValue AS 'SAC'
,DB_ESV.DynamicFieldValue AS 'EstimatedSalesVolume'
,AH3.ArticleHierarchyName AS 'Category'
,AH4.ArticleHierarchyName AS 'Sub-category'
,DB_L.DynamicFieldValue AS 'Location'
FROM  dbo.Campaigns AS C
JOIN dbo.CampaignArticles AS CA ON CA.CampaignNo = C.CampaignNo 
JOIN Agg_Store as AggS ON AggS.CampaignId = c.CampaignId
--LEFT JOIN dbo.CampaignStoreGroups				AS CSG ON CSG.CampaignNo = C.CampaignNo AND CSG.CampaignStoreGroupStatusNo=1
--LEFT JOIN dbo.StoreGroups						AS SG ON SG.StoreGroupNo = CSG.StoreGroupNo
LEFT JOIN dbo.CampaignStatuses					AS CS ON CS.CampaignStatusNo = C.CampaignStatusNo
--LEFT JOIN dbo.CampaignArticles				AS CA ON CA.CampaignNo = C.CampaignNo AND CA.CampaignArticleStatusNo=1
LEFT JOIN dbo.CampaignDiscountCombinations		AS CDC ON CDC.CampaignNo = C.CampaignNo AND 1=0
LEFT JOIN dbo.CampaignDiscountElements			AS CDE ON CDE.CampaignDiscountCombinationNo = CDC.CampaignDiscountCombinationNo AND 1=0
LEFT JOIN dbo.CampaignDiscountElementItems		AS CDEI ON CDEI.CampaignDiscountElementNo = CDE.CampaignDiscountElementNo AND 1=0
LEFT JOIN dbo.CampaignDiscountCombinationTypes	AS CDCT ON CDCT.CampaignDiscountCombinationTypeNo = CDC.CampaignDiscountCombinationTypeNo AND 1=0
--LEFT JOIN dbo.Articles						AS aa ON (aa.ArticleNo = CDEI.ArticleNo OR aa.ArticleHierarchyNo=CDEI.ArticleHierarchyNo)
LEFT JOIN dbo.Articles							AS aa ON (aa.ArticleNo = CA.ArticleNo ) --OR aa.ArticleHierarchyNo=CDEI.ArticleHierarchyNo)
LEFT JOIN dbo.UnitOfMeasures					AS UNI ON UNI.UnitOfMeasureNo = aa.UnitOfMeasureNo
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_IWR ON DB_IWR.CampaignArticleNo = CA.CampaignArticleNo AND DB_IWR.DynamicFieldDefinitionId='IsWholeRange' 
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_PIDM ON DB_PIDM.CampaignArticleNo = CA.CampaignArticleNo AND DB_PIDM.DynamicFieldDefinitionId='PictureInDM' 
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_ESV ON DB_ESV.CampaignArticleNo = CA.CampaignArticleNo AND DB_ESV.DynamicFieldDefinitionId='EstimatedSalesVolume' 
LEFT JOIN dbo.CampaignArticleDynamicFields		AS DB_L ON DB_L.CampaignArticleNo = CA.CampaignArticleNo AND DB_L.DynamicFieldDefinitionId='Location' 
LEFT JOIN dbo.CampaignDynamicFields				AS DB_CM ON DB_CM.CampaignNo = c.CampaignNo AND DB_CM.DynamicFieldDefinitionId='CategoryManager'
LEFT JOIN dbo.ArticlePrices						AS AP ON AP.articleno = CA.ArticleNo AND ap.ArticlePriceStatusNo=1
LEFT JOIN dbo.CampaignArticlePrices				AS CAP ON CAP.articlePriceNo = AP.ArticlePriceNo AND CAP.CampaignArticleNo = CA.CampaignArticleNo AND CAP.CampaignArticlePriceStatusNo=1
LEFT JOIN dbo.ArticlePriceCalculationBases		AS APCB ON AA.ArticleNo=APCB.articleno AND APCB.PriceProfileNo = CAP.PriceProfileNo --AND AP.ArticlePriceNo=cap.ArticlePriceNo --AND APCB.PriceProfileNo=1
LEFT JOIN dbo.ArticleBarcodes					AS AB ON AB.ArticleBarcodeNo = AA.DefaultArticleBarcodeNo
LEFT JOIN dbo.SupplierArticles					AS SA ON SA.ArticleNo = aa.ArticleNo AND Aa.DefaultSupplierArticleNo=SA.SupplierArticleNo
--LEFT JOIN dbo.Suppliers						AS S ON S.SupplierNo = SA.SupplierNo 20190629 Endringer
LEFT JOIN dbo.Suppliers							AS S ON S.SupplierNo = SA.ManufacturerSupplierNo
LEFT JOIN dbo.Brands							AS B ON B.BrandNo = aa.BrandNo
LEFT JOIN dbo.Brands							AS B2 ON B2.BrandNo = B.ParentBrandNo
LEFT JOIN dbo.SalesUnitTypes					AS SUT ON SUT.SalesUnitTypeNo = aa.SalesUnitTypeNo
LEFT JOIN dbo.ArticleDynamicFields				AS ADF ON ADF.ArticleNo = aa.ArticleNo AND ADF.DynamicFieldDefinitionId='SAC'
LEFT JOIN dbo.ArticleHierarchies				AS AH4 ON AH4.ArticleHierarchyNo = aa.ArticleHierarchyNo AND ah4.ArticleHierarchyLevelNo=4
LEFT JOIN dbo.ArticleHierarchies				AS AH3 ON ah3.ArticleHierarchyLevelNo=3 AND AH3.ArticleHierarchyNo = AH4.ParentArticleHierarchyNo 
WHERE C.FromDate BETWEEN @DateFrom AND @DateTo
AND C.CampaignStatusNo<9
GROUP BY 
C.CampaignId
,AggS.Agg_StoreName
,C.CampaignName
,C.CampaignDescription
,CS.CampaignStatusName
,C.FromDate
,C.ToDate
,C.IsMemberPromotion
,C.IsAllStoreGroupsSelected
,aa.ArticleId
,aa.ArticleName
--,AP.SalesPrice
,AB.Barcode
,CDCT.CampaignDiscountCombinationTypeName
,CDC.CampaignDiscountCombinationId
,CDC.CampaignDiscountCombinationName
,s.SupplierId
,S.SupplierName
--,B.BrandId
--,B.BrandName 20190629 endringer
,ISNULL(b2.BrandName,B.BrandName)
,aa.UnitOfMeasurementAmount
,uni.UnitOfMeasureName
,ADF.DynamicFieldValue
,AH3.ArticleHierarchyName
,AH4.ArticleHierarchyName
,DB_IWR.DynamicFieldValue
,DB_PIDM.DynamicFieldValue
,DB_CM.DynamicFieldValue
,DB_ESV.DynamicFieldValue
,DB_L.DynamicFieldValue
ORDER BY C.CampaignId


END





GO

