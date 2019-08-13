USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1500_Premiebevis]    Script Date: 28.05.2018 13:55:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1500_Premiebevis]
(
	---------------------------------------------

	@DateFrom AS DATETIME,
	@DateTo AS DATETIME

)
AS  
BEGIN 


--Vita Premiebevis
--Av Andre Angel Meidell
--Mai-2018

--DECLARE @BeginRelativeWeek INTEGER = -1
--DECLARE @StoreId VARCHAR(50) = '1803'
--DECLARE @ArticleId VARCHAR(50) = '13365'

SELECT DS.StoreName,d.FullDate, a.ArticleName,ACSPH.NumberOfArticlesSold, ACSPH.NetPurchasePrice, 
ACSPH.NumberOfArticlesSold*ACSPH.NetPurchasePrice AS TotaltNetPurchasePrice, a.BrandName, DS2.SupplierId, DS2.SupplierName
FROM  RBIM.Agg_CampaignSalesPerHour AS ACSPH 
JOIN RBIM.Dim_CampaignDiscountCombination AS CDC ON CDC.CampaignDiscountCombinationIdx = ACSPH.CampaignDiscountCombinationIdx
join BI_Mart.RBIM.Dim_Date d on d.DateIdx = ACSPH.ReceiptDateIdx
join BI_Mart.RBIM.Dim_Article a on a.ArticleIdx = ACSPH.ArticleIdx
JOIN RBIM.Dim_Supplier AS DS2 ON DS2.SupplierIdx = ACSPH.SupplierIdx
JOIN BI_Mart.RBIM.Dim_Store AS DS ON ds.StoreIdx = ACSPH.StoreIdx
JOIN BI_Mart.rbim.Dim_PriceType AS DPT ON DPT.PriceTypeIdx = ACSPH.PriceTypeIdx
WHERE 1=1
AND CDC.CampaignStatusNo=1 
AND CDC.CampaignId='20172011' -- Alle premiebevis
AND ACSPH.NumberOfArticlesSold<>0 -- bare de som er solgt
AND d.FullDate >= @DateFrom
AND d.FullDate <= @DateTo
ORDER BY DS.StoreId, d.FullDate, a.ArticleName




END 
GO

